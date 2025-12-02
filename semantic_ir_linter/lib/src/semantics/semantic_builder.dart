import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';

import '../widget_tree/widget_node.dart';
import 'known_semantics.dart';
import 'semantic_node.dart';

class SemanticBuilder {
  SemanticBuilder({
    required this.unit,
    required this.knownSemantics,
  }) : fileUri = Uri.file(unit.path);

  final ResolvedUnitResult unit;
  final KnownSemanticsRepository knownSemantics;
  final Uri fileUri;

  SemanticNode? build(WidgetNode? widget) {
    if (widget == null) return null;

    final known = knownSemantics[widget.widgetType] ?? _defaultSemantics;
    final builtChildren = _buildChildren(widget);

    var label = _deriveLabel(widget);
    var labelGuarantee = label == null
        ? LabelGuarantee.none
        : LabelGuarantee.hasStaticLabel;
    var labelSource = _labelSourceForWidget(widget.widgetType, label);
    String? explicitChildLabel;

    if (widget.widgetType == 'ListTile') {
      final titleChild = builtChildren.slotNodes['title'];
      if (titleChild?.label != null) {
        explicitChildLabel = titleChild!.label;
        labelGuarantee = LabelGuarantee.hasStaticLabel;
        labelSource = LabelSource.textChild;
      }
    }

    if (known.mergesDescendants || known.implicitlyMergesSemantics) {
      final mergedLabel = _mergeChildLabels(
        builtChildren.nodes,
        existing: explicitChildLabel,
      );
      if (mergedLabel != null) {
        explicitChildLabel = mergedLabel;
        labelGuarantee = LabelGuarantee.hasStaticLabel;
        labelSource = LabelSource.textChild;
      }
    }

    return SemanticNode(
      widgetType: widget.widgetType,
      astNode: widget.astNode,
      fileUri: fileUri,
      offset: widget.astNode.offset,
      length: widget.astNode.length,
      role: known.role,
      controlKind: known.controlKind,
      isFocusable: known.isFocusable,
      isEnabled: _computeIsEnabled(widget, known),
      hasTap: known.hasTap,
      hasLongPress: known.hasLongPress,
      hasIncrease: known.hasIncrease,
      hasDecrease: known.hasDecrease,
      isToggled: known.isToggled,
      isChecked: known.isChecked,
      mergesDescendants: known.mergesDescendants,
      excludesDescendants: known.excludesDescendants,
      blocksBehind: known.blocksBehind,
      label: label,
      labelGuarantee: labelGuarantee,
      labelSource: labelSource,
      explicitChildLabel: explicitChildLabel,
      children: builtChildren.nodes,
    );
  }

  _BuiltChildren _buildChildren(WidgetNode widget) {
    final nodes = <SemanticNode>[];
    final slotNodes = <String, SemanticNode>{};
    final slotOrder =
        knownSemantics[widget.widgetType]?.slotTraversalOrder ?? widget.slots.keys.toList();

    for (final slotName in slotOrder) {
      final childWidget = widget.slots[slotName];
      if (childWidget == null) continue;
      final childNode = build(childWidget);
      if (childNode != null) {
        nodes.add(childNode);
        slotNodes[slotName] = childNode;
      }
    }

    for (final child in widget.children) {
      final built = build(child);
      if (built != null) {
        nodes.add(built);
      }
    }

    return _BuiltChildren(nodes: nodes, slotNodes: slotNodes);
  }

  bool _computeIsEnabled(WidgetNode widget, KnownSemantics known) {
    var enabled = known.isEnabledByDefault;
    final callbacks = [
      widget.props['onPressed'],
      widget.props['onTap'],
      widget.props['onChanged'],
    ];
    for (final callback in callbacks) {
      if (callback != null) {
        if (callback is NullLiteral) {
          enabled = false;
        } else {
          enabled = true;
        }
        break;
      }
    }
    return enabled;
  }

  String? _deriveLabel(WidgetNode widget) {
    if (widget.widgetType == 'Text') {
      if (widget.positionalArgs.isNotEmpty) {
        return _literalString(widget.positionalArgs.first);
      }
    }

    if (widget.widgetType == 'IconButton') {
      final tooltip = widget.props['tooltip'];
      return _literalString(tooltip);
    }

    return null;
  }

  LabelSource _labelSourceForWidget(String widgetType, String? label) {
    if (label == null) return LabelSource.none;
    if (widgetType == 'Text') return LabelSource.textChild;
    if (widgetType == 'IconButton') return LabelSource.tooltip;
    return LabelSource.other;
  }

  String? _literalString(Expression? expression) {
    if (expression is SimpleStringLiteral) {
      return expression.value;
    }
    if (expression is AdjacentStrings) {
      final buffer = StringBuffer();
      for (final string in expression.strings) {
        final value = _literalString(string);
        if (value == null) return null;
        buffer.write(value);
      }
      return buffer.toString();
    }
    return null;
  }

  String? _mergeChildLabels(
    List<SemanticNode> children, {
    String? existing,
  }) {
    final parts = <String>[];
    if (existing != null && existing.isNotEmpty) {
      parts.add(existing);
    }
    for (final child in children) {
      final childLabel = child.effectiveLabel;
      if (childLabel != null && childLabel.isNotEmpty) {
        parts.add(childLabel);
      }
    }
    if (parts.isEmpty) return existing;
    return parts.join(' ').trim();
  }
}

class _BuiltChildren {
  const _BuiltChildren({
    required this.nodes,
    required this.slotNodes,
  });

  final List<SemanticNode> nodes;
  final Map<String, SemanticNode> slotNodes;
}

const _defaultSemantics = KnownSemantics(
  role: SemanticRole.group,
  controlKind: ControlKind.none,
  isFocusable: false,
  isEnabledByDefault: true,
  hasTap: false,
  hasLongPress: false,
  hasIncrease: false,
  hasDecrease: false,
  isToggled: false,
  isChecked: false,
  mergesDescendants: false,
  implicitlyMergesSemantics: false,
  excludesDescendants: false,
  blocksBehind: false,
  isPureContainer: true,
  slotTraversalOrder: <String>[],
);
