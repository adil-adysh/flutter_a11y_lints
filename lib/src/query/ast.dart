class SourceSpan {
  const SourceSpan(this.start, this.end);
  final int start;
  final int end;
}

class Faql4ValidationError implements Exception {
  const Faql4ValidationError(this.message, {this.span});
  final String message;
  final SourceSpan? span;
  @override
  String toString() => span == null
      ? 'Faql4ValidationError: $message'
      : 'Faql4ValidationError at ${span!.start}: $message';
}

class Faql4QueryAst {
  const Faql4QueryAst(this.metadata, this.from, this.where, this.select);
  final Map<String, String> metadata;
  final FromClauseAst from;
  final ExpressionAst? where;
  final SelectClauseAst select;
}

class FromClauseAst {
  const FromClauseAst(this.view, this.variable, this.span);
  final String view;
  final String variable;
  final SourceSpan span;
}

class SelectClauseAst {
  const SelectClauseAst(this.variable, this.message, this.span);
  final String variable;
  final String message;
  final SourceSpan span;
}

sealed class ExpressionAst {
  const ExpressionAst(this.span);
  final SourceSpan span;
}

class VariableAst extends ExpressionAst {
  const VariableAst(this.name, super.span);
  final String name;
}

class MemberCallAst extends ExpressionAst {
  const MemberCallAst(this.variable, this.member, super.span);
  final String variable;
  final String member;
}

class LiteralAst extends ExpressionAst {
  const LiteralAst(this.value, super.span);
  final Object value;
}

class ComparisonAst extends ExpressionAst {
  const ComparisonAst(this.left, this.operator, this.right, super.span);
  final ExpressionAst left;
  final String operator;
  final ExpressionAst right;
}

class NotAst extends ExpressionAst {
  const NotAst(this.inner, super.span);
  final ExpressionAst inner;
}

class AndAst extends ExpressionAst {
  const AndAst(this.left, this.right, super.span);
  final ExpressionAst left;
  final ExpressionAst right;
}

class OrAst extends ExpressionAst {
  const OrAst(this.left, this.right, super.span);
  final ExpressionAst left;
  final ExpressionAst right;
}

class ExistsAst extends ExpressionAst {
  const ExistsAst(this.view, this.variable, this.body, super.span);
  final String view;
  final String variable;
  final ExpressionAst body;
}

class CountAst extends ExpressionAst {
  const CountAst(this.view, this.variable, this.body, super.span);
  final String view;
  final String variable;
  final ExpressionAst body;
}
