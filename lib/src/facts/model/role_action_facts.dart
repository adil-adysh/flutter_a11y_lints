import 'evidence.dart';

enum ActionKind {
  tap,
  longPress,
  increase,
  decrease,
  scrollLeft,
  scrollRight,
  scrollUp,
  scrollDown,
  dismiss,
  expand,
  collapse,
  copy,
  cut,
  paste,
  setText,
  setSelection,
  custom,
}

enum ActionAvailability { unknown, present, absent, dynamic }

/// An action fact intentionally records availability, not callback behavior.
class SemanticActionFact {
  const SemanticActionFact({
    required this.kind,
    required this.availability,
    required this.evidence,
  });

  final ActionKind kind;
  final ActionAvailability availability;
  final FactEvidence evidence;
}
