import 'package:test/test.dart';
import 'package:flutter_a11y_lints/src/faql/parser.dart';
import 'package:flutter_a11y_lints/src/faql/interpreter.dart';

class MockContext2 implements FaqlContext {
  final Map<String, Object?> props;
  final String role;
  MockContext2(this.role, [this.props = const {}]);

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
  Iterable<FaqlContext> get children => const [];
  @override
  Iterable<FaqlContext> get ancestors => const [];
  @override
  Iterable<FaqlContext> get siblings => const [];
  @override
  Object? getProperty(String name) => props[name];
  @override
  bool isPropertyResolved(String name) => props.containsKey(name);
  @override
  String get widgetType => 'X';
}

class TestContext implements FaqlContext {
  final String _role;
  final String _widgetType;
  final Map<String, Object?> _props;

  TestContext(this._role, this._widgetType, [Map<String, Object?>? props])
      : _props = props ?? {};

  @override
  String get role => _role;

  @override
  String get widgetType => _widgetType;

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
  Iterable<FaqlContext> get ancestors => const [];

  @override
  Iterable<FaqlContext> get children => const [];

  @override
  Iterable<FaqlContext> get siblings => const [];

  @override
  Object? getProperty(String name) => _props[name];

  @override
  bool isPropertyResolved(String name) => _props.containsKey(name);
}

void main() {
  final parser = FaqlParser();
  final interp = FaqlInterpreter();

  bool run(String code, FaqlContext node) {
    final rule = parser.parseRule(code);
    return interp.evaluate(rule, node);
  }

  group('Casting and Numeric Coercion', () {
    test('string numeric coerces to number in comparisons', () {
      final node = MockContext2('x', {'n': '10'});
      final rule = 'rule "r" on any { ensure: prop("n") > 5 report: "" }';
      expect(run(rule, node), isTrue);
    });

    test('invalid numeric string comparison returns false', () {
      final node = MockContext2('x', {'n': 'abc'});
      final rule = 'rule "r" on any { ensure: prop("n") > 5 report: "" }';
      expect(run(rule, node), isFalse);
    });

    test('as int from numeric string works', () {
      final node = MockContext2('x', {'n': '42'});
      final rule = 'rule "r" on any { ensure: (prop("n") as int) == 42 report: "" }';
      expect(run(rule, node), isTrue);
    });

    test('as bool from string true/false', () {
      final node = MockContext2('x', {'f': 'true'});
      final rule = 'rule "r" on any { ensure: (prop("f") as bool) == true report: "" }';
      expect(run(rule, node), isTrue);
    });

    test('as int from non-numeric returns null and comparison false', () {
      final node = MockContext2('x', {'n': 'NaN'});
      final rule = 'rule "r" on any { ensure: (prop("n") as int) > 0 report: "" }';
      expect(run(rule, node), isFalse);
    });
  });

  group('Additional Interpreter Behaviors', () {
    test('unresolved identifier evaluates as null (not the identifier name)', () {
      final rule = parser.parseRule('rule "r" on any { ensure: prop("color") == red report: "r" }');
      final ctx = TestContext('button', 'Button', {'color': 'blue'});
      final result = interp.evaluate(rule, ctx);
      expect(result, isFalse);
    });

    test('numeric coercion: string numeric property compares as number', () {
      final rule = parser.parseRule('rule "s" on any { ensure: prop("size") > 5 report: "r" }');
      final ctx = TestContext('x', 'X', {'size': '10'});
      final result = interp.evaluate(rule, ctx);
      expect(result, isTrue);
    });
  });
}
