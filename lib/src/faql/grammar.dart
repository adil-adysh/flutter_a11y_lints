import 'package:petitparser/petitparser.dart';
import 'ast.dart';

/// Grammar that also builds the AST nodes during parsing.
class FaqlGrammar extends GrammarDefinition {
  @override
  Parser start() => ref0(ruleDefinition).end();

  // Top-level rule -> produces a FaqlRule
  Parser<FaqlRule> ruleDefinition() => (string('rule').trim() &
              ref0(stringLiteral) &
              string('on').trim() &
              ref0(selector) &
              char('{').trim() &
              ref0(metaSection).optional() &
              ref0(whenClause).optional() &
              ref0(ensureClause) &
              ref0(reportClause) &
              char('}').trim())
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
      (ref0(selectorTerm) & (string('||').trim() & ref0(selectorTerm)).star())
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

  Parser selectorTerm() => (string('any').trim().map((_) => AnySelector()) |
          (string('role').trim() & ref0(functionCallArgs))
              .map((v) => RoleSelector(v[1] as String)) |
          (string('type').trim() & ref0(functionCallArgs))
              .map((v) => TypeSelector(v[1] as String)) |
          (string('kind').trim() & ref0(functionCallArgs))
              .map((v) => KindSelector(v[1] as String)))
      .trim();

  // Body clauses
  Parser<Map<String, String>> metaSection() => (string('meta').trim() &
              char('{').trim() &
              (ref0(identifier) & char(':').trim() & ref0(stringLiteral))
                  .star() &
              char('}').trim())
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
      (string('when:').trim() & ref0(expression))
          .map((v) => v[1] as FaqlExpression);

  Parser<FaqlExpression> ensureClause() =>
      (string('ensure:').trim() & ref0(expression))
          .map((v) => v[1] as FaqlExpression);

  Parser<String> reportClause() =>
      (string('report:').trim() & ref0(stringLiteral))
          .map((v) => v[1] as String);

  // Expression builder producing FaqlExpression nodes
  Parser<FaqlExpression> expression() {
    final builder = ExpressionBuilder<FaqlExpression>();

    // primitives - register each separately to satisfy types
    builder.primitive(ref0(parentheses));
    builder.primitive(ref0(traversal));
    builder.primitive(ref0(propAccess));
    builder.primitive(ref0(booleanState));
    builder.primitive(ref0(literal));
    // allow bare identifiers in expressions (e.g., `role == "button"`)
    builder.primitive(ref0(identifierExpr));

    // prefix
    builder.group()
      ..prefix(char('!').trim(),
          (op, value) => UnaryExpression(op.toString(), value))
      ..prefix(char('-').trim(),
          (op, value) => UnaryExpression(op.toString(), value));

    // multiplicative
    builder.group()
      ..left(
          char('*').trim(), (l, op, r) => BinaryExpression(l, op.toString(), r))
      ..left(char('/').trim(),
          (l, op, r) => BinaryExpression(l, op.toString(), r));

    // additive
    builder.group()
      ..left(
          char('+').trim(), (l, op, r) => BinaryExpression(l, op.toString(), r))
      ..left(char('-').trim(),
          (l, op, r) => BinaryExpression(l, op.toString(), r));

    // relational
    builder.group()
      ..left(string('<=').trim(),
          (l, op, r) => BinaryExpression(l, op.toString(), r))
      ..left(string('>=').trim(),
          (l, op, r) => BinaryExpression(l, op.toString(), r))
      ..left(
          char('<').trim(), (l, op, r) => BinaryExpression(l, op.toString(), r))
      ..left(char('>').trim(),
          (l, op, r) => BinaryExpression(l, op.toString(), r));

    // equality & contains/matches
    builder.group()
      ..left(string('==').trim(),
          (l, op, r) => BinaryExpression(l, op.toString(), r))
      ..left(string('!=').trim(),
          (l, op, r) => BinaryExpression(l, op.toString(), r))
      ..left(string('~=').trim(),
          (l, op, r) => BinaryExpression(l, op.toString(), r))
      ..left(string('contains').trim(),
          (l, op, r) => BinaryExpression(l, op.toString(), r))
      ..left(string('matches').trim(),
          (l, op, r) => BinaryExpression(l, op.toString(), r));

    // logical
    builder.group()
      ..left(string('&&').trim(),
          (l, op, r) => BinaryExpression(l, op.toString(), r));
    builder.group()
      ..left(string('||').trim(),
          (l, op, r) => BinaryExpression(l, op.toString(), r));

    return builder.build();
  }

  Parser<FaqlExpression> parentheses() =>
      (char('(').trim() & ref0(expression) & char(')').trim())
          .map((v) => v[1] as FaqlExpression);

  // traversal -> RelationLengthExpression or AggregatorExpression
  Parser<FaqlExpression> traversal() => (ref0(relationName) &
              char('.').trim() &
              (string('length').trim() |
                  (ref0(aggregatorName) &
                      char('(').trim() &
                      ref0(expression) &
                      char(')').trim())))
          .map((v) {
        final relation = v[0] as String;
        final tail = v[2];
        if (tail is String && tail == 'length')
          return RelationLengthExpression(relation);
        // tail is a List: [aggregator, '(', expr, ')']
        final agg = (tail as List)[0] as String;
        final expr = (tail[2]) as FaqlExpression;
        return AggregatorExpression(relation, agg, expr);
      });

  // prop("name") [.is_resolved] | as type
  Parser<FaqlExpression> propAccess() => (string('prop').trim() &
              char('(').trim() &
              ref0(stringLiteral) &
              char(')').trim() &
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
      .trim()
      .flatten();

  Parser<String> aggregatorName() =>
      (string('any') | string('all') | string('none')).trim().flatten();

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
      .trim()
      .flatten()
      .map((s) => BooleanStateExpression(s.toString().trim()));

  Parser<String> functionCallArgs() =>
      (char('(').trim() & ref0(identifier) & char(')').trim())
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
      ((letter() | char('_')) & (word()).star()).flatten().trim();

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
              return ch ?? '';
          }
        });
      });

  Parser<String> numberLiteral() =>
      ((digit().plus() & (char('.') & digit().plus()).optional()))
          .flatten()
          .trim();

  Parser<String> booleanLiteral() =>
      (string('true') | string('false')).trim().flatten();
}
