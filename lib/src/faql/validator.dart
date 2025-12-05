import 'ast.dart';
import 'interpreter.dart' show FaqlCompilationError;

/// Semantic validator for FAQL ASTs.
/// Ensures that identifier property names exist in the provided schema.
class FaqlSemanticValidator {
  final Set<String> schemaProps;

  FaqlSemanticValidator(Iterable<String> schema)
      : schemaProps = Set<String>.from(schema.map((s) => s.toString()));

  void validate(FaqlRule rule) {
    void visitExpr(FaqlExpression? e) {
      if (e == null) return;
      if (e is Identifier) {
        if (!_isKnown(e.name)) {
          throw FaqlCompilationError('Unknown identifier "${e.name}" in rule ${rule.name}');
        }
      } else if (e is PropExpression) {
        if (!_isKnown(e.name)) {
          throw FaqlCompilationError('Unknown property "${e.name}" in rule ${rule.name}');
        }
      } else if (e is UnaryExpression) {
        visitExpr(e.expr);
      } else if (e is BinaryExpression) {
        visitExpr(e.left);
        visitExpr(e.right);
      } else if (e is RegexMatchExpression) {
        visitExpr(e.left);
      } else if (e is AggregatorExpression) {
        visitExpr(e.expr);
      } else if (e is RelationLengthExpression) {
        // relation names in AST are enums so nothing to validate here
      } else if (e is LiteralExpression) {
        // ok
      } else if (e is BooleanStateExpression) {
        // boolean states are fixed; optionally validate if desired
      }
    }

    if (rule.when != null) visitExpr(rule.when);
    visitExpr(rule.ensure);
  }

  bool _isKnown(String name) {
    // allow builtins
    const builtins = {'role', 'widgetType', 'type'};
    if (builtins.contains(name)) return true;
    return schemaProps.contains(name);
  }
}
