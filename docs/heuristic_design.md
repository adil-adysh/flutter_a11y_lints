# 📕 Heuristic Design for `flutter_a11y_lints`

Signal-based, compiler-style detection for “soft” accessibility rules

**Goal:**
Define exactly how heuristic rules (non-guaranteed, context-dependent checks) must be implemented so they are:

* AST-based (compiler-like)
* Low noise (few false positives)
* Configurable
* Easy to test and refine

This builds on the “greater accuracy” principles and turns them into a concrete implementation guide.

---

## 1. Heuristic Rules: When and Why

Heuristic rules address accessibility concerns you cannot prove statically with 100% certainty but that are still valuable to flag as “likely problems.” Examples include:

* **A06** — Composite control (Icon + Text) should be a single semantic node
* **A07** — Custom Semantics label should exclude children
* **A09** — Numeric value missing units
* **A10 / A20** — `SemanticsService.announce` spam prevention
* **A13** — Two buttons that represent one action
* **A23** — Contextual list buttons should name the item

These rules behave like contextual hints, not rigid compiler errors.

---

## 2. Heuristic Pipeline Overview

Each heuristic rule follows a small “compiler pass”:

1. **AST Selection** – Identify candidate nodes (widgets, builder scopes, method invocations)
2. **Signal Extraction** – Compute boolean facts about those nodes
3. **Guard Checks** – Apply negative filters that cancel warnings
4. **Confidence Scoring** – Combine signals into a score
5. **Decision** – Emit a lint when INFO thresholds are exceeded
6. **Testing & Feedback** – Refine based on unit tests and real-world reports

---

## 3. AST Selection

Heuristics always start from a clear AST anchor:

* A concrete widget type (`IconButton`, `Row`, `Semantics`)
* A builder pattern (`ListView.builder`, `GridView.builder`)
* A specific API (`SemanticsService.announce`)

Example A23 selection:

* Anchor on `InstanceCreationExpression` of `IconButton`
* Filter to builders such as `ListView.builder` or `GridView.builder`

This keeps the heuristic focused rather than global.

---

## 4. Signal Extraction

A **Signal** is a simple boolean fact derived from the AST. Each rule defines its own signal set. A23 might compute:

* `insideBuilderContext` – IconButton lives inside a builder closure
* `hasItemVariable` – Viewer code declares `final item = items[index];`
* `hasItemTitleText` – Nearby `Text(item.title)` exists
* `tooltipIsLiteral` – `tooltip: 'Delete'` uses a string literal
* `hasGenericTooltip` – Literal is “Delete”, “Edit”, “More”, etc.
* `hasSemanticsOverride` – IconButton already wrapped with `Semantics(label: ...)`

Signals never inspect runtime layout or guess beyond the AST and literal values.

---

## 5. Guard Checks (Negative Filters)

Guards cancel a warning even when some signals look suspicious. A23 guards include:

* Tooltip sources localization (`context.l10n.*`, `S.of(context)`) → skip
* Semantics wrapper already provides the label → skip
* The IconButton is inside a trusted `safe_component` from config → skip

Guards keep noise low and protect custom patterns.

---

## 6. Confidence Scoring

After signals and guards, accumulate a simple score:

```dart
var score = 0;
if (signals.insideBuilderContext) score++;
if (signals.hasItemVariable) score++;
if (signals.hasItemTitleText) score++;
if (signals.tooltipIsLiteral) score++;
if (signals.hasGenericTooltip) score++;

if (score >= 4 && !signals.hasSemanticsOverride) {
  // emit INFO lint
}
```

Rule authors can adjust thresholds per rule to tighten or loosen the heuristic without rewriting the structure.

---

## 7. Decision Object

Wrap outcomes in a small struct:

```dart
class HeuristicDecision {
  final bool shouldReport;
  final int confidence;

  const HeuristicDecision(this.shouldReport, this.confidence);

  factory HeuristicDecision.lint([int confidence = 3]) =>
      HeuristicDecision(true, confidence);

  factory HeuristicDecision.noLint() =>
      const HeuristicDecision(false, 0);
}
```

Every heuristic visitor does:

```dart
final decision = heuristicEngine.evaluateA23(node, queries, config);
if (decision.shouldReport) {
  reporter.atNode(node).report(_code);
}
```

---

## 8. Mapping the “Greater Accuracy” Principles

1. **AST only** – Signals rely on analyzer node kinds, named arguments, and literals. No layout inference or broad string scanning.
2. **Extensive tests** – Positive, negative, and regression suites capture intended behavior and fix future false positives.
3. **Config awareness** – Respect `ignore_paths`, `ignore_rules`, `safe_components`, and `additional_button_classes` before evaluating signals.
4. **Multiple signals** – Require several facts (parent interactivity, callbacks, child structure) before reporting.
5. **INFO severity** – Heuristics default to `ErrorSeverity.INFO`, activate in `mode: expanded`, and remain optional.
6. **Feedback-driven iteration** – Add failing cases as regression tests, adjust guards/thresholds, rerun suite, release patch.

---

## 9. Example Flow: A06 — Merge Multi-Part Control

### AST Selection (A06 flow)

* Anchor on `InstanceCreationExpression` for `Row`/`Column`
* Only when parent is interactive (`InkWell`, `GestureDetector`, `TextButton`)

### Signals (A06 flow)

* `parentIsInteractive`
* `hasExactlyIconAndTextChildren`
* `usesSameCallback`
* `hasSemanticsAncestor`
* `isInSafeComponent`

### Guards (A06 flow)

* Skip if `hasSemanticsAncestor`
* Skip if `isInSafeComponent`
* Skip when more than two semantic children

### Scoring (A06 flow)

```dart
var score = 0;
if (signals.parentIsInteractive) score++;
if (signals.hasExactlyIconAndTextChildren) score++;
if (signals.usesSameCallback) score++;

if (score >= 3 && !signals.hasSemanticsAncestor && !signals.isInSafeComponent) {
  reporter.atNode(node).report(_code);
}
```


---

## 10. Example Flow: A23 — Contextual Button Labels

### AST Selection (A23 flow)

* IconButton inside builder/Sliver delegate

### Signals (A23 flow)

* `insideBuilderContext`
* `hasItemVariable`
* `hasItemTitleText`
* `tooltipIsLiteral`
* `hasGenericTooltip`
* `hasSemanticsOverride`

### Guards (A23 flow)

* Tooltip is localized → skip
* Semantics override present → skip
* IconButton sits in `safe_component` → skip

### Scoring (A23 flow)

```dart
var score = 0;
if (insideBuilderContext) score++;
if (hasItemVariable) score++;
if (hasItemTitleText) score++;
if (tooltipIsLiteral) score++;
if (hasGenericTooltip) score++;

if (score >= 4 && !hasSemanticsOverride && !isInSafeComponent) {
  reporter.atNode(node).report(_code);
}
```

---

## 11. Takeaways for Developers and Coding Agents

When authoring any heuristic rule:

1. Anchor on a precise AST node.
2. Define 5–10 simple signals.
3. Define guards that cancel warnings.
4. Evaluate a confidence threshold instead of a single `if`.
5. Respect config (`ignore_paths`, `safe_components`, `ignore_rules`).
6. Keep severity as INFO and limit to `mode: expanded`.
7. Provide positive, negative, and regression tests.

Doing so keeps heuristics predictable, tunable, and increasingly accurate over time.
