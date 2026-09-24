import 'ast.dart';
import 'lexer.dart';

Faql4QueryAst parseFaql4(String source) => _Parser(lexFaql4(source)).parse();

class _Parser {
  _Parser(this.tokens);
  final List<Token> tokens;
  var index = 0;
  Token get current => tokens[index];
  Token take(TokenKind kind, [String? text]) {
    if (current.kind != kind || (text != null && current.lexeme != text)) {
      throw Faql4ValidationError('Expected ${text ?? kind.name}.',
          span: current.span);
    }
    return tokens[index++];
  }

  bool accept(TokenKind kind, [String? text]) {
    if (current.kind == kind && (text == null || current.lexeme == text)) {
      index++;
      return true;
    }
    return false;
  }

  Faql4QueryAst parse() {
    final metadata = <String, String>{};
    while (accept(TokenKind.at)) {
      final key = take(TokenKind.identifier);
      final value = current.kind == TokenKind.string
          ? take(TokenKind.string)
          : take(TokenKind.identifier);
      metadata[key.lexeme] = value.lexeme;
    }
    final fromStart = take(TokenKind.identifier, 'from').span.start;
    final view = take(TokenKind.identifier);
    final variable = take(TokenKind.identifier);
    ExpressionAst? where;
    if (accept(TokenKind.identifier, 'where')) where = expression();
    final selectStart = take(TokenKind.identifier, 'select').span.start;
    final selectVariable = take(TokenKind.identifier);
    take(TokenKind.comma);
    final message = take(TokenKind.string);
    take(TokenKind.eof);
    return Faql4QueryAst(
        metadata,
        FromClauseAst(view.lexeme, variable.lexeme,
            SourceSpan(fromStart, variable.span.end)),
        where,
        SelectClauseAst(selectVariable.lexeme, message.lexeme,
            SourceSpan(selectStart, message.span.end)));
  }

  ExpressionAst expression() {
    var result = and();
    while (accept(TokenKind.identifier, 'or')) {
      final right = and();
      result =
          OrAst(result, right, SourceSpan(result.span.start, right.span.end));
    }
    return result;
  }

  ExpressionAst and() {
    var result = unary();
    while (accept(TokenKind.identifier, 'and')) {
      final right = unary();
      result =
          AndAst(result, right, SourceSpan(result.span.start, right.span.end));
    }
    return result;
  }

  ExpressionAst unary() {
    if (accept(TokenKind.identifier, 'not')) {
      final start = tokens[index - 1].span.start;
      final inner = unary();
      return NotAst(inner, SourceSpan(start, inner.span.end));
    }
    return primary();
  }

  ExpressionAst primary() {
    if (accept(TokenKind.lParen)) {
      final inner = expression();
      take(TokenKind.rParen);
      return inner;
    }
    if (accept(TokenKind.identifier, 'exists')) return quantify(false);
    if (accept(TokenKind.identifier, 'count')) {
      final count = quantify(true);
      final operator = takeComparison();
      final right = literal();
      return ComparisonAst(count, operator.lexeme, right,
          SourceSpan(count.span.start, right.span.end));
    }
    final left = value();
    if (isComparison(current.kind)) {
      final operator = tokens[index++];
      final right = value();
      return ComparisonAst(left, operator.lexeme, right,
          SourceSpan(left.span.start, right.span.end));
    }
    return left;
  }

  ExpressionAst quantify(bool count) {
    final start = tokens[index - 1].span.start;
    take(TokenKind.lParen);
    final view = take(TokenKind.identifier);
    final variable = take(TokenKind.identifier);
    take(TokenKind.pipe);
    final body = expression();
    final end = take(TokenKind.rParen).span.end;
    return count
        ? CountAst(view.lexeme, variable.lexeme, body, SourceSpan(start, end))
        : ExistsAst(view.lexeme, variable.lexeme, body, SourceSpan(start, end));
  }

  ExpressionAst value() {
    if (current.kind == TokenKind.string ||
        current.kind == TokenKind.integer ||
        (current.kind == TokenKind.identifier &&
            (current.lexeme == 'true' || current.lexeme == 'false')))
      return literal();
    final name = take(TokenKind.identifier);
    if (!accept(TokenKind.dot)) return VariableAst(name.lexeme, name.span);
    final member = take(TokenKind.identifier);
    take(TokenKind.lParen);
    take(TokenKind.rParen);
    return MemberCallAst(name.lexeme, member.lexeme,
        SourceSpan(name.span.start, tokens[index - 1].span.end));
  }

  LiteralAst literal() {
    final token = current;
    if (accept(TokenKind.string)) return LiteralAst(token.lexeme, token.span);
    if (accept(TokenKind.integer))
      return LiteralAst(int.parse(token.lexeme), token.span);
    if (accept(TokenKind.identifier, 'true'))
      return LiteralAst(true, token.span);
    if (accept(TokenKind.identifier, 'false'))
      return LiteralAst(false, token.span);
    throw Faql4ValidationError('Expected literal.', span: token.span);
  }

  bool isComparison(TokenKind kind) => const {
        TokenKind.equal,
        TokenKind.notEqual,
        TokenKind.less,
        TokenKind.lessEqual,
        TokenKind.greater,
        TokenKind.greaterEqual
      }.contains(kind);
  Token takeComparison() {
    if (!isComparison(current.kind))
      throw Faql4ValidationError('Expected comparison.', span: current.span);
    return tokens[index++];
  }
}
