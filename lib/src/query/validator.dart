import '../facts/fact_store.dart';
import 'ast.dart';
import 'stdlib.dart';

/// Type-checks a parsed FAQL 4 Core query before it becomes an executable plan.
class Faql4Validator {
  Faql4Validator(this.mode, this.scope);

  final FactMode mode;
  final Set<String> scope;

  FaqlType validate(ExpressionAst? expression) {
    if (expression == null) return FaqlType.boolean;
    return switch (expression) {
      LiteralAst value => value.value is bool
          ? FaqlType.boolean
          : value.value is int
              ? FaqlType.integer
              : FaqlType.string,
      VariableAst value => scope.contains(value.name)
          ? FaqlType.node
          : _bad('Unknown variable.', value.span),
      MemberCallAst value => _member(value),
      NotAst value => _not(value),
      AndAst value => _both(value.left, value.right),
      OrAst value => _both(value.left, value.right),
      ComparisonAst value => _comparison(value),
      ExistsAst value => _quantify(
          value.view, value.variable, value.body, value.span, FaqlType.boolean),
      CountAst value => _quantify(
          value.view, value.variable, value.body, value.span, FaqlType.integer),
    };
  }

  FaqlType _member(MemberCallAst value) {
    if (!scope.contains(value.variable)) {
      return _bad('Unknown variable.', value.span);
    }
    final type = Faql4StandardLibrary.memberType(value.member);
    return type ?? _bad('Unknown member ${value.member}.', value.span);
  }

  FaqlType _not(NotAst value) {
    if (mode == FactMode.conservative && _partial(value.inner)) {
      return _bad('Conservative queries cannot negate a partial predicate.',
          value.span);
    }
    return _require(value.inner, FaqlType.boolean);
  }

  FaqlType _both(ExpressionAst left, ExpressionAst right) {
    _require(left, FaqlType.boolean);
    _require(right, FaqlType.boolean);
    return FaqlType.boolean;
  }

  FaqlType _comparison(ComparisonAst value) {
    final left = validate(value.left);
    final right = validate(value.right);
    if (left != right ||
        (value.operator != '=' &&
            value.operator != '!=' &&
            left != FaqlType.integer)) {
      return _bad('Incompatible comparison operands.', value.span);
    }
    return FaqlType.boolean;
  }

  FaqlType _quantify(String view, String variable, ExpressionAst body,
      SourceSpan span, FaqlType result) {
    if (!Faql4StandardLibrary.views.contains(view)) {
      return _bad('Unknown view $view.', span);
    }
    final nested = Faql4Validator(mode, {...scope, variable});
    nested._require(body, FaqlType.boolean);
    return result;
  }

  FaqlType _require(ExpressionAst expression, FaqlType type) {
    if (validate(expression) != type) {
      return _bad('Expected ${type.name} expression.', expression.span);
    }
    return type;
  }

  bool _partial(ExpressionAst expression) => switch (expression) {
        MemberCallAst value => Faql4StandardLibrary.isPartial(value.member),
        NotAst value => _partial(value.inner),
        AndAst value => _partial(value.left) || _partial(value.right),
        OrAst value => _partial(value.left) || _partial(value.right),
        ComparisonAst value => _partial(value.left) || _partial(value.right),
        ExistsAst value => _partial(value.body),
        CountAst value => _partial(value.body),
        _ => false,
      };

  Never _bad(String message, SourceSpan span) =>
      throw Faql4ValidationError(message, span: span);
}
