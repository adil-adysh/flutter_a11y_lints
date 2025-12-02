# 📘 flutter_a11y_lints — Complete System Design Document (v1.0)

Architecture, Rule Specification, Heuristic Engine, Implementation Guide, and Developer Framework

**Audience:**
Developers, coding agents, contributors building rules for the `flutter_a11y_lints` project.

**Purpose:**
Provide one clear, unified, comprehensive technical design that defines:

* The purpose and philosophy of the plugin
* High-confidence rule specifications
* Heuristic rule engine design
* Compiler-style architecture
* Configuration system
* Testing strategy
* False-positive control
* Contribution workflow

Everything needed to implement, extend, and maintain a robust accessibility linter for Flutter.

---

## Table of Contents

1. Project Purpose
2. Core A11y Principles
3. High-Confidence Rule Set (Strict/WARNING)
4. Heuristic Rule Set (INFO / Expanded mode)
5. Real-World Challenges & Why a Compiler-Style Design
6. System Architecture Overview
7. AST Frontend Layer
8. Configuration Layer
9. Heuristic Engine (Compiler Middle-End)
10. Diagnostics Policy Layer (Severity / Modes)
11. Testing Architecture & Regression System
12. False-Positive Control Model
13. Rule Development Guidelines
14. Project Folder Structure
15. Workflow for Adding New Rules
16. Long-Term Evolution & Maintenance Loop
17. Appendix: Example Heuristic Implementation (A06)

---

## 1. Project Purpose

`flutter_a11y_lints` is a Flutter accessibility linter designed to:

* Detect common a11y issues at development time
* Enforce semantic correctness
* Reduce obstacles for screen reader users
* Provide best-practice patterns
* Offer both strict rules and optional heuristic guidance
* Maintain extremely low false positives

This project treats accessibility linting with the seriousness of a **compiler**, not a loose pattern matcher.

---

## 2. Core A11y Principles the Linter Enforces

Aligned with WCAG + Flutter semantics:

* **Perceivable**: Every meaningful UI element must be exposed to assistive tech.
* **Operable**: Interactive elements must have proper focus/activation semantics.
* **Understandable**: Labels must be non-redundant, contextual, clear.
* **Robust**: Prefer built-in semantics; avoid duplication, override only intentionally.

---

## 3. High-Confidence Rules (Strict / WARNING)

These rules are safe, deterministic, low false-positive, and enabled by default.

These rules rely **only on AST structure**, never heuristics.

| Rule ID | Description                                                          |
| ------- | -------------------------------------------------------------------- |
| **A01** | Label non-text controls (`IconButton` without tooltip)               |
| **A03** | Decorative images must use `excludeFromSemantics: true`              |
| **A04** | Informative images must have `semanticLabel` (avatars, product images) |
| **A05** | No redundant `Semantics` wrappers on Material buttons                 |
| **A11** | Minimum tap target size (< 44/48 literal values only)                |
| **A16** | Toggle state must use semantic flags, not label text                 |
| **A18** | Hidden focus traps (`Offstage`/`Visibility` with focusable children) |
| **A21** | Use `IconButton.tooltip` instead of `Tooltip` wrapper                |
| **A22** | Don’t wrap `ListTile` family in `MergeSemantics`                     |
| **A24** | Exclude drag-handle icons from semantics                            |

These form the **core conservative mode**.

---

## 4. Heuristic Rule Set (INFO / Expanded Mode)

Rules requiring multiple signals, contextual logic, or partial inference.

* **A02** — Redundant role words
* **A06** — Merge multi-part control (Icon + Text button)
* **A07** — Replace semantics cleanly (`ExcludeSemantics`)
* **A09** — Numeric values should include units
* **A10 / A20** — Prevent announcement spam
* **A12** — Focus order heuristics
* **A13** — One role per control
* **A23** — Contextual button labels in lists

Heuristic rules:

* Enabled only in `expanded` mode
* Severity = INFO
* Opt-in per rule
* Must use the heuristic engine described below
* Must support negative filters and confidence scoring

---

## 5. Real-World Challenges & Why a Compiler-Style Design

The system must handle:

* Custom design systems wrapping buttons, tiles, and images
* Localization systems (labels are often non-literal)
* Generated code (`*.g.dart`, `*.freezed.dart`)
* Large monorepos
* Builder patterns (`itemBuilder`)
* Runtime context we cannot see (layout, constraints, semantics merging)
* Avoiding false positives at all cost
* Long-term maintainability

Therefore:
**A simple collection of ad-hoc rules is insufficient → Compiler-like architecture is appropriate.**

---

## 6. System Architecture Overview

The architecture has **four layers**:

1. **Frontend (AST parsing)**
2. **Config Layer (ignore paths, safe components, modes)**
3. **Heuristic Engine (signals, guards, scoring)**
4. **Diagnostics Policy Layer (severity, rule enabling)**

Supported by:

* **Comprehensive test suite**
* **Regression feedback loop**

This ensures consistency, predictability, and low false positives.

---

## 7. AST Frontend Layer

This layer reads Dart code and exposes structured node information.

### Responsibilities

* Determine if a file uses Flutter
* Quickly ignore generated files and ignored paths
* Provide helpers to inspect:
  * Widget classes
  * Named arguments
  * Literal values
  * Parent/child relationships
  * Interactivity (`onTap`, `onPressed`, etc.)
  * Builder contexts (`ListView.builder`, `GridView.builder`)
  * `Semantics` wrappers

### Core Utility `NodeQueries`

Example API:

```dart
bool isWidget(node, 'IconButton');
bool hasNamedArg(node, 'tooltip');
Expression? getNamedArg(node, 'tooltip');
bool isLiteralString(expr);
String? getLiteralString(expr);
bool hasInteractiveCallback(node);
T? nearestAncestorOfType<T>(node);
List<Widget> getDirectWidgetChildren(node);
```

All rules use this instead of raw analyzer logic.

---

## 8. Configuration Layer

Loaded from `analysis_options.yaml`:

```yaml
flutter_a11y_lints:
  mode: expanded
  ignore_rules:
    - flutter_a11y_contextual_button_labels
  ignore_paths:
    - lib/generated/**
  additional_button_classes:
    - AppButton
  safe_components:
    - AppListTileWithSemantics
```

Provides:

* Conservative/expanded mode
* Per-rule enable/disable
* Additional safe widgets
* Project-specific design system awareness
* Ignore paths (DSLs, codegen, 3rd-party)

### Function `shouldIgnoreFile`

Checks:

* Config ignore paths
* Generated file patterns
* `// ignore_for_file:` directives

---

## 9. Heuristic Engine (Compiler Middle-End)

This is the heart of heuristic accuracy.

### Core Concepts

#### Signal

A boolean fact about a node. Examples:

* `parentIsInteractive`
* `hasIconAndTextChildren`
* `usesSameCallback`
* `tooltipIsLiteral`
* `insideBuilderContext`
* `hasSemanticsOverride`

#### Guards

Negative conditions that suppress warnings:

* Inside safe component
* Label is localized (don’t inspect raw text)
* Already has `MergeSemantics`
* Complex layout (`Expanded`/`Flexible`)
* Multiple independent actions

#### Confidence Score

An integer count of positive signals.

#### Decision

```dart
class HeuristicDecision {
  final bool shouldReport;
  final int confidence;
}
```

### Evaluation Pipeline

Example (A06):

1. Compute signals
2. Apply negative guards
3. Count confidence
4. If score ≥ threshold → emit INFO

This prevents noisy heuristics.

---

## 10. Diagnostics Policy Layer (Severity & Modes)

### Severity Rules

| Type            | Severity | Enabled In              |
| --------------- | -------- | ----------------------- |
| High-confidence | WARNING  | conservative & expanded |
| Heuristic       | INFO     | expanded only           |
| Advisory        | INFO/OFF | optional                |

### Modes

```yaml
flutter_a11y_lints:
  mode: conservative  # default  
  mode: expanded      # enables heuristics
```

### Per-rule severity override

```yaml
rule_severity_overrides:
  flutter_a11y_contextual_button_labels: warning
```

---

## 11. Testing Architecture & Regression System

### Each rule must have

* **Positive tests** (violations)
* **Negative tests** (correct patterns)
* **Regression tests** for every false positive reported by users

### Structure

```text
test/rules/
  a06_merge_multi_part_test.dart
  a23_contextual_button_labels_test.dart
```

### Regression workflow

1. User reports FP
2. Add minimal repro to tests
3. Ensure lint does *not* fire
4. Adjust heuristic logic
5. Re-run full suite
6. Commit fix

This makes the system self-healing over time.

---

## 12. False-Positive Control Model

To maintain developer trust:

1. **Use literal-only heuristics when possible**
2. **Avoid interpreting localization keys**
3. **Never infer layout**
4. **Never assume custom widgets are incorrect**
5. **Use multi-signal detection**
6. **Allow per-rule suppression**
7. **Offer config for safe components & ignore paths**
8. **Make heuristic rules INFO**
9. **Skip generated code**

The philosophy: **Better to skip a warning than create a false one.**

---

## 13. Rule Development Guidelines

Every rule must clearly define:

* Problem description
* Rationale
* AST patterns required
* Explicit false-positive risk
* Example violation
* Example correct pattern
* Detection logic
* Negative guards
* Test cases

Template:

```markdown
### AXX — Rule Name
Severity: WARNING / INFO
Confidence: High / Heuristic
Description: ...
Rationale: ...
Detects: ...
Does NOT detect: ...
Violation Example: ...
Correct Example: ...
False-Positive Considerations: ...
```

---

## 14. Project Folder Structure

```text
lib/
  src/
    plugin.dart
    rules/
      a01_label_non_text_controls.dart
      ...
      a24_exclude_visual_only_indicators.dart
    utils/
      ast.dart
      flutter_detection.dart
      material_widget_utils.dart
      widget_tree.dart
      text_analysis.dart
      config_loader.dart
      ignore_patterns.dart
    config/defaults.yaml
    types/rule_mode.dart

test/
  rules/
    a01_test.dart
    a06_test.dart
    a23_test.dart
  test_utils.dart
```

---

## 15. Workflow for Adding New Rules

1. Identify the issue (WCAG reference if possible)
2. Decide if high-confidence or heuristic
3. Create rule file
4. Implement AST logic (or heuristic signals)
5. Add docs
6. Write:
   * positive tests
   * negative tests
   * regression tests
7. Register rule in `plugin.dart`
8. Add demo code in example project
9. Validate performance

---

## 16. Long-Term Evolution & Maintenance Loop

1. Collect real-world feedback
2. Refine signals/guards
3. Add regression tests
4. Release patch versions
5. Add new heuristic rules in minor versions
6. Break compatibility only in major versions

This mirrors compiler evolution (Rust, Clang, TypeScript).

---

## 17. Appendix: Example Heuristic Implementation (A06)

### Positive Signals

* Parent is interactive
* Child is `Row`/`Column`
* Children = Icon + Text
* Same callback used

### Guard Conditions

* `Semantics`/`MergeSemantics` present
* Complex layout
* Multiple independent actions

### Confidence Logic

```dart
score = 0;
if (signals.parentIsInteractive) score++;
if (signals.hasIconAndTextChildren) score++;
if (signals.usesSameCallback) score++;

if (score >= 3 && !signals.hasSemanticsOverride) {
  lint();
}
```

### Severity

INFO (heuristic, expanded mode only)
