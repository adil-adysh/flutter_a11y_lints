import 'evidence.dart';

enum VisualVisibilityState { unknown, visible, visuallyHidden }

enum HitTestState { unknown, available, unavailable }

enum SemanticInclusionState { unknown, included, excluded }

enum AccessibilityFocusExposureState { unknown, exposed, blocked }

/// Independent rendering and accessibility exposure states for one node.
class ExposureFact {
  const ExposureFact({
    required this.visual,
    required this.semantic,
    required this.focus,
    required this.evidence,
    this.hitTest = HitTestState.unknown,
  });

  final VisualVisibilityState visual;
  final HitTestState hitTest;
  final SemanticInclusionState semantic;
  final AccessibilityFocusExposureState focus;
  final FactEvidence evidence;
}
