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

  group('Interpreter traversal', () {
    test('Traversal: children.any()', () {
      final tree = TestContext(
        role: 'row',
        children: [
          TestContext(role: 'text'),
          TestContext(role: 'button', props: {'focusable': true}),
        ],
      );
      const rule =
          'rule "r" on any { ensure: children.any(focusable) report: "" }';
      expect(run(rule, tree), isTrue);
    });

    test('Traversal: ancestors.none() (Nested Buttons)', () {
      final root = TestContext(role: 'window');
      final parentButton = TestContext(role: 'button', ancestors: [root]);
      final childButton =
          TestContext(role: 'button', ancestors: [parentButton, root]);
      const rule = '''
        rule "no-nest" on role(button) {
          ensure: ancestors.none(role == "button")
          report: ""
        }
      ''';

      expect(run(rule, parentButton), isTrue);
      expect(run(rule, childButton), isFalse);
    });

    test('Relation length and nested aggregators', () {
      final grandchild = TestContext(role: 'icon', props: {'focusable': true});
      final child1 = TestContext(role: 'container', children: [grandchild]);
      final child2 = TestContext(role: 'text');
      final row = TestContext(role: 'row', children: [child1, child2]);

      const ruleLen =
          'rule "len" on any { ensure: children.length == 2 report: "" }';
      const ruleNested =
          'rule "nest" on any { ensure: children.any(children.any(focusable)) report: "" }';

      expect(run(ruleLen, row), isTrue);
      expect(run(ruleNested, row), isTrue);
    });

    test('Aggregator all returns false if any child fails', () {
      final tree = TestContext(role: 'row', children: [
        TestContext(role: 'c', props: {'ok': true}),
        TestContext(role: 'c', props: {'ok': false}),
      ]);
      const rule =
          'rule "r" on any { ensure: children.all(prop("ok") == true) report: "" }';
      expect(run(rule, tree), isFalse);
    });
  });
}