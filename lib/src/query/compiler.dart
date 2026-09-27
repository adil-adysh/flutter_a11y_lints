import '../facts/fact_store.dart';
import 'ast.dart';
import 'parser.dart';
import 'stdlib.dart';
import 'validator.dart';

class CompiledQuery {
  const CompiledQuery(
      {required this.queryId,
      required this.ruleId,
      required this.severity,
      required this.mode,
      required this.view,
      required this.variable,
      required this.where,
      required this.message});
  final String queryId, ruleId, severity, view, variable, message;
  final FactMode mode;
  final ExpressionAst? where;
}

class Faql4Compiler {
  CompiledQuery compile(String source) {
    try {
      final ast = parseFaql4(source);
      const required = ['id', 'rule-id', 'severity', 'mode'];
      for (final key in required) {
        if ((ast.metadata[key] ?? '').isEmpty) {
          throw Faql4ValidationError('Missing @$key metadata.',
              span: ast.from.span);
        }
      }
      final mode = switch (ast.metadata['mode']) {
        'conservative' => FactMode.conservative,
        'expanded' => FactMode.expanded,
        _ => throw Faql4ValidationError(
            'Mode must be conservative or expanded.',
            span: ast.from.span)
      };
      if (!Faql4StandardLibrary.views.contains(ast.from.view)) {
        throw Faql4ValidationError('Unknown view ${ast.from.view}.',
            span: ast.from.span);
      }
      if (ast.select.variable != ast.from.variable) {
        throw Faql4ValidationError('select must return the from variable.',
            span: ast.select.span);
      }
      Faql4Validator(mode, {ast.from.variable}).validate(ast.where);
      return CompiledQuery(
          queryId: ast.metadata['id']!,
          ruleId: ast.metadata['rule-id']!,
          severity: ast.metadata['severity']!,
          mode: mode,
          view: ast.from.view,
          variable: ast.from.variable,
          where: ast.where,
          message: ast.select.message);
    } on Faql4ValidationError catch (error) {
      throw error.withSource(source);
    }
  }
}
