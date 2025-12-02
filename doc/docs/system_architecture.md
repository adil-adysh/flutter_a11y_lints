# System Architecture for `flutter_a11y_lints`

Plugin Structure, Rule Loading, Utilities, Configuration, and Testing Architecture

**Version:** 1.0
**Purpose:** Provide coding agents with a clear blueprint of the entire linter’s architecture, how rules are structured, how they interact with analysis context, and how to scale the plugin as rules grow.

---

## 1. High-Level Architecture Overview

`flutter_a11y_lints` is a **custom_lint** plugin that provides a suite of accessibility-focused lint rules for Flutter applications.

It follows a **modular, rule-based architecture**, where each lint rule is:

* a separate Dart file,
* a separate class,
* independently testable,
* registered centrally in `plugin.dart`.

The architecture emphasizes:

* **consistency**
* **extensibility**
* **performance**
* **low false positives**
* **config-driven behavior**

This document describes:

* File structure
* Rule registration flow
* Shared utilities
* Config system
* Rule categories
* Testing framework
* Performance guidelines

---

## 2. Folder & File Structure

A typical project layout:

```text
lib/
 └─ src/
     ├─ plugin.dart
     ├─ rules/
     │    ├─ a01_label_non_text_controls.dart
     │    ├─ a03_decorative_images_excluded.dart
     │    ├─ a04_informative_images_labeled.dart
     │    │    ├─ a05_no_redundant_semantics_on_material_buttons.dart
     │    │    ├─ a11_minimum_tap_target_size.dart
     │    │    ├─ a16_toggle_state_via_semantics.dart
     │    │    ├─ a18_avoid_hidden_focus_traps.dart
     │    │    ├─ a21_use_iconbutton_tooltip.dart
     │    │    ├─ a22_respect_widget_semantic_boundaries.dart
     │    │    ├─ a24_exclude_drag_handle_indicators.dart
     │    │    └─ ... (heuristic rules added later)
     │
     ├─ utils/
     │    ├─ ast.dart
     │    ├─ flutter_detection.dart
     │    ├─ material_widget_utils.dart
     │    ├─ widget_tree.dart
     │    ├─ text_analysis.dart
     │    ├─ config_loader.dart
     │    └─ ignore_patterns.dart
     │
     ├─ config/
     │    └─ defaults.yaml (optional: built-in defaults)
     │
     └─ types/
          └─ rule_mode.dart
```

This structure allows for:

* Clean boundaries
* Reusable utilities
* Fast rule lookup
* Independent tests

---

## 3. Plugin Entry Point (`plugin.dart`)

This file registers all lint rules.

Example:

```dart
typedef LintRuleFactory = LintRule Function();

class FlutterA11yPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) {
    final mode = loadRuleMode(configs);

    final rules = <LintRule>[
      const A01LabelNonTextControls(),
      const A03DecorativeImagesExcluded(),
      const A04InformativeImagesLabeled(),
      const A05NoRedundantButtonSemantics(),
      const A11MinimumTapTargetSize(),
      const A16ToggleStateViaSemantics(),
      const A18AvoidHiddenFocusTraps(),
      const A21UseIconButtonTooltip(),
      const A22RespectWidgetSemanticBoundaries(),
      const A24ExcludeDragHandleIndicators(),
    ];

    if (mode == RuleMode.expanded) {
      rules.addAll([
        // A06–A09, A10–A20, A23 etc.
        // heuristic and INFO-level rules
      ]);
    }

    return rules;
  }
}
```

### Key Architectural Principles

* **Rules are stateless singletons** (no field mutations).
* **Separated by confidence** (high vs heuristic).
* **Config-driven expansion** allows enabling/disabling groups.

---

## 4. Rule Structure

Each rule is a separate class file:

```dart
class A01LabelNonTextControls extends DartLintRule {
  const A01LabelNonTextControls() : super(code: _code);

  static const _code = LintCode(
    name: 'flutter_a11y_label_non_text_controls',
    problemMessage: 'Interactive IconButton widgets must have an accessible label.',
    correctionMessage: 'Provide a tooltip: property or wrap with a Semantics(label: ...).',
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void run(CustomLintResolver resolver, ErrorReporter reporter, CustomLintContext context) {
    context.addPostRunCallback(() async {
      final unit = (await resolver.getResolvedUnitResult()).unit;

      if (!fileUsesFlutter(unit)) return;
      if (shouldIgnoreFile(resolver)) return;

      context.registry.addInstanceCreationExpression((node) {
        if (!isIconButton(node)) return;
        if (!iconButtonIsInteractive(node)) return;
        if (iconButtonHasTooltip(node)) return;
        if (wrappedInSemanticsWithLabel(node)) return;

        reporter.atNode(node).report(_code);
      });
    });
  }
}
```

### Every rule MUST

1. Check `fileUsesFlutter(unit)`
2. Skip generated files (`*.g.dart`, `*.freezed.dart`, etc.)
3. Only install visitors necessary for rule logic
4. Use helper utilities (never reimplement common AST checks)

---

## 5. Shared Utility Modules

### utils/flutter_detection.dart

* `bool fileUsesFlutter(CompilationUnit unit)`
* Detects imports of:
  * `package:flutter/material.dart`
  * `package:flutter/widgets.dart`
  * `package:flutter/cupertino.dart`

### utils/ast.dart

Provides:

* `bool isIconButton(node)`
* `bool isMaterialButton(node)`
* `bool isImageAsset(node)`
* `bool isSemanticsWrapper(node)`
* Parent/sibling traversal helpers

### utils/material_widget_utils.dart

* Recognizes known Material widgets:
  * IconButton
  * TextButton
  * FilledButton
  * ElevatedButton
  * OutlinedButton
  * FloatingActionButton
* Identifies interactive patterns:
  * `onPressed`, `onTap`, `onLongPress`, etc.

### utils/widget_tree.dart

* Locate ancestors:
  * `findNearestAncestor<T>(node)`
  * `isWrappedIn<T>()`
* Used to detect `Semantics`, `Tooltip`, `MergeSemantics`, etc.

### utils/text_analysis.dart

* For heuristic rules:
  * Strip punctuation
  * Normalize whitespace
  * Tokenize text
  * Substring fuzzy matching
  * Literal-only safe mode

### utils/config_loader.dart

Loads configs from `analysis_options.yaml`:

```yaml
flutter_a11y_lints:
  mode: conservative # or expanded
  ignore_rules:
    - flutter_a11y_contextual_button_labels
  ignore_paths:
    - lib/generated/**
    - lib/**/*.g.dart
```

### utils/ignore_patterns.dart

* Centralized logic for skipping:
  * generated files
  * versioned artifacts
  * user-defined ignore paths

---

## 6. Rule Categories

Rules are grouped into two categories:

---

## A. High-Confidence Rules (Conservative Mode)

These rules are safe as WARNING in all apps.

* A01 — Label Non-Text Controls
* A03 — Decorative Images Excluded
* A04 — Informative Images Labeled
* A05 — No Redundant Semantics on Material Buttons
* A11 — Minimum Tap Target Size (literal only)
* A16 — Toggle State via Semantics Flag
* A18 — Hidden Focus Traps (strict mode)
* A21 — Tooltip on IconButton Only
* A22 — No MergeSemantics on ListTile Family
* A24 — Exclude Drag Handle Icons

---

## B. Heuristic Rules (Expanded Mode)

Enable only when user opts in.

* A02 — Avoid Redundant Role Words
* A06 — Merge Multi-Part Single Concept
* A07 — Replace Semantics Cleanly
* A09 — Units in Numeric Values
* A10 — Debounce Live Announcements
* A12 — Visual vs Focus Order
* A13 — Single Interactive Role
* A14 — Validation Feedback Accessible
* A15 — Custom Gesture Semantics
* A17 — Hint Describes Operation
* A19 — Disabled State Reason
* A20 — Async Announce Once
* A23 — Contextual Button Labels
* A24 (extended) — More decorative indicators

Each heuristic rule is marked INFO by default.

---

## 7. Configuration System

### `analysis_options.yaml` example

```yaml
flutter_a11y_lints:
  mode: conservative
  ignore_rules:
    - flutter_a11y_contextual_button_labels
  ignore_paths:
    - lib/generated/**
  additional_button_classes:
    - CupertinoButton
    - AppPrimaryButton
```

### Config Options

| Key                         | Description                       |
| --------------------------- | --------------------------------- |
| `mode`                      | `conservative` or `expanded`      |
| `ignore_rules`              | List of rule names to skip        |
| `ignore_paths`              | Globs for skipping files          |
| `additional_button_classes` | Custom widgets treated as buttons |
| `additional_image_classes`  | Custom widgets treated as images  |
| `safe_components`           | Semantics-safe wrappers           |

---

## 8. Rule Execution Lifecycle

For each file analyzed:

1. **Fast checks**

   * Is file generated? → skip
   * Does file import Flutter? → skip if no

2. **AST resolved**

   * `getResolvedUnitResult` called exactly once per rule

3. **Visitors registered**

   * Each rule registers only the needed visitors:

     * `addInstanceCreationExpression`
     * `addMethodInvocation`
     * `addPrefixedIdentifier`, etc.

4. **Rule execution**

   * Visitors inspect node shapes
   * Utility functions evaluate conditions
   * On violation → reporter emits diagnostic

5. **Completion**

   * No state persisted between files
   * No cross-file analysis

---

## 9. Testing Architecture

### Folder

```text
test/
 ├─ rules/
 │    ├─ a01_label_non_text_controls_test.dart
 │    ├─ a03_decorative_images_excluded_test.dart
 │    ├─ a04_informative_images_labeled_test.dart
 │    └─ ...
 └─ test_utils.dart
```

### Testing Strategy

* Use custom_lint test runner
* Each rule test covers:
  * Positive cases (must warn)
  * Negative cases (must NOT warn)
  * Edge cases (custom widgets, localization, wrappers)
* Snapshot tests for rule outputs

### Test Philosophy

* Zero false positives in tests.
* Heuristic rules require:
  * fewer strict assertions
  * more “should not warn” tests

---

## 10. Performance Guidelines

### Rule implementers must

* Avoid whole-file AST scans when possible.
* Never use expensive nested loops.
* Use `return` early.
* Avoid analyzing large expression trees unnecessarily.
* Cache imports or widget types only within a single run callback.

### Plugin performance goal

* **< 30ms per file** for high-confidence rules
* Additional < 20ms overhead in expanded mode

---

## 11. Extensibility Strategy

### Adding a new rule

1. Create file in `lib/src/rules`
2. Follow rule template
3. Use correct naming conventions: `aXX_rule_name.dart`, class: `AXXRuleName`
4. Add to plugin registry
5. Add tests
6. Add documentation (Document 1/4 sections)

### Maintaining backward compatibility

* Strict rules must remain strict
* Heuristic rules must stay INFO by default
* Breaking changes require major version bump

---

## 12. Summary

This document defines the entire architecture of `flutter_a11y_lints`, including:

* Plugin entry point
* Rule loader
* Rule structure
* Utility libraries
* Configuration system
* Category separation
* Testing structure
* Performance expectations

Together with Document 1 (high-confidence rules) and Document 2 (constraints/real-world challenges), this forms the foundational spec for implementation.
