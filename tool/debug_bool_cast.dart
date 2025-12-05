import 'package:flutter_a11y_lints/src/faql/parser.dart';
import 'package:flutter_a11y_lints/src/faql/interpreter.dart';
import 'package:flutter_a11y_lints/src/faql/ast.dart';

class TestContext implements FaqlContext {
  final Map<String, Object?> props;
  final String _role;
  TestContext(this._role, this.props);
  @override
  String get role => _role;
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
  Object? getProperty(String name) => props[name];
  @override
  bool isPropertyResolved(String name) => props.containsKey(name);
}

void main() {
  final parser = FaqlParser();
  final interp = FaqlInterpreter();
  final rule = parser.parseRule(
      'rule "r" on any { ensure: (prop("f") as bool) == true report: "" }');
  final ctx = TestContext('x', {'f': 'true'});
  print('AST ensure: ${rule.ensure}');
  final ensure = rule.ensure;
  print('ensure runtime type: ${ensure.runtimeType}');
  if (ensure is BinaryExpression) {
    print('left: ${ensure.left}');
    print('right: ${ensure.right}');
  }
  final res = interp.evaluate(rule, ctx);
  print('evaluate result: $res');
}
