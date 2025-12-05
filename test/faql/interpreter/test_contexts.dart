import 'package:flutter_a11y_lints/src/faql/interpreter.dart';

/// Reusable mock context for interpreter tests with configurable props, children, and ancestors.
class TestContext implements FaqlContext {
  @override
  final String role;
  @override
  final String widgetType;
  final Map<String, Object?> _props;
  final List<TestContext> _children;
  final List<TestContext> _ancestors;

  TestContext({
    required this.role,
    this.widgetType = 'Container',
    Map<String, Object?>? props,
    List<TestContext> children = const [],
    List<TestContext> ancestors = const [],
  })  : _props = props ?? {},
        _children = children,
        _ancestors = ancestors;

  @override
  bool get isFocusable => _props['focusable'] == true;
  @override
  bool get isEnabled => _props['enabled'] != false;
  @override
  bool get isHidden => _props['hidden'] == true;
  @override
  bool get mergesDescendants => _props['merges'] == true;
  @override
  bool get hasTap => _props.containsKey('onTap');
  @override
  bool get hasLongPress => false;

  @override
  Iterable<FaqlContext> get children => _children;
  @override
  Iterable<FaqlContext> get ancestors => _ancestors;
  @override
  Iterable<FaqlContext> get siblings => [];

  @override
  Object? getProperty(String name) => _props[name];
  @override
  bool isPropertyResolved(String name) => _props.containsKey(name);
}

/// Minimal context that counts how often a property is accessed.
class CountingContext implements FaqlContext {
  @override
  final String role;
  int calls = 0;

  CountingContext(this.role);

  @override
  String get widgetType => 'Counting';
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
