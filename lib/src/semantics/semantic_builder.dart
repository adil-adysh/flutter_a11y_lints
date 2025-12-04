import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';

import '../widget_tree/widget_node.dart';
import 'known_semantics.dart';
import 'semantic_context.dart';
import 'semantic_node.dart';

/// SemanticBuilder
///
/// Responsible for converting a `WidgetNode` tree (an AST-derived,
/// control-flow-aware representation of widget instantiations) into a
/// `SemanticNode` tree — a static approximation of Flutter's runtime
/// `Semantics` tree. The builder must be deterministic and run synchronously
/// using only information available from resolved AST nodes and simple
/// constant-evaluation helpers exposed by `BuildSemanticContext`.
///
/// Important notes for contributors:
/// - Special semantics widgets (Semantics/MergeSemantics/ExcludeSemantics/
///   BlockSemantics/IndexedSemantics) are handled first since they alter
///   descendant visibility, labels, or focusability.
/// - `KnownSemantics` provides per-widget metadata (role, controlKind,
///   interaction flags, slot traversal order) and is the single source of
///   truth for built-in widgets' static behaviour.
/// - `branchGroupId` and `branchValue` are copied from `WidgetNode` into
///   `SemanticNode`. This preserves knowledge of mutually-exclusive branches
///   (e.g., widgets produced by `if`/`else` constructs) so heuristics can
///   ignore siblings that cannot co-occur at runtime.
/// - The builder populates `explicitChildLabel`, `labelGuarantee`, and
///   `labelSource` so rules can make high-confidence decisions about whether
///   a node is accessible-label-complete.

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
    /// Entry point: convert a `WidgetNode` (root of a build expression) into
    /// a `SemanticNode` tree. Returns `null` when the input is null or cannot
    /// be converted. `enableHeuristics` may be used to enable conservative
    /// heuristic labeling during the build.
    if (widget == null) return null;
    final ctx = BuildSemanticContext(
      global: globalContext,
      enableHeuristics: enableHeuristics,
      unit: unit,
    );
    return _buildNode(widget, ctx);
  }

  /// Internal dispatch: handle conditional branch nodes and route special
  /// semantics widgets to their dedicated builders. Returns a `SemanticNode`
  /// or `null` if the widget produces no semantic node.
  SemanticNode? _buildNode(WidgetNode? widget, BuildSemanticContext ctx) {
    if (widget == null) return null;

    if (widget.nodeType == WidgetNodeType.conditionalBranch) {
      // For a `conditionalBranch` node the builder attempts to build each
      // mutually-exclusive branch and returns the first non-null result. This
      // mirrors the runtime behavior where only one branch is active.
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
    // Build a semantic node for a standard (non-wrapper) widget.
    // Steps:
    // 1. Lookup KnownSemantics metadata for this widget type (with heuristic fallback)
    // 2. Build semantic children according to slotTraversalOrder + children list
    // 3. Derive a label from widget props, tooltips, text children, etc.
    // 4. Merge child labels when the widget merges descendants
    // 5. Return a `SemanticNode` containing combined semantics for rules.

    // Get known semantics or infer heuristic metadata for unregistered widgets
    var known = ctx.knownSemantics[widget.widgetType];
    bool isHeuristic = false;
    if (known == null) {
      known = _inferHeuristicSemantics(widget) ?? _defaultSemantics;
      isHeuristic = true;
    }

    final builtChildren = _buildChildren(widget, ctx);

    final derivedLabelInfo = _deriveLabelInfo(widget);
    var label = derivedLabelInfo?.value;
    var labelGuarantee = derivedLabelInfo?.guarantee ?? LabelGuarantee.none;
    var labelSource = derivedLabelInfo?.source ?? LabelSource.none;
    String? explicitChildLabel;
    var childLabelGuarantee = LabelGuarantee.none;

    // Try schema-based attribute resolution for label
    if (known.schema.label.isNotEmpty) {
      final schemaLabelInfo =
          _resolveAttribute(widget, known.schema.label, builtChildren);
      if (schemaLabelInfo != null) {
        // Only set explicitChildLabel if this came from a slot child
        // For direct prop/positional sources, use it as the main label
        final isFromSlot = known.schema.label.any((s) =>
            s is SlotSource && schemaLabelInfo.source != LabelSource.none);

        if (isFromSlot) {
          explicitChildLabel = schemaLabelInfo.value;
          childLabelGuarantee = schemaLabelInfo.guarantee;
        } else {
          // Direct property/positional extraction
          if (label == null) {
            label = schemaLabelInfo.value;
            labelGuarantee = schemaLabelInfo.guarantee;
          }
        }

        // Always update labelSource if schema provides it and we didn't have one before
        if (labelSource == LabelSource.none) {
          labelSource = schemaLabelInfo.source;
        }
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
      // Preserve branch metadata so later heuristics can determine
      // mutual-exclusion between nodes originating from different
      // conditional branches.
      branchGroupId: widget.branchGroupId,
      branchValue: widget.branchValue,
      rawAttributes: widget.props,
      isHeuristic: isHeuristic,
    );
  }

  SemanticNode? _buildSemanticsWrapper(
    WidgetNode widget,
    BuildSemanticContext ctx,
  ) {
    // Handle `Semantics(...)` widgets which may override role/label and
    // can mark a semantic boundary. This wrapper may set `mergesDescendants`
    // when `container: true` or when a `label` is provided.
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
    // `MergeSemantics` aggregates descendant labels and actions into a single
    // parent node. Children remain in the physical tree but are not separate
    // accessibility focus targets.
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
    // `ExcludeSemantics` temporarily marks built descendants as excluded from
    // accessibility. We track `excludeDepth` in the context in case of nested
    // exclusions.
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
    // `BlockSemantics` marks an overlay that blocks semantics behind it. We
    // track `blockDepth` so that focus-order assignment can skip nodes that are
    // conceptually behind a blocking overlay.
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
    // `IndexedSemantics` attaches an index to the semantic node when the
    // `index` argument is a compile-time integer. This supports list indexing
    // and list-item grouping heuristics.
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
    // Compose semantic properties by overriding base child values with
    // explicitly-provided values from the wrapper. This allows `Semantics`
    // widgets to selectively override child semantics (label, role, toggled
    // state, etc.) while otherwise inheriting from their primary child.
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
      // Copy branch information from the originating WidgetNode so that the
      // mutual-exclusion semantics are preserved through the semantic tree.
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
      rawAttributes: widget.props,
      isHeuristic: base?.isHeuristic ?? false,
    );
  }

  _BuiltChildren _buildChildren(
    WidgetNode widget,
    BuildSemanticContext ctx,
  ) {
    // Build and return the semantic children for `widget`.
    // We follow `slotTraversalOrder` from KnownSemantics (if available) to
    // ensure deterministic ordering of named slots (e.g. ListTile's leading,
    // title, subtitle, trailing) before falling back to the `slots.keys`
    // order. Positional `children` come after slots.
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
    // Append nodes built from `child` into `aggregate`, and record the first
    // built node for the `slotName` (if provided) in `slotNodes`.
    if (child.nodeType == WidgetNodeType.conditionalBranch) {
      // Unfold conditional branches: we append results from each branch so
      // that downstream merging logic (and branchId propagation) can see all
      // mutually-exclusive alternatives.
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

  /// Infer heuristic semantics for widgets not in the KnownSemantics registry.
  ///
  /// Tier 1 fallback: if a widget has common callback patterns (onTap, onPressed),
  /// assume it's a button. If it has label/text props, create a simple schema to
  /// extract them. This provides basic accessibility support for custom widgets.
  KnownSemantics? _inferHeuristicSemantics(WidgetNode widget) {
    // Check if the widget has tap/press callbacks
    final hasTap = widget.props.containsKey('onTap') ||
        widget.props.containsKey('onPressed') ||
        widget.props.containsKey('onLongPress');

    if (!hasTap) {
      // No obvious callback; cannot infer strong semantics
      return null;
    }

    // Build a simple schema: check for common label/text props
    final labelSources = <SemanticSource>[];
    if (widget.props.containsKey('label')) {
      labelSources.add(PropSource('label'));
    }
    if (widget.props.containsKey('text')) {
      labelSources.add(PropSource('text'));
    }
    if (widget.props.containsKey('tooltip')) {
      labelSources.add(PropSource('tooltip'));
    }

    return KnownSemantics(
      role: SemanticRole.button,
      controlKind: ControlKind.none,
      isFocusable: true,
      isEnabledByDefault: true,
      hasTap: true,
      hasLongPress: widget.props.containsKey('onLongPress'),
      hasIncrease: false,
      hasDecrease: false,
      isToggled: false,
      isChecked: false,
      mergesDescendants: true,
      implicitlyMergesSemantics: true,
      excludesDescendants: false,
      blocksBehind: false,
      isPureContainer: false,
      slotTraversalOrder: widget.slots.keys.toList(),
      schema: SemanticSchema(label: labelSources),
    );
  }

  bool _computeIsEnabled(WidgetNode widget, KnownSemantics known) {
    // Determine whether the control should be considered enabled. Prefer the
    // widget-level default from `KnownSemantics` but override when a
    // callback-like argument is present; a `null` literal explicitly disables
    // the callback.
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

  /// Generic attribute resolution using the declarative schema.
  ///
  /// Attempts to extract a semantic attribute (label, tooltip, value, etc.)
  /// from a widget instance by trying sources in priority order:
  ///
  /// 1. **PropSource:** Look up a named argument in `widget.props`.
  /// 2. **PositionalSource:** Look up a positional argument in `widget.positionalArgs`.
  /// 3. **SlotSource:** Look up a built child in a named slot. If the child
  ///    exists and has a label, return it with **propagated labelGuarantee**.
  ///
  /// Returns `null` if no source succeeds.
  ///
  /// Label source provenance: Each source can specify a sourceOverride to
  /// indicate which LabelSource should be used. This preserves information
  /// about data origin (e.g., tooltip extraction marks source as LabelSource.tooltip).
  _LabelInfo? _resolveAttribute(
    WidgetNode widget,
    List<SemanticSource> sources,
    _BuiltChildren children,
  ) {
    for (final source in sources) {
      if (source is PropSource) {
        // Try named argument
        final expr = widget.props[source.name];
        // Use sourceOverride if provided, else use smart defaults
        final labelSource = source.sourceOverride ?? LabelSource.other;
        final info = _labelFromExpression(expr, source: labelSource);
        if (info != null) return info;
      } else if (source is PositionalSource) {
        // Try positional argument
        if (source.index < widget.positionalArgs.length) {
          final expr = widget.positionalArgs[source.index];
          final labelSource = source.sourceOverride ?? LabelSource.textChild;
          final info = _labelFromExpression(expr, source: labelSource);
          if (info != null) return info;
        }
      } else if (source is SlotSource) {
        // Try slot child: use the built node's label if available
        final childNode = children.slotNodes[source.slotName];
        if (childNode != null &&
            childNode.labelGuarantee != LabelGuarantee.none) {
          final labelSource = source.sourceOverride ?? LabelSource.textChild;
          return _LabelInfo(
            value: childNode.effectiveLabel,
            // Crucially, propagate the child's labelGuarantee
            guarantee: childNode.labelGuarantee,
            source: labelSource,
          );
        }
      }
    }

    return null;
  }

  _LabelInfo? _deriveLabelInfo(WidgetNode widget) {
    // Look for label sources that are local to this widget instance.
    // This uses the schema from KnownSemantics when available, otherwise
    // falls back to hardcoded checks for special cases like Semantics.label.

    // For Semantics widget, always check the label prop directly
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
    // Try extracting a text label from common prop names when no explicit
    // label was found. This is a conservative fallback and should not be
    // relied upon for high-confidence rules unless the guarantee is static.
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
    // Try to extract a textual label from an expression by recognizing
    // `Text(...)` constructors and conditional expressions composed of
    // such constructors.
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
    // Combine two label infos (e.g., from conditional branches) by choosing
    // the stronger guarantee and a non-null value when available.
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
    // Aggregate textual labels from descendant nodes into a single merged
    // label string. The guarantee reflects the strongest guarantee among
    // contributing nodes. This is used when a parent widget implicitly or
    // explicitly merges descendant semantics (e.g., ListTile, ElevatedButton).
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
    // Combine two guarantees: the higher enum index represents a stronger
    // guarantee (none < hasLabelButDynamic < hasStaticLabel).
    return incoming.index > current.index ? incoming : current;
  }

  _LabelInfo? _labelFromExpression(
    Expression? expression, {
    required LabelSource source,
  }) {
    // Convert an expression into a `_LabelInfo` describing whether the
    // expression is a compile-time string or a dynamic string-like value.
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
    // Return a string when `expression` is a compile-time string literal
    // (including adjacent strings and pure interpolations with only
    // `InterpolationString` parts). Return null for non-constant or
    // interpolated expressions that include values.
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
    // Heuristic test for whether an expression is string-like. When `staticType`
    // is available we use it; otherwise we conservatively inspect the syntax
    // node shapes (literals / interpolations) and return true.
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
    // Resolve the type name for an `InstanceCreationExpression`. Prefer the
    // analyzer-provided `staticType` when available; otherwise fall back to
    // the source text of the constructor's type name.
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
