
# 📘 flutter_a11y_lints — Accessibility Rules & Specification

### Version 1.0 — Final Developer & Linter Author Guide

**Maintainers:** flutter_a11y_lints contributors
**Audience:**

* Flutter application developers
* Accessibility linter implementers
* Tooling and CI maintainers

---

# 0. Purpose

`flutter_a11y_lints` is a static accessibility linter for Flutter.
Its purpose is to detect common accessibility issues **before runtime** by analyzing:

* Dart **AST**
* Widget structure (**WidgetNode IR**)
* Derived semantics (**Static SemanticTree IR**)

This document is the **canonical reference** for:

* The **full rule set (A01–A27)**
* Their **confidence levels and modes**
* Their **behavior, rationale, and detection boundaries**
* The **architecture constraints** that ensure low false positives
* Guidance for Flutter developers using the linter
* Guidance for contributors implementing new rules

Rule IDs **never change**.
The order in this document is for clarity, not numbering.

---

# 1. Understanding Modes & Confidence

The linter operates in three modes:

---

## **1.1 Conservative Mode (Default)**

**High-confidence rules**
**Severity:** `WARNING`
**False-positive risk:** Near zero
**Enabled by default**

Characteristics:

* Uses primitive Flutter widgets only
* Uses literal-only checks
* Does NOT assume design system semantics
* Does NOT inspect localization expressions
* Does NOT infer layout
* Predictable, deterministic

These are “must-fix” issues.

---

## **1.2 Expanded Mode (Optional)**

**Medium-confidence rules**
**Severity:** mostly `INFO`
**False-positive risk:** low-to-medium
**Enabled with:**

```yaml
flutter_a11y_lints:
  mode: expanded
```

Characteristics:

* Heuristics used carefully
* Single-file context only
* Literal-only text checks
* Structural grouping heuristics
* Never fails CI unless the team opts in

These are “should-fix” suggestions.

---

## **1.3 Advisory / Experimental Mode (Opt-in only)**

**Low-confidence rules**
**Severity:** `INFO`
**False-positive risk:** medium-to-high
**Disabled unless explicitly enabled**

Characteristics:

* Highly contextual
* Often layout-dependent
* Useful for strict teams with design systems

---

# 2. The Semantic IR Architecture (What Rules Operate On)

All rules work on a **static accessibility view** of the widget tree created via:

### **2.1 AST → WidgetNode Tree**

Extract:

* widget type
* children
* literal size constraints
* gesture handlers
* literal text
* role hints from known primitive widgets

### **2.2 WidgetNode Tree → SemanticTree**

Determines:

* final roles (button, image, staticText, toggle, etc.)
* merged/excluded semantics
* tap actions, toggle states
* labels and hints (literal vs dynamic)
* focusability
* hidden/visible state
* effective semantics after parent manipulation

### **2.3 IR Structural Helpers**

* `accessibilityFocusNodes`: nodes visited by screen readers
* `physicalNodes`: all rendered nodes
* `labelGuarantee`:

  * `none`
  * `hasStaticLabel`
  * `hasLabelButDynamic`
* `layoutGroupId`: heuristic grouping (Row/Column siblings)
* `SemanticNeighborhood`: siblings and parent-child semantics

### **2.4 IR Constraints (Important)**

The IR **does NOT** attempt:

* layout resolution
* runtime size computation
* localization content inference
* multi-file context stitching
* style-to-role inference beyond trivial cases

These constraints keep false positives low and performance high.

---

# 3. Conservative Mode Rules (High Confidence, WARNING)

These **must always fire correctly** with very low false positives.

---

## **A01 — Label Non-Text Controls**

**ID:** `flutter_a11y_label_non_text_controls`
**Severity:** WARNING
**Confidence:** High

### Specification

Warn when a primitive `IconButton` is interactive but has **no accessible label**.

### Triggers

* `IconButton(onPressed != null)`
* No `tooltip:` parameter
* No `Semantics(label: ...)` ancestor

### Not Triggered

* Custom button wrappers (design systems)
* Any non-literal label (i18n) — considered “unknown”

---

## **A03 — Decorative Images Must Be Excluded**

**ID:** `flutter_a11y_decorative_images_excluded`
**Severity:** WARNING
**Confidence:** High

### Specification

Warn for `Image.asset` whose literal filename clearly indicates decoration:

Keywords:
`background, bg, decor, decorative, pattern, wallpaper, divider, separator`

### Requirements

* Filename must be **literal**
* No `semanticLabel`
* No `excludeFromSemantics: true`

---

## **A04 — Informative Images Require Labels (Safe Contexts Only)**

**ID:** `flutter_a11y_informative_images_labeled`
**Severity:** WARNING
**Confidence:** High

### Specification

Warn only in **safe, unambiguous patterns**:

1. `CircleAvatar(backgroundImage: ...)`
2. `ListTile.leading` containing `Image` or `CircleAvatar`

### Requirements

* No `semanticLabel`
* No `Semantics(label: ...)`

---

## **A05 — No Redundant Semantics on Material Buttons**

**ID:** `flutter_a11y_no_redundant_semantics_wrappers_on_material_buttons`
**Severity:** WARNING
**Confidence:** High

### Specification

Warn when:

* A `Semantics` wrapper adds **no** new meaningful properties
* And child is a primitive Material button

Examples of bad patterns:

* `Semantics(button: true, child: ElevatedButton(...))`
* `Semantics(child: IconButton(...))` (no label, hint, value)

---

## **A11 — Minimum Tap Target Size (Literal Only)**

**ID:** `flutter_a11y_minimum_tap_target_size`
**Severity:** WARNING
**Confidence:** High

### Specification

Warn when:

* Parent is `SizedBox`, `Container`, `ConstrainedBox`
* Literal width or height < 44
* Child is interactive

No dynamic expressions or theme-dependent inference.

---

## **A16 — Toggle State Via Semantics Flags**

**ID:** `flutter_a11y_toggle_state_via_semantics_flag`
**Severity:** WARNING
**Confidence:** High

### Specification

Warn when:

* Parent `Semantics(label:)` uses literal state words (on/off/checked/etc.)
* Child is a toggle widget (Switch/Checkbox/Radio/ToggleButtons)
* And no `toggled`, `checked`, or `selected` is set

Literal-only.

---

## **A18 — Avoid Hidden Focus Traps**

**ID:** `flutter_a11y_avoid_hidden_focus_traps`
**Severity:** WARNING
**Confidence:** High

### Specification

Warn when:

* Using `Offstage(true)` or `Visibility(false)`
* The subtree contains a **focusable or interactive** widget
* And it is not excluded from semantics

---

## **A21 — Prefer IconButton.tooltip Over Tooltip Wrapper**

**ID:** `flutter_a11y_use_iconbutton_tooltip`
**Severity:** WARNING
**Confidence:** High

### Specification

Warn when:

```dart
Tooltip(
  message: '...',
  child: IconButton(...)
)
```

Instead of:

```dart
IconButton(tooltip: '...')
```

---

## **A22 — Respect ListTile Semantic Boundaries**

**ID:** `flutter_a11y_respect_widget_semantic_boundaries`
**Severity:** WARNING
**Confidence:** High

### Specification

Do not wrap ListTile-family widgets in `MergeSemantics`.

Warn for:

* `MergeSemantics(child: ListTile(...))`
* `MergeSemantics(child: CheckboxListTile(...))`
* `MergeSemantics(child: SwitchListTile(...))`

---

## **A24 — Exclude Drag Handle Icons**

**ID:** `flutter_a11y_exclude_visual_only_indicators`
**Severity:** WARNING
**Confidence:** High

### Specification

Warn when:

* Icon is `Icons.drag_handle` or `Icons.drag_indicator`
* Not inside `ExcludeSemantics`

---

# 4. Expanded Mode Rules (Heuristic, INFO)

Enabled with:

```yaml
flutter_a11y_lints:
  mode: expanded
```

These improve accessibility quality but rely on contextual cues.

---

## 4.1 Labels & Text

---

### **A02 — Avoid Redundant Role Words**

**ID:** `flutter_a11y_avoid_redundant_role_words`
Literal-only.
Warn when tooltip/label contains literal words like “button”, “icon”, “checkbox”, etc.

---

### **A09 — Numeric Values Should Include Units**

**ID:** `flutter_a11y_numeric_values_require_units`
Warn when a static label is composed of digits only.

Example: `"72"` should likely be `"72 bpm"`.

---

### **A17 — Hints Should Describe Operation, Not Meaning**

**ID:** `flutter_a11y_hints_describe_operation`
Warn when hint text duplicates the label or describes meaning/state instead of operation.

---

### **A23 — Contextual Button Labels in Lists**

**ID:** `flutter_a11y_contextual_button_labels`
Warn inside builder methods when trailing buttons have generic literal labels (“Delete”, “Remove”) while an item label literal is present.

---

## 4.2 Structure & Semantics Grouping

---

### **A06 — Merge Multi-Part Single Concept**

**ID:** `flutter_a11y_merge_multi_part_single_concept`
Warn when icon + text represent a single action but appear as separate nodes due to missing `MergeSemantics`.

---

### **A07 — Replace Semantics Cleanly (Use ExcludeSemantics)**

**ID:** `flutter_a11y_replace_semantics_cleanly`
Warn when a custom `Semantics(label: ...)` wraps children still emitting semantics.

---

### **A25 — Use IndexedSemantics for Virtualized Lists**

**ID:** `flutter_a11y_use_indexed_semantics_for_virtualized_lists`
Warn when list items in builder-based lists lack semantic indices.

---

### **A27 — Mark Section Headers Explicitly**

**ID:** `flutter_a11y_mark_section_headers`
Warn when repeated literal section titles appear without `Semantics(header: true)`.

---

## 4.3 Controls & Gestures

---

### **A13 — Single Semantic Role for Composite Controls**

**ID:** `flutter_a11y_single_role_composite_control`
Warn when multiple focusable nodes visually form one interactive control.

---

### **A15 — Mirror Custom Gestures to Semantics Actions**

**ID:** `flutter_a11y_map_custom_gestures_to_on_tap`
Warn when `GestureDetector` exposes tap behavior but no semantic action.

---

## 4.4 Validation & Feedback

---

### **A14 — Validation Feedback Accessible**

**ID:** `flutter_a11y_validation_feedback_accessible`
Warn when visible error text is not exposed to screen readers (missing `errorText`, not tied to the field).

---

## 4.5 Dynamic Behaviors

---

### **A08 — BlockSemantics Only for True Modals**

**ID:** `flutter_a11y_block_semantics_only_for_true_modals`
Warn when BlockSemantics is used for non-modal/non-blocking UI.

---

### **A10 — Debounce Live Announcements**

**ID:** `flutter_a11y_debounce_live_announcements`
Warn when announcing too frequently (e.g., inside animation builders).

---

### **A20 — Announce Async Completion Once**

**ID:** `flutter_a11y_announce_async_completion_once`
Warn for duplicated success announcements within the same scope.

---

### **A26 — Avoid Per-Frame Semantics Updates**

**ID:** `flutter_a11y_avoid_per_frame_semantics_updates`
Warn when semantics values update in animation frames without throttling.

---

# 5. Advisory Rules (Opt-In)

Disabled by default. Only for strict teams.

---

### **A12 — Focus Order Should Match Visual Order**

**ID:** `flutter_a11y_focus_order_matches_visual_order`
Warn when custom sort keys appear significantly out of order.

---

### **A19 — Disabled State Labeling Should Not Be Redundant**

**ID:** `flutter_a11y_reason_for_disabled_optional`
Warn when developers manually include the word “disabled” in labels.

---

# 6. Linter Implementation Guidelines

### 6.1 Always Follow These

* Start rule with `if (!fileUsesFlutter(unit)) return;`
* Skip generated files:
  `*.g.dart`, `*.freezed.dart`, `*.gen.dart`, `/generated/`
* Never infer layout, size, or theme
* Never inspect i18n expressions
* Only use literal string analysis
* Only analyze **within a single file**
* Provide inline ignore support:

```dart
// ignore: flutter_a11y_rule_name
```

* Keep `WARNING` rules extremely conservative
* Keep heuristic rules `INFO`
* Ensure fast execution across monorepos

---

# 7. Developer Guidance (For Flutter App Authors)

* Fix all **WARNING** issues first
* Then enable **expanded** mode for deeper improvements
* Test with TalkBack/VoiceOver after major refactors
* Use inline ignores only when intentional
* For design systems, consider adding rule overrides (planned feature)

---

# 8. Versioning & Future Enhancements

* v1.1: Desktop/Web-specific rules
* v1.2: Rule configuration per-widget
* v2.0: Optional “semantic simulation mode” (runtime semantic tree validation)

---

# 9. Summary

This document defines:

* The **complete rule set A01–A27**
* Their **grouping by mode & confidence**
* Their **Static Semantic IR-based specification**
* Developer-friendly and contributor-friendly guidance
* Strict constraints ensuring **low false positives** and **high trust**
