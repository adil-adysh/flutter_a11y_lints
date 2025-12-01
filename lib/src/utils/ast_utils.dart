import 'package:analyzer/dart/ast/ast.dart';

Expression? getNamedArg(InstanceCreationExpression node, String name) {
  try {
    return node.argumentList.arguments
        .whereType<NamedExpression>()
        .firstWhere((arg) => arg.name.label.name == name)
        .expression;
  } catch (e) {
    return null;
  }
}

String? getStringLiteralArg(InstanceCreationExpression node, String name) {
  final arg = getNamedArg(node, name);
  if (arg is StringLiteral) {
    return arg.stringValue;
  }
  return null;
}

bool hasCallbackArg(InstanceCreationExpression node, String name) {
  final arg = getNamedArg(node, name);
  return arg != null && arg is! NullLiteral;
}

bool hasTextChild(InstanceCreationExpression node) {
  // This is a simplistic check. A more robust implementation would traverse the
  // widget tree.
  final childArg = getNamedArg(node, 'child');
  if (childArg is InstanceCreationExpression) {
    final type = childArg.staticType;
    if (type != null &&
        type.getDisplayString(withNullability: false) == 'Text') {
      return true;
    }
  }
  return false;
}
