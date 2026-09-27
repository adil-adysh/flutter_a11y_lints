class SourceSpan {
  const SourceSpan(this.start, this.end);
  final int start;
  final int end;
}

class Faql4ValidationError implements Exception {
  const Faql4ValidationError(this.message, {this.span, this.source});
  final String message;
  final SourceSpan? span;
  final String? source;

  int? get line => _location?.$1;
  int? get column => _location?.$2;

  (int, int)? get _location {
    if (source == null || span == null) return null;
    final before = source!.substring(0, span!.start);
    final line = '\n'.allMatches(before).length + 1;
    final lastNewline = before.lastIndexOf('\n');
    return (line, span!.start - lastNewline);
  }

  Faql4ValidationError withSource(String source) =>
      Faql4ValidationError(message, span: span, source: source);

  @override
  String toString() => line != null
      ? 'Faql4ValidationError at $line:$column: $message'
      : span == null
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
  const MemberCallAst(this.variable, this.member, this.arguments, super.span);
  final String variable;
  final String member;
  final List<LiteralAst> arguments;
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
