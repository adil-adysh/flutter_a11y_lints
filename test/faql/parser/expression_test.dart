import 'package:test/test.dart';
import 'package:flutter_a11y_lints/src/faql/parser.dart';
import 'package:flutter_a11y_lints/src/faql/ast.dart';

void main() {
  final parser = FaqlParser();

  group('Parser expression coverage', () {
    test('parse slider-integrity example', () {
      const input = '''
        rule "slider-integrity" on kind(slider) {
          meta { severity: "error" }
          when: prop("divisions").is_resolved
          ensure: prop("divisions") as int <= 10 && focusable
          report: "Too many divisions!"
        }
      ''';

      final rule = parser.parseRule(input);
      expect(rule.name, 'slider-integrity');
      expect(rule.report, 'Too many divisions!');
      expect(rule.selectors, isNotEmpty);
      final ensure = rule.ensure as BinaryExpression;
      expect(ensure.op, FaqlBinaryOp.and);
      final left = ensure.left as BinaryExpression;
      expect(left.op, FaqlBinaryOp.lessEqual);
      expect(left.left, isA<PropExpression>());
      expect((left.left as PropExpression).name, 'divisions');
      expect(left.right, isA<LiteralExpression>());
      expect((left.right as LiteralExpression).value, 10);
    });

    test('parse prop is_resolved and as cast', () {
      const input = '''
        rule "r" on any {
          ensure: prop("x").is_resolved && prop("y") as int > 0
          report: "ok"
        }
      ''';

      final rule = parser.parseRule(input);
      final ensure = rule.ensure as BinaryExpression;
      expect(ensure.op, FaqlBinaryOp.and);
      final left = ensure.left as PropExpression;
      expect(left.name, 'x');
      expect(left.isResolved, true);
    });

    test('children.any aggregation', () {
      const input = '''
        rule "r" on any {
          ensure: children.any(prop("label") contains "foo")
          report: "r"
        }
      ''';

      final rule = parser.parseRule(input);
      final expr = rule.ensure;
      expect(expr, isA<AggregatorExpression>());
      final agg = expr as AggregatorExpression;
      expect(agg.relation, FaqlRelation.children);
      expect(agg.aggregator, FaqlAggregator.any);
    });

    test('boolean state', () {
      const input = '''
        rule "r" on any { ensure: focusable && enabled report: "r" }
      ''';

      final rule = parser.parseRule(input);
      final expr = rule.ensure as BinaryExpression;
      expect(expr.op, FaqlBinaryOp.and);
      expect(expr.left, isA<BooleanStateExpression>());
      expect((expr.left as BooleanStateExpression).name, 'focusable');
    });

    test('negation and parentheses grouping', () {
      const input = '''
        rule "n" on any { ensure: !(prop("x") == 0) && !focusable report: "r" }
      ''';

      final rule = parser.parseRule(input);
      final be = rule.ensure as BinaryExpression;
      expect(be.op, FaqlBinaryOp.and);
      expect(be.left, isA<UnaryExpression>());
      expect((be.left as UnaryExpression).op, '!');
      expect(be.right, isA<UnaryExpression>());
    });

    test('equality and matches operators', () {
      const input = '''
        rule "eq" on any { ensure: prop("label") matches "^foo.*" || prop("count") == 5 report: "r" }
      ''';

      final rule = parser.parseRule(input);
      final be = rule.ensure as BinaryExpression;
      expect(be.op, FaqlBinaryOp.or);
      expect(be.left, isA<RegexMatchExpression>());
      final leftRegex = be.left as RegexMatchExpression;
        expect(leftRegex.pattern.pattern, '^foo.*');
      expect(be.right, isA<BinaryExpression>());
      expect((be.right as BinaryExpression).op, FaqlBinaryOp.equals);
    });

    test('relation length and float literal', () {
      const input = '''
        rule "len" on any { ensure: children.length > 2 && prop("ratio") >= 0.75 report: "r" }
      ''';

      final rule = parser.parseRule(input);
      final be = rule.ensure as BinaryExpression;
      expect(be.op, FaqlBinaryOp.and);
      final left = be.left as BinaryExpression;
      expect(left.left, isA<RelationLengthExpression>());
      final right = be.right as BinaryExpression;
      expect(right.right, isA<LiteralExpression>());
      expect((right.right as LiteralExpression).value, closeTo(0.75, 1e-9));
    });

    test('aggregator with complex inner expression', () {
      const input = '''
        rule "agg" on any {
          ensure: children.any(prop("label") contains "foo" && prop("count") > 0)
          report: "r"
        }
      ''';

      final rule = parser.parseRule(input);
      final expr = rule.ensure as AggregatorExpression;
      expect(expr.aggregator, FaqlAggregator.any);
      expect(expr.expr, isA<BinaryExpression>());
      final inner = expr.expr as BinaryExpression;
      expect(inner.op, FaqlBinaryOp.and);
    });

    test('aggregator all/none variations', () {
      const input = '''
        rule "agg2" on any { ensure: ancestors.all(prop("a") == "b") report: "r" }
      ''';

      final rule = parser.parseRule(input);
      final expr = rule.ensure as AggregatorExpression;
      expect(expr.aggregator, FaqlAggregator.all);
      expect(expr.relation, FaqlRelation.ancestors);
    });

    test('unary minus with float literal', () {
      const input = '''
        rule "num" on any { ensure: prop("n") < -3.5 report: "r" }
      ''';

      final rule = parser.parseRule(input);
      final be = rule.ensure as BinaryExpression;
      expect(be.op, FaqlBinaryOp.less);
      expect(be.right, isA<UnaryExpression>());
      final ue = be.right as UnaryExpression;
      expect(ue.op, '-');
      expect(ue.expr, isA<LiteralExpression>());
      expect((ue.expr as LiteralExpression).value, closeTo(3.5, 1e-9));
    });

    test('contains operator', () {
      const input = '''
        rule "c" on any { ensure: prop("label") contains "bar" report: "r" }
      ''';

      final rule = parser.parseRule(input);
      final be = rule.ensure as BinaryExpression;
      expect(be.op, FaqlBinaryOp.contains);
    });

    test('nested aggregators', () {
      const input = '''
        rule "nest" on any {
          ensure: children.any(ancestors.any(prop("label") contains "x"))
          report: "r"
        }
      ''';

      final rule = parser.parseRule(input);
      final expr = rule.ensure as AggregatorExpression;
      expect(expr.aggregator, FaqlAggregator.any);
      expect(expr.expr, isA<AggregatorExpression>());
      final inner = expr.expr as AggregatorExpression;
      expect(inner.relation, FaqlRelation.ancestors);
      expect(inner.aggregator, FaqlAggregator.any);
    });

    test('operator precedence (AND binds tighter than OR)', () {
      const input = '''
        rule "prec" on any { ensure: focusable || enabled && prop("n") == 1 report: "r" }
      ''';

      final rule = parser.parseRule(input);
      final top = rule.ensure as BinaryExpression;
      expect(top.op, FaqlBinaryOp.or);
      expect(top.left, isA<BooleanStateExpression>());
      expect(top.right, isA<BinaryExpression>());
      expect((top.right as BinaryExpression).op, FaqlBinaryOp.and);
    });

    test('prop as-cast produces asType', () {
      const input = '''
        rule "cast" on any { ensure: prop("score") as int > 0 report: "r" }
      ''';

      final rule = parser.parseRule(input);
      final be = rule.ensure as BinaryExpression;
      final left = be.left as PropExpression;
      expect(left.asType, 'int');
    });

    test('matches operator with regex and ~= operator', () {
      const input = '''
        rule "m" on any { ensure: prop("t") matches "^foo\\d+" || prop("v") ~= "bar" report: "r" }
      ''';

      final rule = parser.parseRule(input);
      final be = rule.ensure as BinaryExpression;
      expect(be.op, FaqlBinaryOp.or);
      expect(be.left, isA<RegexMatchExpression>());
      final leftRegex = be.left as RegexMatchExpression;
      expect(leftRegex.pattern.pattern, '^foo\\d+');
      expect((be.right as BinaryExpression).op, FaqlBinaryOp.tildeEquals);
    });

    test('boolean state tokens all parsed', () {
      const states = [
        'focusable',
        'enabled',
        'hidden',
        'checked',
        'toggled',
        'merges_descendants',
        'has_tap',
        'has_long_press',
        'is_empty',
        'is_not_empty'
      ];
      for (final s in states) {
        final input = 'rule "b" on any { ensure: $s report: "r" }';
        final rule = parser.parseRule(input);
        final expr = rule.ensure;
        expect(expr, isA<BooleanStateExpression>());
        expect((expr as BooleanStateExpression).name, s);
      }
    });

    test('relation names and aggregator varieties', () {
      const input = '''
        rule "r" on any {
          ensure: children.length > 0 && siblings.none(prop("x") == "y") && ancestors.all(prop("a") ~= "foo")
          report: "r"
        }
      ''';

      final rule = parser.parseRule(input);
      final top = rule.ensure as BinaryExpression;
      bool foundLength = false;
      bool foundNone = false;
      bool foundAll = false;

      void walk(FaqlExpression e) {
        if (e is RelationLengthExpression && e.relation == FaqlRelation.children)
          foundLength = true;
        if (e is AggregatorExpression &&
            e.aggregator == FaqlAggregator.none &&
            e.relation == FaqlRelation.siblings) {
          foundNone = true;
        }
        if (e is AggregatorExpression &&
            e.aggregator == FaqlAggregator.all &&
            e.relation == FaqlRelation.ancestors) {
          foundAll = true;
        }
        if (e is UnaryExpression) walk(e.expr);
        if (e is BinaryExpression) {
          walk(e.left);
          walk(e.right);
        }
        if (e is AggregatorExpression) walk(e.expr);
      }

      walk(top);
      expect(foundLength, isTrue);
      expect(foundNone, isTrue);
      expect(foundAll, isTrue);
    });
  });
}
