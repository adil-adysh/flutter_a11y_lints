import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';

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

    if (widget.nodeType == WidgetNodeType.conditionalBranch) {
      for (final branch in widget.branchChildren) {
        final built = build(branch);
        if (built != null) {
          return built;
        }
      }
      return null;
    }

    final known = knownSemantics[widget.widgetType] ?? _defaultSemantics;
    final builtChildren = _buildChildren(widget);

    final labelInfo = _deriveLabelInfo(widget);
    final label = labelInfo?.value;
    var labelGuarantee = labelInfo?.guarantee ?? LabelGuarantee.none;
    var labelSource = labelInfo?.source ?? LabelSource.none;
    String? explicitChildLabel;
    var childLabelGuarantee = LabelGuarantee.none;

    if (widget.widgetType == 'ListTile') {
      final titleChild = builtChildren.slotNodes['title'];
      if (titleChild != null &&
          titleChild.labelGuarantee != LabelGuarantee.none) {
        explicitChildLabel = titleChild.effectiveLabel ?? explicitChildLabel;
        childLabelGuarantee = _mergeGuarantees(
          childLabelGuarantee,
          titleChild.labelGuarantee,
        );
      }
    }

    if (known.mergesDescendants || known.implicitlyMergesSemantics) {
      final merged = _mergeChildLabels(
        builtChildren.nodes,
        existingText: explicitChildLabel,
        existingGuarantee: childLabelGuarantee,
      );
      explicitChildLabel = merged.text ?? explicitChildLabel;
      childLabelGuarantee = _mergeGuarantees(
        childLabelGuarantee,
        merged.guarantee,
      );
    }

    if (childLabelGuarantee == LabelGuarantee.none) {
      final fallbackChildLabel = _deriveFallbackChildLabel(widget);
      if (fallbackChildLabel != null) {
        explicitChildLabel ??= fallbackChildLabel.value;
        childLabelGuarantee = _mergeGuarantees(
          childLabelGuarantee,
          fallbackChildLabel.guarantee,
        );
        if (labelSource == LabelSource.none) {
          labelSource = fallbackChildLabel.source;
        }
      }
    } else if (labelSource == LabelSource.none && explicitChildLabel != null) {
      labelSource = LabelSource.textChild;
    }

    if (childLabelGuarantee != LabelGuarantee.none) {
      labelGuarantee = _mergeGuarantees(labelGuarantee, childLabelGuarantee);
      if (labelSource == LabelSource.none) {
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
      branchGroupId: widget.branchGroupId,
      branchValue: widget.branchValue,
    );
  }

  _BuiltChildren _buildChildren(WidgetNode widget) {
    final nodes = <SemanticNode>[];
    final slotNodes = <String, SemanticNode>{};
    final slotOrder = knownSemantics[widget.widgetType]?.slotTraversalOrder ??
        widget.slots.keys.toList();

    for (final slotName in slotOrder) {
      final childWidget = widget.slots[slotName];
      if (childWidget == null) continue;
      _appendBuiltNodes(
        childWidget,
        nodes,
        slotNodes,
        slotName: slotName,
      );
    }

    for (final child in widget.children) {
      _appendBuiltNodes(child, nodes, slotNodes);
    }

    return _BuiltChildren(nodes: nodes, slotNodes: slotNodes);
  }

  void _appendBuiltNodes(
    WidgetNode child,
    List<SemanticNode> aggregate,
    Map<String, SemanticNode> slotNodes, {
    String? slotName,
  }) {
    if (child.nodeType == WidgetNodeType.conditionalBranch) {
      for (final branch in child.branchChildren) {
        _appendBuiltNodes(branch, aggregate, slotNodes, slotName: slotName);
      }
      return;
    }

    final built = build(child);
    if (built != null) {
      aggregate.add(built);
      if (slotName != null && !slotNodes.containsKey(slotName)) {
        slotNodes[slotName] = built;
      }
    }
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

  _LabelInfo? _deriveLabelInfo(WidgetNode widget) {
    if (widget.widgetType == 'Text' && widget.positionalArgs.isNotEmpty) {
      return _labelFromExpression(
        widget.positionalArgs.first,
        source: LabelSource.textChild,
      );
    }

    if (widget.widgetType == 'IconButton') {
      final tooltip = widget.props['tooltip'];
      final tooltipInfo =
          _labelFromExpression(tooltip, source: LabelSource.tooltip);
      if (tooltipInfo != null) return tooltipInfo;
    }

    if (widget.widgetType == 'FloatingActionButton') {
      final tooltip = widget.props['tooltip'];
      final tooltipInfo =
          _labelFromExpression(tooltip, source: LabelSource.tooltip);
      if (tooltipInfo != null) return tooltipInfo;
    }

    if (widget.widgetType == 'Icon') {
      final semanticLabel = widget.props['semanticLabel'];
      final labelInfo = _labelFromExpression(
        semanticLabel,
        source: LabelSource.other,
      );
      if (labelInfo != null) return labelInfo;
    }

    if (widget.widgetType == 'Semantics') {
      final semanticsLabel = widget.props['label'];
      final labelInfo = _labelFromExpression(
        semanticsLabel,
        source: LabelSource.semanticsWidget,
      );
      if (labelInfo != null) return labelInfo;
    }

    return null;
  }

  _LabelInfo? _deriveFallbackChildLabel(WidgetNode widget) {
    const candidates = ['child', 'label'];
    for (final prop in candidates) {
      final info = _extractTextLabel(widget.props[prop]);
      if (info != null) {
        return info;
      }
    }
    return null;
  }

  _LabelInfo? _extractTextLabel(Expression? expression) {
    if (expression == null) return null;
    if (expression is ConditionalExpression) {
      final thenInfo = _extractTextLabel(expression.thenExpression);
      final elseInfo = _extractTextLabel(expression.elseExpression);
      return _combineLabelInfo(thenInfo, elseInfo);
    }

    if (expression is InstanceCreationExpression) {
      final typeName = _instanceTypeName(expression);
      if (typeName == 'Text') {
        if (expression.argumentList.arguments.isEmpty) {
          return null;
        }
        final firstArg = expression.argumentList.arguments.first;
        final valueExpression =
            firstArg is NamedExpression ? firstArg.expression : firstArg;
        return _labelFromExpression(
          valueExpression,
          source: LabelSource.textChild,
        );
      }
    }

    return null;
  }

  _LabelInfo? _combineLabelInfo(_LabelInfo? a, _LabelInfo? b) {
    if (a == null) return b;
    if (b == null) return a;
    final guarantee = _mergeGuarantees(a.guarantee, b.guarantee);
    final value = a.value ?? b.value;
    final source = a.source != LabelSource.none ? a.source : b.source;
    return _LabelInfo(value: value, guarantee: guarantee, source: source);
  }

  _MergedChildLabel _mergeChildLabels(
    List<SemanticNode> children, {
    String? existingText,
    LabelGuarantee existingGuarantee = LabelGuarantee.none,
  }) {
    final parts = <String>[];
    if (existingText != null && existingText.isNotEmpty) {
      parts.add(existingText);
    }

    var guarantee = existingGuarantee;
    for (final child in children) {
      final childLabel = child.effectiveLabel;
      if (childLabel != null && childLabel.isNotEmpty) {
        parts.add(childLabel);
      }
      guarantee = _mergeGuarantees(guarantee, child.labelGuarantee);
    }

    final text = parts.isEmpty ? null : parts.join(' ').trim();
    return _MergedChildLabel(text: text, guarantee: guarantee);
  }

  LabelGuarantee _mergeGuarantees(
    LabelGuarantee current,
    LabelGuarantee incoming,
  ) {
    return incoming.index > current.index ? incoming : current;
  }

  _LabelInfo? _labelFromExpression(
    Expression? expression, {
    required LabelSource source,
  }) {
    if (expression == null || expression is NullLiteral) return null;
    final literal = _literalString(expression);
    if (literal != null) {
      return _LabelInfo(
        value: literal,
        guarantee: LabelGuarantee.hasStaticLabel,
        source: source,
      );
    }
    if (!_isStringExpression(expression)) {
      return null;
    }
    return _LabelInfo(
      value: null,
      guarantee: LabelGuarantee.hasLabelButDynamic,
      source: source,
    );
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
    if (expression is StringInterpolation) {
      final buffer = StringBuffer();
      for (final element in expression.elements) {
        if (element is InterpolationString) {
          buffer.write(element.value);
        } else {
          return null;
        }
      }
      return buffer.toString();
    }
    return null;
  }

  bool _isStringExpression(Expression expression) {
    final type = expression.staticType;
    if (type is InterfaceType) {
      return type.isDartCoreString;
    }
    if (type == null) {
      return true;
    }
    return expression is SimpleStringLiteral ||
        expression is AdjacentStrings ||
        expression is StringInterpolation;
  }

  String? _instanceTypeName(InstanceCreationExpression expression) {
    final type = expression.staticType ?? expression.constructorName.type.type;
    if (type is InterfaceType) {
      return type.element.name;
    }
    return expression.constructorName.type.toSource();
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

class _LabelInfo {
  const _LabelInfo({
    required this.value,
    required this.guarantee,
    required this.source,
  });

  final String? value;
  final LabelGuarantee guarantee;
  final LabelSource source;
}

class _MergedChildLabel {
  const _MergedChildLabel({
    required this.text,
    required this.guarantee,
  });

  final String? text;
  final LabelGuarantee guarantee;
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
