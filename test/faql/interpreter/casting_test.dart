import 'package:test/test.dart';
import 'package:flutter_a11y_lints/src/faql/parser.dart';
import 'package:flutter_a11y_lints/src/faql/interpreter.dart';
import 'test_contexts.dart';

void main() {
  final parser = FaqlParser();
  final interpreter = FaqlInterpreter();

  bool run(String code, FaqlContext node) {
    final rule = parser.parseRule(code);
    return interpreter.evaluate(rule, node);
  }

  group('Interpreter casting and numeric coercion', () {
    test('Prop casting: as int/string/bool behavior', () {
      final node = TestContext(
          role: 'x', props: {'size': '15', 'flag': true, 'name': 123});
      const ruleSize =
          'rule "s" on any { ensure: prop("size") as int > 10 report: "" }';
      const ruleFlag =
          'rule "f" on any { ensure: prop("flag") as bool report: "" }';
      const ruleName =
          'rule "n" on any { ensure: prop("name") as string == "123" report: "" }';

      expect(run(ruleSize, node), isTrue);
      expect(run(ruleFlag, node), isTrue);
      expect(run(ruleName, node), isTrue);
    });

    test('string numeric coerces to number in comparisons', () {
      final node = TestContext(role: 'x', props: {'n': '10'});
      const rule = 'rule "r" on any { ensure: prop("n") > 5 report: "" }';
      expect(run(rule, node), isTrue);
    });

    test('invalid numeric string comparison returns false', () {
      final node = TestContext(role: 'x', props: {'n': 'abc'});
      const rule = 'rule "r" on any { ensure: prop("n") > 5 report: "" }';
      expect(run(rule, node), isFalse);
    });

    test('as int from numeric string works', () {
      final node = TestContext(role: 'x', props: {'n': '42'});
      const rule =
          'rule "r" on any { ensure: (prop("n") as int) == 42 report: "" }';
      expect(run(rule, node), isTrue);
    });

    test('as bool from string true/false', () {
      final node = TestContext(role: 'x', props: {'f': 'true'});
      const rule =
          'rule "r" on any { ensure: (prop("f") as bool) == true report: "" }';
      expect(run(rule, node), isTrue);
    });

    test('as int from non-numeric returns null and comparison false', () {
      final node = TestContext(role: 'x', props: {'n': 'NaN'});
      const rule =
          'rule "r" on any { ensure: (prop("n") as int) > 0 report: "" }';
      expect(run(rule, node), isFalse);
    });

    test('invalid cast returns null and comparison is false', () {
      final node = TestContext(role: 'x', props: {'size': 'NaN'});
      const rule =
          'rule "r" on any { ensure: prop("size") as int > 5 report: "" }';
      expect(run(rule, node), isFalse);
    });

    test('unresolved identifier evaluates as null (not the identifier name)',
        () {
      final rule = parser.parseRule(
          'rule "r" on any { ensure: prop("color") == red report: "r" }');
      final ctx = TestContext(
          role: 'button', widgetType: 'Button', props: {'color': 'blue'});
      final result = interpreter.evaluate(rule, ctx);
      expect(result, isFalse);
    });

    test('numeric coercion: string numeric property compares as number', () {
      final rule = parser.parseRule(
          'rule "s" on any { ensure: prop("size") > 5 report: "r" }');
      final ctx =
          TestContext(role: 'x', widgetType: 'X', props: {'size': '10'});
      final result = interpreter.evaluate(rule, ctx);
      expect(result, isTrue);
    });
  });
}
