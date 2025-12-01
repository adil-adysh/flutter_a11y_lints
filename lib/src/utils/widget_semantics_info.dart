import '../types/semantic_role.dart';

/// Information about a widget's default semantic behavior
class WidgetSemanticsInfo {
  /// The semantic role this widget represents
  final SemanticRole role;

  /// Whether the widget is interactive by default
  final bool isInteractive;

  /// Whether the widget merges its children's semantics
  final bool mergesChildren;

  /// Whether the widget manages its own semantics completely
  final bool semanticsManaged;

  /// Whether the widget has a tooltip parameter
  final bool hasTooltipParam;

  /// Whether the widget has a semanticLabel parameter
  final bool hasSemanticLabelParam;

  const WidgetSemanticsInfo({
    required this.role,
    this.isInteractive = false,
    this.mergesChildren = false,
    this.semanticsManaged = false,
    this.hasTooltipParam = false,
    this.hasSemanticLabelParam = false,
  });

  factory WidgetSemanticsInfo.unknown() =>
      const WidgetSemanticsInfo(role: SemanticRole.unknown);
}
