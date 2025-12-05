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

  group('Interpreter logic', () {
    test('Basic property check (Slider divisions)', () {
      final validSlider = TestContext(role: 'slider', props: {'divisions': 5});
      final invalidSlider =
          TestContext(role: 'slider', props: {'divisions': 20});
      const rule =
          'rule "r" on any { ensure: prop("divisions") as int <= 10 report: "err" }';

      expect(run(rule, validSlider), isTrue);
      expect(run(rule, invalidSlider), isFalse);
    });

    test('Boolean state (Focusable)', () {
      final focusableNode =
          TestContext(role: 'button', props: {'focusable': true});
      final nonFocusableNode =
          TestContext(role: 'image', props: {'focusable': false});
      const rule = 'rule "r" on any { ensure: focusable report: "err" }';

      expect(run(rule, focusableNode), isTrue);
      expect(run(rule, nonFocusableNode), isFalse);
    });

    test('Complex Logic (&&, ||, parens)', () {
      final node = TestContext(
          role: 'switch', props: {'enabled': true, 'toggled': false});
      const rule = '''
        rule "logic" on any {
          ensure: (enabled && !toggled) || hidden
          report: "err"
        }
      ''';
      expect(run(rule, node), isTrue);
    });

    test('Short-circuiting: when clause', () {
      final node = TestContext(role: 'image');
      const rule = '''
        rule "safe" on any {
          when: prop("label").is_resolved
          ensure: prop("label") == "foo"
          report: "err"
        }
      ''';

      expect(run(rule, node), isTrue);
    });

    test('String operators: contains and matches (regex)', () {
      final node = TestContext(role: 'text', props: {'label': 'Save Changes'});
      const ruleContains =
          'rule "c" on any { ensure: prop("label") contains "Save" report: "" }';
      const ruleMatches =
          'rule "m" on any { ensure: prop("label") matches "^Save.*" report: "" }';

      expect(run(ruleContains, node), isTrue);
      expect(run(ruleMatches, node), isTrue);
    });

    test('~= case-insensitive equality operator', () {
      final node = TestContext(role: 'x', props: {'t': 'Foo '});
      const rule = 'rule "r" on any { ensure: prop("t") ~= "foo" report: "" }';
      expect(run(rule, node), isTrue);
    });

    test('Arithmetic and unary minus work with coercion', () {
      final node = TestContext(role: 'x', props: {'a': 2, 'b': '3'});
      const rule =
          'rule "r" on any { ensure: prop("a") * (prop("b") as int) == 6 report: "" }';
      expect(run(rule, node), isTrue);
    });

    test('prop(...).is_resolved inside ensure short-circuits inner prop usage',
        () {
      final node = TestContext(role: 'x');
      const rule =
          'rule "r" on any { ensure: prop("label").is_resolved && prop("label") contains "x" report: "" }';
      expect(run(rule, node), isFalse);
    });

    test('Short-circuit: RHS not evaluated for &&/||', () {
      final node = CountingContext('x');
      const ruleAnd =
          'rule "s" on any { ensure: false && prop("x") == 1 report: "" }';
      const ruleOr =
          'rule "s2" on any { ensure: 1 == 1 || prop("x") report: "" }';

      expect(run(ruleAnd, node), isFalse);
      expect(run(ruleOr, node), isTrue);
      expect(node.calls, equals(0), reason: 'RHS should not execute');
    });

    test('Selector Logic: Role vs Kind', () {
      final btn = TestContext(role: 'button');
      final slider = TestContext(role: 'slider');
      const rule = 'rule "k" on kind(input) { ensure: true report: "" }';
      const ruleFail = 'rule "k" on kind(input) { ensure: false report: "" }';

      expect(run(rule, btn), isTrue);
      expect(run(ruleFail, slider), isFalse);
    });

    test('Selector OR semantics: rule runs if any selector matches', () {
      final node = TestContext(role: 'button');
      const rule =
          'rule "s" on role(text) || role(button) { ensure: false report: "" }';
      expect(run(rule, node), isFalse);
    });
  });
}
