import 'package:test/test.dart';
import 'package:flutter_a11y_lints/src/faql/parser.dart';
import 'package:flutter_a11y_lints/src/faql/interpreter.dart';

// Extra tests implemented from TODO file
class MockContext3 implements FaqlContext {
  @override
  final String role;
  @override
  final String widgetType;
  final Map<String, Object?> props;
  final List<MockContext3> _children;
  final List<MockContext3> _ancestors;

  MockContext3(
      {required this.role,
      this.widgetType = 'Container',
      this.props = const {},
      List<MockContext3> children = const [],
      List<MockContext3> ancestors = const []})
      : _children = children,
        _ancestors = ancestors;

  @override
  bool get isFocusable => props['focusable'] == true;
  @override
  bool get isEnabled => props['enabled'] != false;
  @override
  bool get isHidden => props['hidden'] == true;
  @override
  bool get mergesDescendants => props['merges'] == true;
  @override
  bool get hasTap => props.containsKey('onTap');
  @override
  bool get hasLongPress => false;

  @override
  Iterable<FaqlContext> get children => _children;
  @override
  Iterable<FaqlContext> get ancestors => _ancestors;
  @override
  Iterable<FaqlContext> get siblings => [];

  @override
  Object? getProperty(String name) => props[name];
  @override
  bool isPropertyResolved(String name) => props.containsKey(name);
}

// Helper counting context used to assert short-circuiting
class _CountingContext implements FaqlContext {
  @override
  final String role;
  int calls = 0;
  _CountingContext(this.role);

  @override
  String get widgetType => 'X';
  @override
  bool get isFocusable => false;
  @override
  bool get isEnabled => true;
  @override
  bool get isHidden => false;
  @override
  bool get mergesDescendants => false;
  @override
  bool get hasTap => false;
  @override
  bool get hasLongPress => false;
  @override
  Iterable<FaqlContext> get children => const [];
  @override
  Iterable<FaqlContext> get ancestors => const [];
  @override
  Iterable<FaqlContext> get siblings => const [];

  @override
  Object? getProperty(String name) {
    calls += 1;
    return null;
  }

  @override
  bool isPropertyResolved(String name) => false;
}

void main() {
  final parser = FaqlParser();
  final interp = FaqlInterpreter();

  bool run(String code, FaqlContext node) {
    final rule = parser.parseRule(code);
    return interp.evaluate(rule, node);
  }

  group('Interpreter Extra', () {
    test('Short-circuit: RHS not evaluated for &&/||', () {
      final node = _CountingContext('x');
      final ruleAnd =
          'rule "s" on any { ensure: false && prop("x") == 1 report: "" }';
      final ruleOr =
          'rule "s2" on any { ensure: 1 == 1 || prop("x") report: "" }';

      expect(run(ruleAnd, node), isFalse);
      expect(run(ruleOr, node), isTrue);
      expect(node.calls, equals(0),
          reason: 'RHS should not have been evaluated');
    });

    test('~= case-insensitive equality operator', () {
      final node = MockContext3(role: 'x', props: {'t': 'Foo '});
      final rule = 'rule "r" on any { ensure: prop("t") ~= "foo" report: "" }';
      expect(run(rule, node), isTrue);
    });

    test('Arithmetic and unary minus work with coercion', () {
      final node = MockContext3(role: 'x', props: {'a': 2, 'b': '3'});
      final rule =
          'rule "r" on any { ensure: prop("a") * (prop("b") as int) == 6 report: "" }';
      expect(run(rule, node), isTrue);
    });

    test('prop(...).is_resolved inside ensure short-circuits inner prop usage',
        () {
      final node = MockContext3(role: 'x'); // no label
      final rule =
          'rule "r" on any { ensure: prop("label").is_resolved && prop("label") contains "x" report: "" }';
      expect(run(rule, node), isFalse);
    });

    test('Aggregator all returns false if any child fails', () {
      final tree = MockContext3(role: 'row', children: [
        MockContext3(role: 'c', props: {'ok': true}),
        MockContext3(role: 'c', props: {'ok': false}),
      ]);
      final rule =
          'rule "r" on any { ensure: children.all(prop("ok") == true) report: "" }';
      expect(run(rule, tree), isFalse);
    });

    test('matches supports inline (?i) flag for case-insensitive pattern', () {
      final node = MockContext3(role: 'text', props: {'label': 'save'});
      final rule =
          r'rule "r" on any { ensure: prop("label") matches "(?i)^Save$" report: "" }';
      expect(run(rule, node), isTrue);
    });

    test('null equality semantics', () {
      final node = MockContext3(role: 'x');
      final rule = 'rule "r" on any { ensure: prop("x") == null report: "" }';
      expect(run(rule, node), isTrue);
    });

    test('invalid cast returns null and comparison is false', () {
      final node = MockContext3(role: 'x', props: {'size': 'NaN'});
      final rule =
          'rule "r" on any { ensure: prop("size") as int > 5 report: "" }';
      expect(run(rule, node), isFalse);
    });

    test('selector OR semantics: rule runs if any selector matches', () {
      final node = MockContext3(role: 'button');
      final rule =
          'rule "s" on role(text) || role(button) { ensure: false report: "" }';
      // Since one selector matches (role(button)), ensure:false should cause rule to fail
      expect(run(rule, node), isFalse);
    });
  });
}
