import 'package:analyzer/dart/ast/ast.dart';
import 'package:meta/meta.dart';

import 'known_semantics.dart';

/// How confident the builder is that a node has a usable label.
///
/// - `none` means there is no discovered label source.
/// - `hasLabelButDynamic` indicates the widget exposes a label-like
///   parameter but its value is not a statically-known string (e.g. an
///   expression or variable). Assistive tech may still announce it at runtime.
/// - `hasStaticLabel` means a compile-time string was found (best confidence).
enum LabelGuarantee { none, hasLabelButDynamic, hasStaticLabel }

/// Origin of a discovered label. Rules may use this to prefer certain label
/// sources (e.g., prefer explicit Semantics.label over a tooltip when
/// resolving conflicts).
enum LabelSource {
  none,
  tooltip,
  textChild,
  semanticsWidget,
  inputDecoration,
  customWidgetParameter,
  valueToString,
  other,
}

/// Simplified semantic IR node used by rules and the tree annotator.
///
/// `SemanticNode` intentionally stores both raw discovery data (e.g. the
/// originating `AstNode`, `offset`, `length`) and derived semantics (role,
/// controlKind, label, labelGuarantee, explicitChildLabel). This design lets
/// rules make high-confidence checks without rereading the AST or invoking the
/// analyzer.
@immutable
class SemanticNode {
  const SemanticNode({
    required this.widgetType,
    required this.astNode,
    required this.fileUri,
    required this.offset,
    required this.length,
    required this.role,
    required this.controlKind,
    required this.isFocusable,
    required this.isEnabled,
    required this.hasTap,
    required this.hasLongPress,
    required this.hasIncrease,
    required this.hasDecrease,
    required this.isToggled,
    required this.isChecked,
    required this.mergesDescendants,
    required this.excludesDescendants,
    required this.blocksBehind,
    required this.label,
    required this.labelGuarantee,
    required this.labelSource,
    required this.explicitChildLabel,
    required this.children,
    this.branchGroupId,
    this.branchValue,
    this.id,
    this.parentId,
    this.siblingIndex = 0,
    this.depth = 0,
    this.preOrderIndex,
    this.focusOrderIndex,
    this.layoutGroupId,
    this.listItemGroupId,
    this.isPrimaryInGroup = false,
    this.tooltip,
    this.value,
    this.semanticIndex,
    this.isSemanticBoundary = false,
    this.isCompositeControl = false,
    this.isPureContainer = false,
    this.isInMutuallyExclusiveGroup = false,
    this.hasScroll = false,
    this.hasDismiss = false,
  });

  final String widgetType;
  final AstNode astNode;
  final Uri fileUri;
  final int offset;
  final int length;

  final SemanticRole role;
  final ControlKind controlKind;

  final bool isFocusable;
  final bool isEnabled;
  final bool hasTap;
  final bool hasLongPress;
  final bool hasIncrease;
  final bool hasDecrease;
  final bool isToggled;
  final bool isChecked;

  final bool mergesDescendants;
  final bool excludesDescendants;
  final bool blocksBehind;

  final String? label;
  final LabelGuarantee labelGuarantee;
  final LabelSource labelSource;
  final String? explicitChildLabel;
  final String? tooltip;
  final String? value;

  final List<SemanticNode> children;

  /// Identifies mutually exclusive states originating from the same
  /// conditional in the widget tree. Nodes that share the same
  /// [branchGroupId] but different [branchValue] should not both be considered
  /// simultaneously by heuristics.
  final int? branchGroupId;

  /// Position within a conditional group (e.g. 0 for the "true" branch,
  /// 1 for the "false" branch).
  final int? branchValue;

  /// Unique identifier assigned when the semantic tree is annotated.
  final int? id;

  /// Identifier of the parent node after annotation.
  final int? parentId;

  /// Index within the parent's children list.
  final int siblingIndex;

  /// Depth within the semantic tree (0 for root).
  final int depth;

  /// Depth-first order index assigned during tree annotation.
  final int? preOrderIndex;

  /// Order in which assistive technologies would focus this node.
  final int? focusOrderIndex;

  final int? layoutGroupId;
  final int? listItemGroupId;
  final bool isPrimaryInGroup;

  /// Whether this node establishes a semantic boundary (e.g. Semantics widget).
  final bool isSemanticBoundary;

  /// Whether this node aggregates text/control semantics from children.
  final bool isCompositeControl;

  /// Whether this widget behaves as a pure layout container.
  final bool isPureContainer;

  final bool isInMutuallyExclusiveGroup;
  final bool hasScroll;
  final bool hasDismiss;
  final int? semanticIndex;

  String? get effectiveLabel {
    final pieces = <String>[];
    if (label != null && label!.isNotEmpty) {
      pieces.add(label!);
    }
    if (tooltip != null && tooltip!.isNotEmpty) {
      pieces.add(tooltip!);
    }
    if (explicitChildLabel != null && explicitChildLabel!.isNotEmpty) {
      pieces.add(explicitChildLabel!);
    }
    if (pieces.isEmpty) {
      return null;
    }
    return pieces.join('\n');
  }

  SemanticNode copyWith({
    String? widgetType,
    AstNode? astNode,
    Uri? fileUri,
    int? offset,
    int? length,
    SemanticRole? role,
    ControlKind? controlKind,
    bool? isFocusable,
    bool? isEnabled,
    bool? hasTap,
    bool? hasLongPress,
    bool? hasIncrease,
    bool? hasDecrease,
    bool? isToggled,
    bool? isChecked,
    bool? mergesDescendants,
    bool? excludesDescendants,
    bool? blocksBehind,
    String? label,
    LabelGuarantee? labelGuarantee,
    LabelSource? labelSource,
    String? explicitChildLabel,
    List<SemanticNode>? children,
    int? branchGroupId,
    int? branchValue,
    int? id,
    int? parentId,
    int? siblingIndex,
    int? depth,
    int? preOrderIndex,
    int? focusOrderIndex,
    int? layoutGroupId,
    int? listItemGroupId,
    bool? isPrimaryInGroup,
    String? tooltip,
    String? value,
    int? semanticIndex,
    bool? isSemanticBoundary,
    bool? isCompositeControl,
    bool? isPureContainer,
    bool? isInMutuallyExclusiveGroup,
    bool? hasScroll,
    bool? hasDismiss,
  }) {
    return SemanticNode(
      widgetType: widgetType ?? this.widgetType,
      astNode: astNode ?? this.astNode,
      fileUri: fileUri ?? this.fileUri,
      offset: offset ?? this.offset,
      length: length ?? this.length,
      role: role ?? this.role,
      controlKind: controlKind ?? this.controlKind,
      isFocusable: isFocusable ?? this.isFocusable,
      isEnabled: isEnabled ?? this.isEnabled,
      hasTap: hasTap ?? this.hasTap,
      hasLongPress: hasLongPress ?? this.hasLongPress,
      hasIncrease: hasIncrease ?? this.hasIncrease,
      hasDecrease: hasDecrease ?? this.hasDecrease,
      isToggled: isToggled ?? this.isToggled,
      isChecked: isChecked ?? this.isChecked,
      mergesDescendants: mergesDescendants ?? this.mergesDescendants,
      excludesDescendants: excludesDescendants ?? this.excludesDescendants,
      blocksBehind: blocksBehind ?? this.blocksBehind,
      label: label ?? this.label,
      labelGuarantee: labelGuarantee ?? this.labelGuarantee,
      labelSource: labelSource ?? this.labelSource,
      explicitChildLabel: explicitChildLabel ?? this.explicitChildLabel,
      children: children ?? this.children,
      branchGroupId: branchGroupId ?? this.branchGroupId,
      branchValue: branchValue ?? this.branchValue,
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      siblingIndex: siblingIndex ?? this.siblingIndex,
      depth: depth ?? this.depth,
      preOrderIndex: preOrderIndex ?? this.preOrderIndex,
      focusOrderIndex: focusOrderIndex ?? this.focusOrderIndex,
      layoutGroupId: layoutGroupId ?? this.layoutGroupId,
      listItemGroupId: listItemGroupId ?? this.listItemGroupId,
      isPrimaryInGroup: isPrimaryInGroup ?? this.isPrimaryInGroup,
      tooltip: tooltip ?? this.tooltip,
      value: value ?? this.value,
      semanticIndex: semanticIndex ?? this.semanticIndex,
      isSemanticBoundary: isSemanticBoundary ?? this.isSemanticBoundary,
      isCompositeControl: isCompositeControl ?? this.isCompositeControl,
      isPureContainer: isPureContainer ?? this.isPureContainer,
      isInMutuallyExclusiveGroup:
          isInMutuallyExclusiveGroup ?? this.isInMutuallyExclusiveGroup,
      hasScroll: hasScroll ?? this.hasScroll,
      hasDismiss: hasDismiss ?? this.hasDismiss,
    );
  }
}
