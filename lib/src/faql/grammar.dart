import 'package:petitparser/petitparser.dart';
import 'ast.dart';

/// Grammar that also builds the AST nodes during parsing.
class FaqlGrammar extends GrammarDefinition {
  @override
  Parser start() => ref0(ruleDefinition).trim(ref0(hidden)).end();

  // Top-level rule -> produces a FaqlRule
  Parser<FaqlRule> ruleDefinition() => (token('rule') &
              token(ref0(stringLiteral)) &
              token('on') &
              ref0(selector) &
              token(char('{')) &
              ref0(metaSection).optional() &
              ref0(whenClause).optional() &
              ref0(ensureClause) &
              ref0(reportClause) &
              token(char('}')))
          .map((values) {
        // values: [ 'rule', name, 'on', selectors, '{', meta?, when?, ensure, report, '}' ]
        final name = values[1] as String;
        final selectors = (values[3] as List).cast<FaqlSelector>();
        final meta = (values[5] as Map<String, String>?) ?? <String, String>{};
        final whenExpr = values[6] as FaqlExpression?;
        final ensureExpr = values[7] as FaqlExpression;
        final report = values[8] as String;
        return FaqlRule(
            name: name,
            selectors: selectors,
            meta: meta,
            when: whenExpr,
            ensure: ensureExpr,
            report: report);
      });

  // Selectors
    Parser selector() =>
      (ref0(selectorTerm) & (token(string('||')) & ref0(selectorTerm)).star())
          .map((v) {
        final first = v[0] as FaqlSelector;
        final rest = v[1] as List;
        final items = <FaqlSelector>[first];
        for (final pair in rest) {
          // pair is ['||', selectorTerm]
          items.add(pair[1] as FaqlSelector);
        }
        return items;
      });

    Parser selectorTerm() => (token('any').map((_) => AnySelector()) |
        (token('role') & ref0(functionCallArgs))
          .map((v) => RoleSelector(v[1] as String)) |
        (token('type') & ref0(functionCallArgs))
          .map((v) => TypeSelector(v[1] as String)) |
        (token('kind') & ref0(functionCallArgs))
          .map((v) => KindSelector(v[1] as String)));

  // Body clauses
    Parser<Map<String, String>> metaSection() => (token('meta') &
      token(char('{')) &
      (ref0(identifier) & token(char(':')) & token(ref0(stringLiteral)))
        .star() &
          token(char('}')))
          .map((v) {
        final pairs = v[2] as List;
        final map = <String, String>{};
        for (final p in pairs) {
          // p: [key, ':', value]
          final key = p[0] as String;
          final val = p[2] as String;
          map[key] = val;
        }
        return map;
      });

    Parser<FaqlExpression> whenClause() =>
      (token('when:') & ref0(expression))
          .map((v) => v[1] as FaqlExpression);

    Parser<FaqlExpression> ensureClause() =>
      (token('ensure:') & ref0(expression))
          .map((v) => v[1] as FaqlExpression);

    Parser<String> reportClause() =>
      (token('report:') & token(ref0(stringLiteral)))
          .map((v) => v[1] as String);

  // Expression builder producing FaqlExpression nodes
  late final Parser<FaqlExpression> _expressionParser = _buildExpression();

  Parser<FaqlExpression> expression() => _expressionParser;

  Parser<FaqlExpression> _buildExpression() {
    final builder = ExpressionBuilder<FaqlExpression>();

    // primitives - register each separately to satisfy types
    builder.primitive(ref0(parentheses));
    builder.primitive(ref0(traversal));
    builder.primitive(ref0(propAccess));
    builder.primitive(ref0(booleanState));
    builder.primitive(ref0(literal));
    // allow bare identifiers in expressions (e.g., `role == "button")`
    builder.primitive(ref0(identifierExpr));

    // prefix
    builder.group()
      ..prefix(token(char('!')),
        (op, value) => UnaryExpression(op.toString(), value))
      ..prefix(token(char('-')),
        (op, value) => UnaryExpression(op.toString(), value));

    // multiplicative
    builder.group()
      ..left(token(char('*')), (l, op, r) =>
        BinaryExpression(l, _mapOp(op.toString()), r))
      ..left(token(char('/')),
        (l, op, r) => BinaryExpression(l, _mapOp(op.toString()), r));

    // additive
    builder.group()
      ..left(token(char('+')),
        (l, op, r) => BinaryExpression(l, _mapOp(op.toString()), r))
      ..left(token(char('-')),
        (l, op, r) => BinaryExpression(l, _mapOp(op.toString()), r));

    // relational
    builder.group()
      ..left(token(string('<=')),
        (l, op, r) => BinaryExpression(l, _mapOp(op.toString()), r))
      ..left(token(string('>=')),
        (l, op, r) => BinaryExpression(l, _mapOp(op.toString()), r))
      ..left(token(char('<')),
        (l, op, r) => BinaryExpression(l, _mapOp(op.toString()), r))
      ..left(token(char('>')),
        (l, op, r) => BinaryExpression(l, _mapOp(op.toString()), r));

    // equality & contains/matches
    builder.group()
      ..left(token(string('==')),
        (l, op, r) => BinaryExpression(l, _mapOp(op.toString()), r))
      ..left(token(string('!=')),
        (l, op, r) => BinaryExpression(l, _mapOp(op.toString()), r))
      ..left(token(string('~=')),
        (l, op, r) => BinaryExpression(l, _mapOp(op.toString()), r))
      ..left(token(string('contains')),
        (l, op, r) => BinaryExpression(l, _mapOp(op.toString()), r))
      ..left(token(string('matches')), (l, op, r) {
        // If the right-hand-side is a string literal, pre-compile the RegExp.
        if (r is LiteralExpression && r.value is String) {
          var pattern = (r.value as String);
          var caseSensitive = true;
          if (pattern.startsWith('(?i)')) {
            caseSensitive = false;
            pattern = pattern.substring(4);
          }
          return RegexMatchExpression(l, RegExp(pattern, caseSensitive: caseSensitive));
        }
        return BinaryExpression(l, _mapOp(op.toString()), r);
      });

    // logical
    builder.group()
      ..left(token(string('&&')),
          (l, op, r) => BinaryExpression(l, _mapOp(op.toString()), r));
    builder.group()
      ..left(token(string('||')),
          (l, op, r) => BinaryExpression(l, _mapOp(op.toString()), r));

    return builder.build();
  }

  FaqlBinaryOp _mapOp(String opToken) {
    final t = opToken.trim();
    switch (t) {
      case '&&':
        return FaqlBinaryOp.and;
      case '||':
        return FaqlBinaryOp.or;
      case '+':
        return FaqlBinaryOp.add;
      case '-':
        return FaqlBinaryOp.subtract;
      case '*':
        return FaqlBinaryOp.multiply;
      case '/':
        return FaqlBinaryOp.divide;
      case '<':
        return FaqlBinaryOp.less;
      case '>':
        return FaqlBinaryOp.greater;
      case '<=':
        return FaqlBinaryOp.lessEqual;
      case '>=':
        return FaqlBinaryOp.greaterEqual;
      case '==':
        return FaqlBinaryOp.equals;
      case '!=':
        return FaqlBinaryOp.notEquals;
      case '~=':
        return FaqlBinaryOp.tildeEquals;
      case 'contains':
        return FaqlBinaryOp.contains;
      case 'matches':
        return FaqlBinaryOp.matches;
      default:
        return FaqlBinaryOp.equals;
    }
  }

    Parser<FaqlExpression> parentheses() =>
      (token(char('(')) & ref0(expression) & token(char(')')))
        .map((v) => v[1] as FaqlExpression);

  // traversal -> RelationLengthExpression or AggregatorExpression
  Parser<FaqlExpression> traversal() => (ref0(relationName) &
          token(char('.')) &
          (string('length').trim() |
            (ref0(aggregatorName) &
              token(char('(')) &
              ref0(expression) &
              token(char(')')))))
          .map((v) {
        final relationStr = v[0] as String;
        final relation = _mapRelation(relationStr);
        final tail = v[2];
        if (tail is String && tail == 'length')
          return RelationLengthExpression(relation);
        // tail is a List: [aggregator, '(', expr, ')']
        final agg = (tail as List)[0] as String;
        final aggEnum = _mapAggregator(agg);
        final expr = (tail[2]) as FaqlExpression;
        return AggregatorExpression(relation, aggEnum, expr);
      });

  FaqlRelation _mapRelation(String s) {
    switch (s) {
      case 'children':
        return FaqlRelation.children;
      case 'ancestors':
        return FaqlRelation.ancestors;
      case 'siblings':
        return FaqlRelation.siblings;
      case 'next_focus':
        return FaqlRelation.nextFocus;
      case 'prev_focus':
        return FaqlRelation.prevFocus;
      default:
        return FaqlRelation.children;
    }
  }

  FaqlAggregator _mapAggregator(String s) {
    switch (s) {
      case 'any':
        return FaqlAggregator.any;
      case 'all':
        return FaqlAggregator.all;
      case 'none':
        return FaqlAggregator.none;
      default:
        return FaqlAggregator.any;
    }
  }

  // prop("name") [.is_resolved] | as type
  Parser<FaqlExpression> propAccess() => (string('prop').trim() &
              token(char('(')) &
              ref0(stringLiteral) &
              token(char(')')) &
              ref0(castOperation).optional())
          .map((v) {
        final name = v[2] as String;
        String? asType;
        bool? isResolved;
        final cast = v[4];
        if (cast != null) {
          if (cast is String && cast == '.is_resolved')
            isResolved = true;
          else if (cast is List && cast.length >= 2) asType = cast[1] as String;
        }
        return PropExpression(name, asType: asType, isResolved: isResolved);
      });

    Parser<dynamic> castOperation() => (string('.is_resolved').trim() |
      (string('as').trim() &
        (string('string') | string('int') | string('bool'))));

  // Tokens and helpers
  Parser<String> relationName() => (string('children') |
          string('siblings') |
          string('ancestors') |
          string('next_focus') |
          string('prev_focus'))
      .trim(ref0(hidden))
      .flatten();

    Parser<String> aggregatorName() =>
      (string('any') | string('all') | string('none')).trim(ref0(hidden)).flatten();

  Parser<FaqlExpression> booleanState() => (string('focusable') |
          string('enabled') |
          string('hidden') |
          string('checked') |
          string('toggled') |
          string('merges_descendants') |
          string('has_tap') |
          string('has_long_press') |
          string('is_empty') |
          string('is_not_empty'))
      .trim(ref0(hidden))
      .flatten()
      .map((s) => BooleanStateExpression(s.toString().trim()));

    Parser<String> functionCallArgs() =>
      (token(char('(')) & ref0(identifier) & token(char(')')))
        .map((v) => v[1] as String);

  Parser<FaqlExpression> literal() {
    final p1 = ref0(stringLiteral).map((s) => LiteralExpression(s.toString()));
    final p2 = ref0(numberLiteral)
        .map((s) => LiteralExpression(num.parse(s.toString())));
    final p3 = ref0(booleanLiteral)
        .map((s) => LiteralExpression(s.toString().trim() == 'true'));
    return (p1 | p2 | p3).map((v) => v as FaqlExpression);
  }

  // Bare identifiers produce an Identifier AST node.
  Parser<FaqlExpression> identifierExpr() =>
      ref0(identifier).map((s) => Identifier(s.toString()));

    Parser<String> identifier() =>
      ((letter() | char('_')) & (word()).star()).flatten().trim(ref0(hidden));

  Parser<String> stringLiteral() =>
      (char('"') & (char('\\') & any() | pattern('^"')).star() & char('"'))
          .flatten()
          .map((s) {
        // Strip surrounding quotes and unescape common escape sequences.
        final inner = s.substring(1, s.length - 1);
        return inner.replaceAllMapped(RegExp(r'\\(.)'), (m) {
          final ch = m[1];
          switch (ch) {
            case 'n':
              return '\n';
            case 't':
              return '\t';
            case 'r':
              return '\r';
            case '\\':
              return '\\';
            case '"':
              return '"';
            default:
              // Preserve unknown escapes (e.g. '\\d') as-is so regex
              // escape sequences like '\\d' are not stripped to 'd'.
              return '\\${ch ?? ''}';
          }
        });
      });

    Parser<String> numberLiteral() =>
      ((digit().plus() & (char('.') & digit().plus()).optional()))
        .flatten()
        .trim(ref0(hidden));

  Parser<String> booleanLiteral() =>
      (string('true') | string('false')).trim(ref0(hidden)).flatten();

  // Comments and whitespace handling
    Parser singleLineComment() =>
      string('//') & any().starLazy(char('\n')) & (char('\n') | endOfInput());

  Parser hidden() => (whitespace() | ref0(singleLineComment)).plus();

  // Token helper: trims the given string or parser using `hidden` which
  // consumes whitespace and single-line comments. If `input` is a String,
  // create a string parser, otherwise assume it's already a Parser.
  Parser token(Object input) {
    if (input is String) return string(input).trim(ref0(hidden));
    if (input is Parser) return input.trim(ref0(hidden));
    throw ArgumentError('token() expects a String or Parser');
  }
}
