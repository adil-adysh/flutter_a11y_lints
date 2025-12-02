import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

Expression? extractBuildBodyExpression(MethodDeclaration method) {
  final body = method.body;
  if (body is ExpressionFunctionBody) {
    return body.expression;
  }
  if (body is BlockFunctionBody) {
    for (final statement in body.block.statements) {
      if (statement is ReturnStatement) {
        return statement.expression;
      }
    }
  }
  return null;
}

/// Finds all build methods in a compilation unit.
List<MethodDeclaration> findBuildMethods(CompilationUnit unit) {
  final buildMethods = <MethodDeclaration>[];
  unit.visitChildren(_BuildMethodCollector(buildMethods));
  return buildMethods;
}

class _BuildMethodCollector extends RecursiveAstVisitor<void> {
  _BuildMethodCollector(this.methods);

  final List<MethodDeclaration> methods;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme == 'build') {
      methods.add(node);
    }
    super.visitMethodDeclaration(node);
  }
}
