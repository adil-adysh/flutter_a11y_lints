# Flutter Accessibility Lint Rules — High-Confidence Specification

## Document 1 — High-Confidence A11y Lint Rules Specification

### flutter_a11y_lints — Core Rule Implementation Guide (Low False-Positive Version)

**Version:** 1.0  
**Purpose:** Provide coding agents with the exact, precise rules that are safe to implement as strict warnings with minimal false positives.

---

## 1. Philosophy of High-Confidence Rules

This document defines **only the lint rules that can be enforced with near-zero false positives** across real-world Flutter apps.

These rules share three characteristics:

1. **Concrete detectability** — AST provides direct signals without guessing.
2. **Stable patterns** — Flutter internally follows semantic conventions.
3. **No contextual ambiguity** — rule should be correct regardless of:
   * custom design systems,
   * dynamic layout,
   * localization libraries,
   * abstraction layers.

Every rule here is marked WARNING by default and should be safe for large production apps.

---

## 2. The High-Confidence Core Rule Set

The following rules were selected from our earlier conversations as safe, reliable, and easy for developers to accept.

### Rule A01 (Core Only) — Label Non-Text Controls

`flutter_a11y_label_non_text_controls`

**Trigger only for:**

* `IconButton` with:
  * `onPressed != null`
  * **AND** no `tooltip:`
  * **AND** not wrapped in `Semantics(label: ...)`

**Do NOT apply heuristic logic** (e.g., detecting InkWell + Icon). We keep this rule extremely tight.

**Detection Logic (AST-Exact):**

* Node: `InstanceCreationExpression`
* Class: `IconButton`
* Conditions:
  * `onPressed` present and not null
  * `tooltip` is *not* provided
  * Parent is not `Semantics` with a label
* Report when all conditions match.

**False-Positive Probability:** Very low.

---

### Rule A03 (Core Only) — Decorative Images Must Be Excluded

`flutter_a11y_decorative_images_excluded`

**Trigger only when filename is obviously decorative:**

Decorative keywords:

```text
background, bg, backdrop, decor, decorative, pattern, wallpaper, divider, separator
```

**Detection Logic:**

* Node: `InstanceCreationExpression`
* Class: `Image.asset`
* Conditions:
  * Asset path literal contains decorative keywords
  * `excludeFromSemantics` is not set or set to false
  * No `semanticLabel` provided
* Report violation.

**False-Positive Probability:** Very low.

---

### Rule A04 — Informative Images Must Have Labels (Safe Subset)

`flutter_a11y_informative_images_labeled`

**Safe contexts only:**

* `CircleAvatar(backgroundImage: ...)`
* `ListTile.leading` when leading child is an `Image` or `CircleAvatar`
* `Image.network` inside a `Row`/`Column` with adjacent `Text(profileName)` (common avatar pattern)

**Detection Logic:**

* Identify `Image.network / Image.file / backgroundImage` used in:
  * `CircleAvatar`
  * `ListTile.leading`
* Conditions:
  * No `semanticLabel`
  * Not wrapped in a `Semantics(label: ...)`

**False-Positive Probability:** Very low.

---

### Rule A05 — No Redundant Semantics on Material Buttons

`flutter_a11y_no_redundant_semantics_wrappers_on_material_buttons`

**Material buttons include:**

* `IconButton`
* `ElevatedButton`
* `FilledButton`
* `TextButton`
* `OutlinedButton`
* `FloatingActionButton`

**Violation:**
Wrapping any of these inside:

```dart
Semantics(button: true)
Semantics()
```

without adding a custom label (or with a redundant `button: true`).

**Detection Logic:**

* Node: `InstanceCreationExpression` → `Semantics`
* Child is a Material button type
* And ANY of:
  * `button: true`
  * No other meaningful semantic property (i.e., empty Semantics wrapper)

**False-Positive Probability:** Near zero.

---

### Rule A11 (Restricted Core) — Minimum Tap Target Size (Literal Values Only)

`flutter_a11y_minimum_tap_target_size`

**Only warn when:**

* Direct parent is a `SizedBox`, `Container`, or `ConstrainedBox`
* `width` or `height` is a **literal numeric value**
* And that value < 44 (Apple) or < 48 (Material)

**Do NOT warn about:**

* LayoutBuilder
* MediaQuery
* Expressions
* Variables
* Theme-based constraints

**Detection Logic:**

* Node: `InstanceCreationExpression`
* Class: `SizedBox` / `Container` / `ConstrainedBox`
* Child is interactive (IconButton, GestureDetector, TextButton, etc.)
* Literal `width` or `height` < 44

**False-Positive Probability:** Very low.

---

### Rule A16 — Toggle State Must Use Semantics Flags

`flutter_a11y_toggle_state_via_semantics_flag`

**Trigger only when:**

* Dev embeds “on/off/selected/checked” inside **label logic** near toggle widgets.

**Toggle widgets:**

* `Switch`
* `Checkbox`
* `Radio`
* `ToggleButtons`
* `SwitchListTile`, etc.

**Detection Logic:**

* Find `Semantics(label: <conditional expression>)`
* Where the conditional returns text containing “on/off/selected/checked”
* And the child is a toggle widget
* Report “Use `toggled:` or `checked:` instead.”

**False-Positive Probability:** Very low.

---

### Rule A18 (Strict Core) — Hidden Focus Traps

`flutter_a11y_avoid_hidden_focus_traps`

**Trigger only when:**

* `Offstage(offstage: true, child: TextField/Button/Focusable widget)`
* or `Visibility(visible: false, child: ...)` with focusable children

**No heuristics. Only literal `true/false`.**

**Detection Logic:**

* Node: `InstanceCreationExpression` → `Offstage`
* `offstage` argument is literal `true`
* Descendant is focusable (TextField, button, GestureDetector)
* Report violation.

**False-Positive Probability:** Very low.

---

### Rule A21 — Use IconButton.tooltip Instead of Tooltip Wrapper

`flutter_a11y_use_iconbutton_tooltip`

**Trigger:**

* `Tooltip(child: IconButton(...))`
* IconButton.tooltip is null

**Detection Logic:**

* Node: `InstanceCreationExpression` → `Tooltip`
* child is IconButton
* IconButton has no tooltip

**False-Positive Probability:** Very low.

---

### Rule A22 — Respect Semantic Boundaries (ListTile Family)

`flutter_a11y_respect_widget_semantic_boundaries`

**Trigger only when:**

* `MergeSemantics` wraps:
  * `ListTile`
  * `CheckboxListTile`
  * `SwitchListTile`
  * `RadioListTile`

These widgets have their own semantic merging. Wrapping them almost always breaks behavior.

**Detection Logic:**

* Node: `InstanceCreationExpression` → `MergeSemantics`
* child is one of the above
* Warn

**False-Positive Probability:** Extremely low.

---

### Rule A24 (Safe Core) — Drag Handle Icons Must Be Excluded

`flutter_a11y_exclude_visual_only_indicators`

**Trigger only for:**

* `Icon(Icons.drag_handle)`
* `Icon(Icons.drag_indicator)`

Used as:

* `ListTile.leading`
* or anywhere not inside `ExcludeSemantics`

**Detection Logic:**

* Detect Icon with those two iconData values
* Check if ancestor is `ExcludeSemantics`
* If not → warn

**False-Positive Probability:** Very low.

---

## 3. Rules Explicitly Omitted From High-Confidence Set

Rules that are too heuristic and can produce false positives:

* A06 Merge multi-part value semantics
* A07 Replace semantics cleanly
* A09 Numeric-unit requirement
* A10 Debounce announcements
* A12 Focus order
* A13 Single-role composite control
* A14 Validation feedback
* A15 Custom gesture semantics
* A17 Hint correctness
* A19 Disabled state
* A20 Announce async once
* A23 Contextual labels in lists/grids

These belong in “Heuristic / Medium Confidence Rule Set” (Document 4).

---

## 4. Implementation Notes for Coding Agent

### Every rule must begin with

```dart
if (!fileUsesFlutter(unit)) return;
```

### Avoid scanning entire AST when possible

Register only visitors needed for each rule.

### For every rule

* Report once per offending node
* Use `reporter.atNode(node).report(code)`
* Provide actionable correctionMessage

---

## 5. Summary Table

| Rule | Confidence | Severity | Should Implement? |
| ---- | ---------- | -------- | ----------------- |
| A01  | Very High  | WARNING  | Yes               |
| A03  | Very High  | WARNING  | Yes               |
| A04  | Very High  | WARNING  | Yes               |
| A05  | Very High  | WARNING  | Yes               |
| A11  | Very High  | WARNING  | Yes               |
| A16  | Very High  | WARNING  | Yes               |
| A18  | Very High  | WARNING  | Yes               |
| A21  | Very High  | WARNING  | Yes               |
| A22  | Very High  | WARNING  | Yes               |
| A24  | Very High  | WARNING  | Yes               |
