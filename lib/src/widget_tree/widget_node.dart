import 'package:analyzer/dart/ast/ast.dart';

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

  /// Children that correspond to mutually exclusive branches for
  /// [WidgetNodeType.conditionalBranch]. Standard widget nodes leave this
  /// collection empty.
  final List<WidgetNode> branchChildren;
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
