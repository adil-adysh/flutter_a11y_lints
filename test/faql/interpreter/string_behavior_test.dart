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

  group('Interpreter string behavior', () {
    test('contains with null left operand returns false', () {
      final node = TestContext(role: 'text');
      const rule =
          'rule "c" on any { ensure: prop("label") contains "foo" report: "" }';
      expect(run(rule, node), isFalse);
    });

    test('next_focus/prev_focus relations default to empty and length == 0',
        () {
      final node = TestContext(role: 'x');
      const rule =
          'rule "r" on any { ensure: next_focus.length == 0 report: "" }';
      expect(run(rule, node), isTrue);
    });

    test('numeric string equality with literal is false (no coercion)', () {
      final node = TestContext(role: 'x', props: {'size': '10'});
      const rule = 'rule "eq" on any { ensure: prop("size") == 10 report: "" }';
      expect(run(rule, node), isFalse);
    });

    test('matches honors anchors and is case-sensitive by default', () {
      final node = TestContext(role: 'text', props: {'label': 'Save'});
      final rule1 =
          r'rule "r1" on any { ensure: prop("label") matches "^Save$" report: "" }';
      final rule2 =
          r'rule "r2" on any { ensure: prop("label") matches "^save$" report: "" }';
      expect(run(rule1, node), isTrue);
      expect(run(rule2, node), isFalse);
    });

    test('matches supports inline (?i) flag for case-insensitive pattern', () {
      final node = TestContext(role: 'text', props: {'label': 'save'});
      const rule =
          r'rule "r" on any { ensure: prop("label") matches "(?i)^Save$" report: "" }';
      expect(run(rule, node), isTrue);
    });

    test('invalid regex in matches now throws at parse time', () {
      const rule =
          'rule "r" on any { ensure: prop("label") matches "[unclosed" report: "" }';
      expect(() => parser.parseRule(rule), throwsFormatException);
    });
  });
}
