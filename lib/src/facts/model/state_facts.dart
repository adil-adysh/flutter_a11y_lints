import 'evidence.dart';

enum EnabledState { unknown, enabled, disabled }

enum CheckedState { unknown, checked, unchecked, mixed }

enum SelectedState { unknown, selected, unselected }

enum ToggledState { unknown, on, off }

enum ExpandedState { unknown, expanded, collapsed }

enum FocusableState { unknown, focusable, notFocusable }

enum FocusedState { unknown, focused, unfocused }

enum RequiredState { unknown, required, optional }

enum ReadOnlyState { unknown, readOnly, editable }

enum ObscuredState { unknown, obscured, unobscured }

enum MultilineState { unknown, multiline, singleLine }

class ControlStateFact {
  const ControlStateFact({
    this.enabled = EnabledState.unknown,
    this.checked = CheckedState.unknown,
    this.selected = SelectedState.unknown,
    this.toggled = ToggledState.unknown,
    this.expanded = ExpandedState.unknown,
    this.focusable = FocusableState.unknown,
    this.focused = FocusedState.unknown,
    this.required = RequiredState.unknown,
    this.readOnly = ReadOnlyState.unknown,
    this.obscured = ObscuredState.unknown,
    this.multiline = MultilineState.unknown,
    this.evidence = const FactEvidence(
      provenance: FactProvenance.exact,
      knowledge: KnowledgeState.unknown,
    ),
  });

  final EnabledState enabled;
  final CheckedState checked;
  final SelectedState selected;
  final ToggledState toggled;
  final ExpandedState expanded;
  final FocusableState focusable;
  final FocusedState focused;
  final RequiredState required;
  final ReadOnlyState readOnly;
  final ObscuredState obscured;
  final MultilineState multiline;
  final FactEvidence evidence;
}
