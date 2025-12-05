import 'package:test/test.dart';
import 'package:flutter_a11y_lints/src/faql/parser.dart';
import 'package:flutter_a11y_lints/src/faql/interpreter.dart';

// Minimal Mock used by these extra tests (keeps file self-contained)
class MockContext2 implements FaqlContext {
  @override
  final String role;
  @override
  final String widgetType;
  final Map<String, Object?> props;
  final List<MockContext2> _children;
  final List<MockContext2> _ancestors;

  MockContext2(
      {required this.role,
      this.widgetType = 'Container',
      this.props = const {},
      List<MockContext2> children = const [],
      List<MockContext2> ancestors = const []})
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

void main() {
  final parser = FaqlParser();
  final interp = FaqlInterpreter();

  bool run(String code, MockContext2 node) {
    final rule = parser.parseRule(code);
    return interp.evaluate(rule, node);
  }

  group('Interpreter Additional Edge Cases', () {
    test('invalid regex in matches returns false and does not throw', () {
      final node = MockContext2(role: 'text', props: {'label': 'abc'});
      const rule =
          'rule "r" on any { ensure: prop("label") matches "[unclosed" report: "" }';
      expect(run(rule, node), isFalse);
    });

    test('contains with null left operand returns false', () {
      final node = MockContext2(role: 'text'); // no label
      const rule =
          'rule "c" on any { ensure: prop("label") contains "foo" report: "" }';
      expect(run(rule, node), isFalse);
    });

    test('next_focus/prev_focus relations default to empty and length == 0',
        () {
      final node = MockContext2(role: 'x');
      const rule =
          'rule "r" on any { ensure: next_focus.length == 0 report: "" }';
      expect(run(rule, node), isTrue);
    });

    test(
        'equality between number literal and numeric string is false (no coercion)',
        () {
      final node = MockContext2(role: 'x', props: {'size': '10'});
      const rule = 'rule "eq" on any { ensure: prop("size") == 10 report: "" }';
      // Current interpreter uses strict equality (no coercion), so this should be false
      expect(run(rule, node), isFalse);
    });

    test('matches honors anchors and is case-sensitive by default', () {
      final node = MockContext2(role: 'text', props: {'label': 'Save'});
      final rule1 =
          r'rule "r1" on any { ensure: prop("label") matches "^Save$" report: "" }';
      final rule2 =
          r'rule "r2" on any { ensure: prop("label") matches "^save$" report: "" }';
      expect(run(rule1, node), isTrue);
      expect(run(rule2, node), isFalse);
    });
  });
}
