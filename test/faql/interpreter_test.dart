import 'package:test/test.dart';
import 'package:flutter_a11y_lints/src/faql/parser.dart';
import 'package:flutter_a11y_lints/src/faql/interpreter.dart';

// --- 1. The Mock (Simulates your future IR) ---
class MockContext implements FaqlContext {
  @override
  final String role;
  @override
  final String widgetType;
  final Map<String, Object> props;
  final List<MockContext> _children;
  final List<MockContext> _ancestors;

  MockContext({
    required this.role,
    this.widgetType = 'Container',
    this.props = const {},
    List<MockContext> children = const [],
    List<MockContext> ancestors = const [],
  })  : _children = children,
        _ancestors = ancestors;

  // Default simulated state
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
  final interpreter = FaqlInterpreter();

  // Helper to run a rule against a node
  bool run(String ruleCode, MockContext node) {
    try {
      final rule = parser.parseRule(ruleCode);
      return interpreter.evaluate(rule, node);
    } catch (e) {
      print('Execution Error: $e');
      return false;
    }
  }

  group('Interpreter Logic', () {
    test('Basic property check (Slider divisions)', () {
      final validSlider = MockContext(role: 'slider', props: {'divisions': 5});
      final invalidSlider =
          MockContext(role: 'slider', props: {'divisions': 20});

      const rule =
          'rule "r" on any { ensure: prop("divisions") as int <= 10 report: "err" }';

      expect(run(rule, validSlider), isTrue, reason: '5 <= 10');
      expect(run(rule, invalidSlider), isFalse, reason: '20 > 10');
    });

    test('Boolean state (Focusable)', () {
      final focusableNode =
          MockContext(role: 'button', props: {'focusable': true});
      final nonFocusableNode =
          MockContext(role: 'image', props: {'focusable': false});

      const rule = 'rule "r" on any { ensure: focusable report: "err" }';

      expect(run(rule, focusableNode), isTrue);
      expect(run(rule, nonFocusableNode), isFalse);
    });

    test('Traversal: children.any()', () {
      // Tree: Row -> [Text, Button]
      final tree = MockContext(
        role: 'row',
        children: [
          MockContext(role: 'text'),
          MockContext(role: 'button', props: {'focusable': true}),
        ],
      );

      // Rule: Must have at least one focusable child
      const rule =
          'rule "r" on any { ensure: children.any(focusable) report: "err" }';

      expect(run(rule, tree), isTrue);
    });

    test('Traversal: ancestors.none() (Nested Buttons)', () {
      final root = MockContext(role: 'window');
      final parentButton = MockContext(role: 'button', ancestors: [root]);
      final childButton =
          MockContext(role: 'button', ancestors: [parentButton, root]);

      // Rule: A button cannot be inside another button
      const rule = '''
        rule "no-nest" on role(button) { 
          ensure: ancestors.none(role == "button") 
          report: "err" 
        }
      ''';

      expect(run(rule, parentButton), isTrue,
          reason: 'Parent has no button ancestors');
      // Note: FAQL `role` identifier inside scope evaluates against context
      // Since context is MockContext, `role` getter returns 'button'
      expect(run(rule, childButton), isFalse,
          reason: 'Child has a button ancestor');
    });

    test('Complex Logic (&&, ||, parens)', () {
      final node = MockContext(
          role: 'switch', props: {'enabled': true, 'toggled': false});

      // (Enabled AND Not Toggled) OR Hidden
      const rule = '''
        rule "logic" on any { 
          ensure: (enabled && !toggled) || hidden
          report: "err" 
        }
      ''';

      // !toggled (true) && enabled (true) => true
      expect(run(rule, node), isTrue);
    });

    test('Short-circuiting: when clause', () {
      final node = MockContext(role: 'image'); // Missing 'label' prop entirely

      // Without 'when', this might return null/false.
      // With 'when', it should skip (return true).
      const rule = '''
        rule "safe" on any {
          when: prop("label").is_resolved
          ensure: prop("label") == "foo"
          report: "err"
        }
      ''';

      expect(run(rule, node), isTrue,
          reason: 'Should skip (pass) because when clause is false');
    });

    test('Selector Logic: Role vs Kind', () {
      final btn = MockContext(role: 'button');
      final slider = MockContext(role: 'slider');

      const rule = 'rule "k" on kind(input) { ensure: true report: "" }';

      // 'button' is not in 'input' kind (textField, slider, switch)
      expect(run(rule, btn), isTrue,
          reason: 'Rule is skipped (returns true) because selector mismatch');

      // If we want to verify it ACTUALLY ran, we force a fail
      const ruleFail = 'rule "k" on kind(input) { ensure: false report: "" }';
      expect(run(ruleFail, slider), isFalse,
          reason: 'Slider is input, so rule runs and ensure:false fails');
    });

    test('String operators: contains and matches (regex)', () {
      final node = MockContext(role: 'text', props: {'label': 'Save Changes'});

      const ruleContains =
          'rule "c" on any { ensure: prop("label") contains "Save" report: "" }';
      const ruleMatches =
          'rule "m" on any { ensure: prop("label") matches "^Save.*" report: "" }';

      expect(run(ruleContains, node), isTrue,
          reason: 'contains should find substring');
      expect(run(ruleMatches, node), isTrue,
          reason: 'matches should match regex');
    });

    test('Relation length and nested aggregators', () {
      // Row with two children; one child has a focusable grandchild
      final grandchild = MockContext(role: 'icon', props: {'focusable': true});
      final child1 = MockContext(role: 'container', children: [grandchild]);
      final child2 = MockContext(role: 'text');
      final row = MockContext(role: 'row', children: [child1, child2]);

      const ruleLen =
          'rule "len" on any { ensure: children.length == 2 report: "" }';
      const ruleNested =
          'rule "nest" on any { ensure: children.any(children.any(focusable)) report: "" }';

      expect(run(ruleLen, row), isTrue, reason: 'children.length == 2');
      expect(run(ruleNested, row), isTrue,
          reason: 'nested any should find a focusable grandchild');
    });

    test('Prop casting: as int/string/bool behavior', () {
      final node = MockContext(
          role: 'x', props: {'size': '15', 'flag': true, 'name': 123});

      // prop("size") as int -> current implementation only casts when raw is num
      const ruleSize =
          'rule "s" on any { ensure: prop("size") as int > 10 report: "" }';
      // prop("flag") as bool -> raw == true check
      const ruleFlag =
          'rule "f" on any { ensure: prop("flag") as bool report: "" }';
      // prop("name") as string -> toString()
      const ruleName =
          'rule "n" on any { ensure: prop("name") as string == "123" report: "" }';

      // size is string '15' -> comparison coerces numbers, so 15 > 10 -> true
      expect(run(ruleSize, node), isTrue);
      // flag is true -> as bool yields true
      expect(run(ruleFlag, node), isTrue);
      // name as string should equal "123"
      expect(run(ruleName, node), isTrue);
    });
  });
}
