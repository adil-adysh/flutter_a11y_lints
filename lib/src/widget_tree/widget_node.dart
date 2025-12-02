import 'package:analyzer/dart/ast/ast.dart';

/// Lightweight representation of a widget instantiation in the AST.
class WidgetNode {
  WidgetNode({
    required this.widgetType,
    required this.astNode,
    required this.positionalArgs,
    required this.props,
    required this.slots,
    required this.children,
  });

  final String widgetType;
  final AstNode astNode;
  final List<Expression> positionalArgs;
  final Map<String, Expression> props;
  final Map<String, WidgetNode?> slots;
  final List<WidgetNode> children;
}
