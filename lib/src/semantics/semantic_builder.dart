import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';

import '../widget_tree/widget_node.dart';
import 'known_semantics.dart';
import 'semantic_context.dart';
import 'semantic_node.dart';

class SemanticBuilder {
  SemanticBuilder({
    required this.unit,
    required this.globalContext,
  }) : fileUri = Uri.file(unit.path);

  final ResolvedUnitResult unit;
  final GlobalSemanticContext globalContext;
  final Uri fileUri;

  SemanticNode? build(
    WidgetNode? widget, {
    bool enableHeuristics = false,
  }) {
    if (widget == null) return null;
    final ctx = BuildSemanticContext(
      global: globalContext,
      enableHeuristics: enableHeuristics,
    );
    return _buildNode(widget, ctx);
  }

  SemanticNode? _buildNode(WidgetNode? widget, BuildSemanticContext ctx) {
    if (widget == null) return null;

    if (widget.nodeType == WidgetNodeType.conditionalBranch) {
      for (final branch in widget.branchChildren) {
        final built = _buildNode(branch, ctx);
        if (built != null) {
          return built;
        }
      }
      return null;
    }

    switch (widget.widgetType) {
      case 'Semantics':
        return _buildSemanticsWrapper(widget, ctx);
      case 'MergeSemantics':
        return _buildMergeSemantics(widget, ctx);
      case 'ExcludeSemantics':
        return _buildExcludeSemantics(widget, ctx);
      case 'BlockSemantics':
        return _buildBlockSemantics(widget, ctx);
      case 'IndexedSemantics':
        return _buildIndexedSemantics(widget, ctx);
      default:
        return _buildStandardNode(widget, ctx);
    }
  }

  SemanticNode? _buildStandardNode(
    WidgetNode widget,
    BuildSemanticContext ctx,
  ) {
    final known = ctx.knownSemantics[widget.widgetType] ?? _defaultSemantics;
    final builtChildren = _buildChildren(widget, ctx);

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

  SemanticNode? _buildSemanticsWrapper(
    WidgetNode widget,
    BuildSemanticContext ctx,
  ) {
    final builtChildren = _buildChildren(widget, ctx);
    final nodes = builtChildren.nodes;
    final baseChild = nodes.isNotEmpty ? nodes.first : null;
    final labelInfo = _labelFromExpression(
      widget.props['label'],
      source: LabelSource.semanticsWidget,
    );
    final tooltip = ctx.evalString(widget.props['tooltip']);
    final value = ctx.evalString(widget.props['value']);
    final mergesDescendants =
        (ctx.evalBool(widget.props['container']) ?? false) || labelInfo != null;
    final mergedChildLabels = _mergeChildLabels(nodes);

    SemanticRole? roleOverride;
    if (ctx.evalBool(widget.props['button']) == true) {
      roleOverride = SemanticRole.button;
    } else if (ctx.evalBool(widget.props['header']) == true) {
      roleOverride = SemanticRole.header;
    }

    return _wrapWithInheritedSemantics(
      widget: widget,
      children: nodes,
      baseChild: baseChild,
      mergesDescendants: mergesDescendants,
      isSemanticBoundary: true,
      labelOverride: labelInfo?.value,
      labelGuaranteeOverride: labelInfo?.guarantee,
      labelSourceOverride: labelInfo?.source,
      explicitChildLabelOverride: mergedChildLabels.text,
      explicitChildLabelGuarantee: mergedChildLabels.guarantee,
      tooltipOverride: tooltip,
      valueOverride: value,
      isFocusableOverride: ctx.evalBool(widget.props['focusable']),
      isEnabledOverride: ctx.evalBool(widget.props['enabled']),
      isToggledOverride: ctx.evalBool(widget.props['toggled']),
      isCheckedOverride: ctx.evalBool(widget.props['checked']),
      roleOverride: roleOverride,
    );
  }

  SemanticNode? _buildMergeSemantics(
    WidgetNode widget,
    BuildSemanticContext ctx,
  ) {
    final builtChildren = _buildChildren(widget, ctx);
    if (builtChildren.nodes.isEmpty) {
      return null;
    }
    final merged = _mergeChildLabels(builtChildren.nodes);
    return _wrapWithInheritedSemantics(
      widget: widget,
      children: builtChildren.nodes,
      baseChild: builtChildren.nodes.first,
      mergesDescendants: true,
      isSemanticBoundary: true,
      explicitChildLabelOverride: merged.text,
      explicitChildLabelGuarantee: merged.guarantee,
    );
  }

  SemanticNode? _buildExcludeSemantics(
    WidgetNode widget,
    BuildSemanticContext ctx,
  ) {
    ctx.excludeDepth++;
    final builtChildren = _buildChildren(widget, ctx);
    ctx.excludeDepth--;
    if (builtChildren.nodes.isEmpty) {
      return null;
    }
    return _wrapWithInheritedSemantics(
      widget: widget,
      children: builtChildren.nodes,
      baseChild: null,
      excludesDescendants: true,
      isSemanticBoundary: true,
      isFocusableOverride: false,
      isEnabledOverride: false,
      hasTapOverride: false,
      hasLongPressOverride: false,
      hasIncreaseOverride: false,
      hasDecreaseOverride: false,
    );
  }

  SemanticNode? _buildBlockSemantics(
    WidgetNode widget,
    BuildSemanticContext ctx,
  ) {
    ctx.blockDepth++;
    final builtChildren = _buildChildren(widget, ctx);
    ctx.blockDepth--;
    if (builtChildren.nodes.isEmpty) {
      return null;
    }
    return _wrapWithInheritedSemantics(
      widget: widget,
      children: builtChildren.nodes,
      baseChild: builtChildren.nodes.first,
      blocksBehind: true,
      isSemanticBoundary: true,
    );
  }

  SemanticNode? _buildIndexedSemantics(
    WidgetNode widget,
    BuildSemanticContext ctx,
  ) {
    final builtChildren = _buildChildren(widget, ctx);
    if (builtChildren.nodes.isEmpty) {
      return null;
    }
    final index = ctx.evalInt(widget.props['index']);
    return _wrapWithInheritedSemantics(
      widget: widget,
      children: builtChildren.nodes,
      baseChild: builtChildren.nodes.first,
      semanticIndex: index,
      isSemanticBoundary: true,
    );
  }

  SemanticNode _wrapWithInheritedSemantics({
    required WidgetNode widget,
    required List<SemanticNode> children,
    required SemanticNode? baseChild,
    bool mergesDescendants = false,
    bool excludesDescendants = false,
    bool blocksBehind = false,
    bool isSemanticBoundary = false,
    String? labelOverride,
    LabelGuarantee? labelGuaranteeOverride,
    LabelSource? labelSourceOverride,
    String? explicitChildLabelOverride,
    LabelGuarantee? explicitChildLabelGuarantee,
    String? tooltipOverride,
    String? valueOverride,
    int? semanticIndex,
    bool? isFocusableOverride,
    bool? isEnabledOverride,
    bool? hasTapOverride,
    bool? hasLongPressOverride,
    bool? hasIncreaseOverride,
    bool? hasDecreaseOverride,
    bool? isToggledOverride,
    bool? isCheckedOverride,
    bool? isCompositeControlOverride,
    bool? isPureContainerOverride,
    bool? isInMutuallyExclusiveGroupOverride,
    bool? hasScrollOverride,
    bool? hasDismissOverride,
    ControlKind? controlKindOverride,
    SemanticRole? roleOverride,
  }) {
    final base = baseChild;
    final role = roleOverride ?? base?.role ?? SemanticRole.group;
    final controlKind =
        controlKindOverride ?? base?.controlKind ?? ControlKind.none;
    final isFocusable = isFocusableOverride ?? base?.isFocusable ?? false;
    final isEnabled = isEnabledOverride ?? base?.isEnabled ?? true;
    final hasTap = hasTapOverride ?? base?.hasTap ?? false;
    final hasLongPress = hasLongPressOverride ?? base?.hasLongPress ?? false;
    final hasIncrease = hasIncreaseOverride ?? base?.hasIncrease ?? false;
    final hasDecrease = hasDecreaseOverride ?? base?.hasDecrease ?? false;
    final isToggled = isToggledOverride ?? base?.isToggled ?? false;
    final isChecked = isCheckedOverride ?? base?.isChecked ?? false;
    final isCompositeControl =
        isCompositeControlOverride ?? base?.isCompositeControl ?? false;
    final isPureContainer =
        isPureContainerOverride ?? base?.isPureContainer ?? false;
    final isInMutuallyExclusiveGroup = isInMutuallyExclusiveGroupOverride ??
        base?.isInMutuallyExclusiveGroup ??
        false;
    final hasScroll = hasScrollOverride ?? base?.hasScroll ?? false;
    final hasDismiss = hasDismissOverride ?? base?.hasDismiss ?? false;

    var labelGuarantee =
        labelGuaranteeOverride ?? base?.labelGuarantee ?? LabelGuarantee.none;
    var labelSource =
        labelSourceOverride ?? base?.labelSource ?? LabelSource.none;

    if (explicitChildLabelOverride != null &&
        explicitChildLabelGuarantee != null) {
      labelGuarantee = _mergeGuarantees(
        labelGuarantee,
        explicitChildLabelGuarantee,
      );
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
      role: role,
      controlKind: controlKind,
      isFocusable: isFocusable,
      isEnabled: isEnabled,
      hasTap: hasTap,
      hasLongPress: hasLongPress,
      hasIncrease: hasIncrease,
      hasDecrease: hasDecrease,
      isToggled: isToggled,
      isChecked: isChecked,
      mergesDescendants: mergesDescendants,
      excludesDescendants: excludesDescendants,
      blocksBehind: blocksBehind,
      label: labelOverride ?? base?.label,
      labelGuarantee: labelGuarantee,
      labelSource: labelSource,
      explicitChildLabel:
          explicitChildLabelOverride ?? base?.explicitChildLabel,
      children: children,
      branchGroupId: widget.branchGroupId,
      branchValue: widget.branchValue,
      tooltip: tooltipOverride ?? base?.tooltip,
      value: valueOverride ?? base?.value,
      semanticIndex: semanticIndex ?? base?.semanticIndex,
      isSemanticBoundary: isSemanticBoundary,
      isCompositeControl: isCompositeControl,
      isPureContainer: isPureContainer,
      isInMutuallyExclusiveGroup: isInMutuallyExclusiveGroup,
      hasScroll: hasScroll,
      hasDismiss: hasDismiss,
    );
  }

  _BuiltChildren _buildChildren(
    WidgetNode widget,
    BuildSemanticContext ctx,
  ) {
    final nodes = <SemanticNode>[];
    final slotNodes = <String, SemanticNode>{};
    final slotOrder =
        ctx.knownSemantics[widget.widgetType]?.slotTraversalOrder ??
            widget.slots.keys.toList();

    for (final slotName in slotOrder) {
      final childWidget = widget.slots[slotName];
      if (childWidget == null) continue;
      _appendBuiltNodes(
        childWidget,
        nodes,
        slotNodes,
        ctx,
        slotName: slotName,
      );
    }

    for (final child in widget.children) {
      _appendBuiltNodes(child, nodes, slotNodes, ctx);
    }

    return _BuiltChildren(nodes: nodes, slotNodes: slotNodes);
  }

  void _appendBuiltNodes(
    WidgetNode child,
    List<SemanticNode> aggregate,
    Map<String, SemanticNode> slotNodes,
    BuildSemanticContext ctx, {
    String? slotName,
  }) {
    if (child.nodeType == WidgetNodeType.conditionalBranch) {
      for (final branch in child.branchChildren) {
        _appendBuiltNodes(
          branch,
          aggregate,
          slotNodes,
          ctx,
          slotName: slotName,
        );
      }
      return;
    }

    final built = _buildNode(child, ctx);
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
    void collectLabels(SemanticNode node) {
      final childLabel = node.effectiveLabel;
      if (childLabel != null && childLabel.isNotEmpty) {
        parts.add(childLabel);
        guarantee = _mergeGuarantees(guarantee, node.labelGuarantee);
        return;
      }
      for (final grandChild in node.children) {
        collectLabels(grandChild);
      }
    }

    for (final child in children) {
      collectLabels(child);
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
