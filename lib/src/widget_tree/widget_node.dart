import 'package:analyzer/dart/ast/ast.dart';

import '../facts/fact_store.dart' show BranchPath, FactProvenance;

/// Classification for widget nodes so we can retain control-flow structure.
enum WidgetNodeType { standard, conditionalBranch, loop }

/// Lightweight representation of a widget instantiation in the AST.
class WidgetNode {
  WidgetNode({
    required this.widgetType,
    required this.astNode,
    required this.positionalArgs,
    required this.props,
    required this.slots,
    required this.children,
    this.nodeType = WidgetNodeType.standard,
    this.branchGroupId,
    this.branchValue,
    this.branchPath = const BranchPath([]),
    this.sourceUri,
    this.evidenceProvenance = FactProvenance.exact,
    List<WidgetNode>? branchChildren,
  }) : branchChildren = branchChildren ?? const <WidgetNode>[];

  final String widgetType;
  final AstNode astNode;
  final List<Expression> positionalArgs;
  final Map<String, Expression> props;
  final Map<String, WidgetNode?> slots;
  final List<WidgetNode> children;

  /// Indicates whether this node represents an actual widget or a control-flow
  /// construct (e.g., `if`/`?:` wrappers).
  final WidgetNodeType nodeType;

  /// Identifier shared by branches that belong to the same conditional group.
  final int? branchGroupId;

  /// Branch slot within [branchGroupId] (e.g., 0 = then, 1 = else).
  final int? branchValue;

  /// Every unresolved conditional enclosing this node, outermost first.
  final BranchPath branchPath;

  /// Source file that supplied this widget expression. Expanded custom-widget
  /// nodes retain their implementation source rather than borrowing the
  /// caller's URI with an unrelated offset.
  final Uri? sourceUri;

  /// Evidence from a custom widget's resolved implementation is derived from
  /// the call site, never direct evidence about that call expression.
  final FactProvenance evidenceProvenance;

  /// Children that correspond to mutually exclusive branches for
  /// [WidgetNodeType.conditionalBranch]. Standard widget nodes leave this
  /// collection empty.
  final List<WidgetNode> branchChildren;

  WidgetNode copyWith({
    String? widgetType,
    AstNode? astNode,
    List<Expression>? positionalArgs,
    Map<String, Expression>? props,
    Map<String, WidgetNode?>? slots,
    List<WidgetNode>? children,
    WidgetNodeType? nodeType,
    int? branchGroupId,
    int? branchValue,
    BranchPath? branchPath,
    Uri? sourceUri,
    FactProvenance? evidenceProvenance,
    List<WidgetNode>? branchChildren,
  }) =>
      WidgetNode(
        widgetType: widgetType ?? this.widgetType,
        astNode: astNode ?? this.astNode,
        positionalArgs: positionalArgs ?? this.positionalArgs,
        props: props ?? this.props,
        slots: slots ?? this.slots,
        children: children ?? this.children,
        nodeType: nodeType ?? this.nodeType,
        branchGroupId: branchGroupId ?? this.branchGroupId,
        branchValue: branchValue ?? this.branchValue,
        branchPath: branchPath ?? this.branchPath,
        sourceUri: sourceUri ?? this.sourceUri,
        evidenceProvenance: evidenceProvenance ?? this.evidenceProvenance,
        branchChildren: branchChildren ?? this.branchChildren,
      );
}

/// `WidgetNode` is a compact representation of a widget instantiation used by
/// the widget→semantic pipeline. It preserves:
/// - the originating `AstNode` (for file/offset location information),
/// - constructor positional and named args (stored as `positionalArgs` and
///   `props`),
/// - named slot children (e.g., `child`, `title`, `leading`) in `slots`, and
/// - positional collection children in `children`.
///
/// Control-flow constructs (conditional branches) are represented using
/// `WidgetNodeType.conditionalBranch` and the `branchChildren` list; when a
/// branch cannot be constant-folded the builder assigns `branchGroupId` and
/// per-branch `branchValue` so that the semantics builder can carry that
/// mutual-exclusion information into the final `SemanticNode` tree.
