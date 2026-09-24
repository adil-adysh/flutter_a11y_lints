import '../facts/fact_store.dart';
import 'ast.dart';
import 'parser.dart';
import 'stdlib.dart';

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
    final ast = parseFaql4(source);
    const required = ['id', 'rule-id', 'severity', 'mode'];
    for (final key in required) {
      if ((ast.metadata[key] ?? '').isEmpty)
        throw Faql4ValidationError('Missing @$key metadata.',
            span: ast.from.span);
    }
    final mode = switch (ast.metadata['mode']) {
      'conservative' => FactMode.conservative,
      'expanded' => FactMode.expanded,
      _ => throw Faql4ValidationError('Mode must be conservative or expanded.',
          span: ast.from.span)
    };
    if (!Faql4StandardLibrary.views.contains(ast.from.view))
      throw Faql4ValidationError('Unknown view ${ast.from.view}.',
          span: ast.from.span);
    if (ast.select.variable != ast.from.variable)
      throw Faql4ValidationError('select must return the from variable.',
          span: ast.select.span);
    _Validator(mode, {ast.from.variable}).validate(ast.where);
    return CompiledQuery(
        queryId: ast.metadata['id']!,
        ruleId: ast.metadata['rule-id']!,
        severity: ast.metadata['severity']!,
        mode: mode,
        view: ast.from.view,
        variable: ast.from.variable,
        where: ast.where,
        message: ast.select.message);
  }
}

class _Validator {
  _Validator(this.mode, this.scope);
  final FactMode mode;
  final Set<String> scope;
  FaqlType validate(ExpressionAst? e) {
    if (e == null) return FaqlType.boolean;
    return switch (e) {
      LiteralAst v => v.value is bool
          ? FaqlType.boolean
          : v.value is int
              ? FaqlType.integer
              : FaqlType.string,
      VariableAst v => scope.contains(v.name)
          ? FaqlType.node
          : _bad('Unknown variable.', v.span),
      MemberCallAst v => _member(v),
      NotAst v => _not(v),
      AndAst v => _both(v.left, v.right),
      OrAst v => _both(v.left, v.right),
      ComparisonAst v => _comparison(v),
      ExistsAst v =>
        _quantify(v.view, v.variable, v.body, v.span, FaqlType.boolean),
      CountAst v =>
        _quantify(v.view, v.variable, v.body, v.span, FaqlType.integer),
    };
  }

  FaqlType _member(MemberCallAst v) {
    if (!scope.contains(v.variable)) return _bad('Unknown variable.', v.span);
    final type = Faql4StandardLibrary.memberType(v.member);
    return type ?? _bad('Unknown member ${v.member}.', v.span);
  }

  FaqlType _not(NotAst v) {
    if (mode == FactMode.conservative && _partial(v.inner))
      return _bad(
          'Conservative queries cannot negate a partial predicate.', v.span);
    return _require(v.inner, FaqlType.boolean);
  }

  FaqlType _both(ExpressionAst a, ExpressionAst b) {
    _require(a, FaqlType.boolean);
    _require(b, FaqlType.boolean);
    return FaqlType.boolean;
  }

  FaqlType _comparison(ComparisonAst v) {
    final a = validate(v.left), b = validate(v.right);
    if (a != b ||
        (v.operator != '=' && v.operator != '!=' && a != FaqlType.integer))
      return _bad('Incompatible comparison operands.', v.span);
    return FaqlType.boolean;
  }

  FaqlType _quantify(String view, String variable, ExpressionAst body,
      SourceSpan span, FaqlType result) {
    if (!Faql4StandardLibrary.views.contains(view))
      return _bad('Unknown view $view.', span);
    final nested = _Validator(mode, {...scope, variable});
    nested._require(body, FaqlType.boolean);
    return result;
  }

  FaqlType _require(ExpressionAst e, FaqlType type) {
    if (validate(e) != type)
      return _bad('Expected ${type.name} expression.', e.span);
    return type;
  }

  bool _partial(ExpressionAst e) => switch (e) {
        MemberCallAst v => Faql4StandardLibrary.isPartial(v.member),
        NotAst v => _partial(v.inner),
        AndAst v => _partial(v.left) || _partial(v.right),
        OrAst v => _partial(v.left) || _partial(v.right),
        ComparisonAst v => _partial(v.left) || _partial(v.right),
        ExistsAst v => _partial(v.body),
        CountAst v => _partial(v.body),
        _ => false
      };
  Never _bad(String message, SourceSpan span) =>
      throw Faql4ValidationError(message, span: span);
}
