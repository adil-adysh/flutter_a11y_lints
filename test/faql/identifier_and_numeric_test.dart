import 'package:test/test.dart';
import 'package:flutter_a11y_lints/src/faql/parser.dart';
import 'package:flutter_a11y_lints/src/faql/interpreter.dart';
import 'package:flutter_a11y_lints/src/faql/ast.dart';

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
  test('unresolved identifier evaluates as null (not the identifier name)', () {
    final parser = FaqlParser();
    final rule = parser.parseRule(
        'rule "r" on any { ensure: prop("color") == red report: "r" }');
    final ctx = TestContext('button', 'Button', {'color': 'blue'});
    final interp = FaqlInterpreter();
    final result = interp.evaluate(rule, ctx);
    // color == red -> 'blue' == null -> false -> rule fails -> evaluate returns false
    expect(result, isFalse);
  });

  test('numeric coercion: string numeric property compares as number', () {
    final parser = FaqlParser();
    final rule = parser
        .parseRule('rule "s" on any { ensure: prop("size") > 5 report: "r" }');
    final ctx = TestContext('x', 'X', {'size': '10'});
    final interp = FaqlInterpreter();
    final result = interp.evaluate(rule, ctx);
    // '10' should be coerced to number 10 and 10 > 5 -> true
    expect(result, isTrue);
  });
}
