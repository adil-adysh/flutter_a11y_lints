import 'ast.dart';

enum TokenKind {
  identifier,
  string,
  integer,
  at,
  dot,
  lParen,
  rParen,
  comma,
  pipe,
  equal,
  notEqual,
  less,
  lessEqual,
  greater,
  greaterEqual,
  eof
}

class Token {
  const Token(this.kind, this.lexeme, this.span);
  final TokenKind kind;
  final String lexeme;
  final SourceSpan span;
}

List<Token> lexFaql4(String source) {
  final tokens = <Token>[];
  var i = 0;
  bool isId(String c) => RegExp(r'[A-Za-z0-9_/-]').hasMatch(c);
  void add(TokenKind kind, int start, [String? value]) => tokens.add(
      Token(kind, value ?? source.substring(start, i), SourceSpan(start, i)));
  while (i < source.length) {
    final start = i;
    final c = source[i++];
    if (RegExp(r'\s').hasMatch(c)) continue;
    if (c == '/' && i < source.length && source[i] == '/') {
      while (i < source.length && source[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && i < source.length && source[i] == '*') {
      i++;
      final end = source.indexOf('*/', i);
      if (end < 0)
        throw Faql4ValidationError('Unterminated comment.',
            span: SourceSpan(start, source.length));
      i = end + 2;
      continue;
    }
    const single = {
      '@': TokenKind.at,
      '.': TokenKind.dot,
      '(': TokenKind.lParen,
      ')': TokenKind.rParen,
      ',': TokenKind.comma,
      '|': TokenKind.pipe,
      '=': TokenKind.equal,
      '<': TokenKind.less,
      '>': TokenKind.greater
    };
    if (single.containsKey(c)) {
      if ((c == '!' || c == '<' || c == '>') &&
          i < source.length &&
          source[i] == '=') {
        i++;
        add(
            c == '!'
                ? TokenKind.notEqual
                : c == '<'
                    ? TokenKind.lessEqual
                    : TokenKind.greaterEqual,
            start);
      } else {
        add(single[c]!, start);
      }
      continue;
    }
    if (c == '!') {
      if (i < source.length && source[i] == '=') {
        i++;
        add(TokenKind.notEqual, start);
        continue;
      }
      throw Faql4ValidationError('Unexpected !.', span: SourceSpan(start, i));
    }
    if (c == '"') {
      final out = StringBuffer();
      var closed = false;
      while (i < source.length) {
        final next = source[i++];
        if (next == '"') {
          closed = true;
          break;
        }
        if (next == '\\' && i < source.length) {
          out.write(source[i++]);
        } else {
          out.write(next);
        }
      }
      if (!closed)
        throw Faql4ValidationError('Unterminated string.',
            span: SourceSpan(start, i));
      add(TokenKind.string, start, out.toString());
      continue;
    }
    if (RegExp(r'\d').hasMatch(c)) {
      while (i < source.length && RegExp(r'\d').hasMatch(source[i])) {
        i++;
      }
      add(TokenKind.integer, start);
      continue;
    }
    if (RegExp(r'[A-Za-z_]').hasMatch(c)) {
      while (i < source.length && isId(source[i])) {
        i++;
      }
      add(TokenKind.identifier, start);
      continue;
    }
    throw Faql4ValidationError('Unexpected token $c.',
        span: SourceSpan(start, i));
  }
  tokens
      .add(Token(TokenKind.eof, '', SourceSpan(source.length, source.length)));
  return tokens;
}
