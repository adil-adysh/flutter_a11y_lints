import 'package:test/test.dart';
import 'package:flutter_a11y_lints/src/faql/ast.dart';

void main() {
  test('Faql AST basic toString and fields', () {
    final lit = LiteralExpression(123);
    expect(lit.toString(), contains('Literal(123)'));

    final bstate = BooleanStateExpression('is_enabled');
    expect(bstate.toString(), contains('BoolState(is_enabled)'));

    final prop = PropExpression('foo', asType: 'int', isResolved: true);
    expect(prop.name, equals('foo'));
    expect(prop.toString(), contains('Prop('));

    final unary = UnaryExpression('!', lit);
    expect(unary.toString(), contains('Unary('));

    final bin = BinaryExpression(lit, FaqlBinaryOp.equals, LiteralExpression(123));
    expect(bin.toString(), contains('Binary('));

    final agg =
      AggregatorExpression(FaqlRelation.children, FaqlAggregator.all, LiteralExpression(true));
    expect(agg.toString(), contains('Aggregator('));
    final len = RelationLengthExpression(FaqlRelation.children);
    expect(len.toString(), contains('Length('));

    final id = Identifier('myId');
    expect(id.toString(), contains('Identifier(myId)'));

    final rule = FaqlRule(
      name: 'r',
      selectors: [AnySelector()],
      meta: {},
      when: null,
      ensure: LiteralExpression(true),
      report: 'ok',
    );
    expect(rule.name, equals('r'));
    expect(rule.toString(), contains('FaqlRule('));
  });
}
