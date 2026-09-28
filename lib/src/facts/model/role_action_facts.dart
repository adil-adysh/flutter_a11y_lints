import 'evidence.dart';

enum AccessibilityRole {
  unknown,
  button,
  link,
  image,
  checkbox,
  switchRole,
  slider,
  textField,
  staticText,
  heading,
  group,
}

enum ControlClassification {
  unknown,
  none,
  elevatedButton,
  textButton,
  filledButton,
  outlinedButton,
  iconButton,
  floatingActionButton,
  listTile,
  checkbox,
  switchControl,
  slider,
  textField,
}

class RoleFact {
  const RoleFact({
    required this.role,
    required this.control,
    required this.evidence,
  });

  final AccessibilityRole role;
  final ControlClassification control;
  final FactEvidence evidence;
}

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
  moveCursorForwardByCharacter,
  moveCursorBackwardByCharacter,
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
