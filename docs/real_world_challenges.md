# Real-World Challenges & Constraints When Implementing Flutter Accessibility Lints

## flutter_a11y_lints — Design Considerations for Reliable Rule Implementation

**Version:** 1.0  
**Purpose:** Prepare the coding agent for practical difficulties when applying accessibility lint rules in real-world Flutter applications. Focus: correctness, false-positive prevention, and robustness in diverse app architectures.

---

## 1. Introduction

Accessibility linting is fundamentally different from typical code-style linting. It attempts to reason about **user experience** and **semantics** through **static analysis** of Dart code.

That means:

* You will frequently see **patterns that look incorrect**, but the actual semantics exist somewhere else (e.g., inside a design system).
* You cannot rely on **runtime values**, **localization**, **layout**, or **context**.
* Many “patterns” in accessibility can only be partially inferred.

The challenge is to provide **helpful**, **predictable**, and **low-noise** lints that developers trust.

This document enumerates the real-world constraints and pitfalls that the coding agent must consider when implementing rules.

---

## 2. Category 1 — Abstraction Layers in Real Apps

Real production Flutter apps rarely use bare Flutter widgets. Instead, everything is wrapped in custom layers.

### ✔ Custom Button Widgets

```dart
class AppIconButton extends StatelessWidget { ... }
class PrimaryButton extends StatelessWidget { ... }
```

### ✔ Custom Image / Avatar Widgets

```dart
class UserAvatar extends StatelessWidget { ... }
```

### ✔ Custom Semantics Wrappers

```dart
class A11y extends StatelessWidget { ... }
```

### ✔ Design Systems / Component Libraries

Most large companies define component families such as:

```text
AppButton
AppCard
AppListTile
AppAvatar
AppTooltip
```

### ✔ Effects on Linting

* The *apparent* violation is often false — semantics may be added inside the custom widget.
* The linter must not assume low-level semantics are missing simply because they are not present locally.

### ✔ Solution Guidelines (Abstraction Layers)

* High-confidence rules only inspect **primitive widgets directly** (`IconButton`, `Image.asset`, `ListTile`, etc.).
* Avoid inferring intent for custom widgets unless explicitly configured.

---

## 3. Category 2 — Localization & Dynamic Text

In most real apps, text is not literal.

```dart
tooltip: context.l10n.save;
label: S.of(context).deleteItem(item.name);
tooltip: tr('buttons.delete');
```

### ✔ Why this breaks naive rules

* You cannot search text for keywords like “button”, “selected”, “off”, etc.
* You cannot infer whether a label is contextual if the language pack supplies context behind the scenes.
* You cannot compare label/hint similarity when both are localization keys.

### ✔ Solution Guidelines (Localization)

* For any rule requiring text analysis:
  * Only run checks on **literal strings** (safe).
  * If the value is an expression → treat as *unknown*, not a violation.
* Heuristic text-matching rules (A02, A16, A23) should degrade gracefully when localization is used.

---

## 4. Category 3 — Layout & Responsiveness

Flutter UI layout depends heavily on:

* constraints passed by parent widgets,
* responsive breakpoints,
* `MediaQuery`,
* `LayoutBuilder`,
* custom render objects.

Static analysis **cannot** determine:

* actual rendered size,
* pixel scaling,
* device orientation,
* text size scaling,
* RTL vs LTR layout effects.

### ✔ Example — Tap target rule

Size might be clamped or padded by ancestors you can’t inspect.

```dart
Row(
  children: [
    IconButton(
      icon: Icon(Icons.close),
      onPressed: () {},
    ),
  ],
)
```

You **cannot** assume that this is < 48dp; it might be inside:

```dart
ButtonTheme(minWidth: 48, height: 48)
```

### ✔ Solution Guidelines (Layout)

* Only warn when explicit **literal sizes** are provided (44 or lower).
* Never attempt layout inference through nested containers or sizing expressions.

---

## 5. Category 4 — Builders, Lists & Multi-File Semantics

Most actionable UI happens inside builders such as `ListView.builder`, `GridView.builder`, or `SliverList`.

```text
ListView.builder
GridView.builder
SliverList
```

Many important elements are split across files.

```text
ListView.builder → ItemTile Widget → Button inside tile
```

### ✔ Challenge — Contextual relationships broken across files

You cannot reliably detect:

* Which text belongs to which button,
* Which item a button refers to,
* Which part of a builder's output the developer wants to expose as semantics.

### ✔ Solution Guidelines (Builders & Context)

* High-confidence rules must analyze **within a single file**.
* For contextual rules:
  * Only apply when *all relevant nodes appear within the same build method*.
  * Otherwise, do not warn.

---

## 6. Category 5 — Generated Code

Flutter projects frequently include:

* `*.g.dart`
* `*.freezed.dart`
* `*.gr.dart` (go_router)
* `*.gen.dart`
* Versioned build artifacts

### ✔ Linting auto-generated code creates noise

Developers do NOT want warnings in generated files. It trains them to distrust the linter.

### ✔ Solution Guidelines (Generated Code)

* Always skip files matching common patterns:
  * `**/*.g.dart`
  * `**/*.freezed.dart`
  * `**/generated/**`
  * `**/*.gen.dart`
* Provide config to extend ignored patterns.

---

## 7. Category 6 — Performance on Large Codebases

Real companies have:

* Monorepos with 100+ packages
* CI pipelines with strict performance limits
* Thousands of Flutter files

### ✔ Performance Challenges

* Lints that scan entire files deeply can be expensive.
* Calling `getResolvedUnitResult()` on every rule is costly.

### ✔ Required Practices

* Every rule must start with `fileUsesFlutter(unit)` to skip non-Flutter files.
* Only register visitors needed for that rule.
* Avoid O(n²) scans (e.g., looking through every node for “announce” duplicates).
* Implement early exit strategies, for example:
  * As soon as a violation is found for a node → do not continue deeper.

---

## 8. Category 7 — Multiple UI Frameworks

Apps may combine Material, Cupertino, FluentUI, and third-party kits.

### ✔ Example (Cupertino button)

```dart
CupertinoButton(
  child: Icon(CupertinoIcons.add),
)
```

Your rules about Material button semantics may not apply.

### ✔ Solution Guidelines (Frameworks)

* Rules must identify widget by class name:
  * IconButton → Material
  * CupertinoButton → Cupertino
* Do not assume semantics for frameworks you do not explicitly support.
* Allow extending framework support in the config.

---

## 9. Category 8 — Intentional Deviations

Developers sometimes intentionally break patterns:

* A drag handle icon *does* have meaning in a specific domain.
* A toggle label *needs* to say "Airplane mode ON" due to safety context.
* A decorative image is deliberately used as a semantic value in a game UI.

### ✔ Solution Guidelines (Intentional Deviations)

* Always provide a one-line “ignore” mechanism:

  ```dart
  // ignore: flutter_a11y_rule_name
  Icon(Icons.drag_handle)
  ```

* Provide optional per-rule configuration overrides.
* Error messages must explain *why* the rule exists.

---

## 10. Category 9 — False Positive Management

False positives kill linter adoption.

A rule is considered noisy if:

* It flags idiomatic valid patterns,
* It fires on design system wrappers,
* It analyzes localization keys incorrectly,
* It suggests changes that alter functionality.

### ✔ Strategies to Maintain Developer Trust

1. **Keep warnings limited to high-confidence cases.**
2. **Heuristic rules should be INFO, not WARNING.**
3. **Customizable suppression**:
   * Inline ignoring
   * File-level ignoring
   * Configuration through `analysis_options.yaml`
4. **Helpful diagnostics**:
   * Include actionable fixes in `correctionMessage`.

---

## 11. Category 10 — Incremental vs Strict Enforcement

Large companies adopt new lint rules gradually.

### ✔ Reality

* They cannot fix thousands of warnings at once.
* Adding too many strict rules breaks CI.

### ✔ Solution

* Provide a configuration mode:

  ```yaml
  flutter_a11y_lints:
    mode: conservative   # default (safe subset)
    # or
    mode: expanded       # includes heuristics
  ```

* Only high-confidence rules belong to “conservative” mode.

---

## 12. Final Guidance for Coding Agents

The coding agent implementing this linter should:

### **1. Prioritize reliability over completeness.**

If a rule has any non-trivial false-positive risk, it belongs in the heuristic set.

### **2. Treat localization, custom widgets, and layout as unknowns.**

Never assume they are incorrect.

### **3. Avoid expensive full-file scans.**

Use targeted AST visitors.

### **4. Always skip generated files.**

### **5. Offer clear, safe auto-fixes where possible.**

### **6. Default to conservative behavior unless explicitly configured otherwise.**

---

## Document 2 Summary

This document provides the architectural and practical obstacles you must anticipate while implementing Flutter accessibility lints:

* Custom widgets
* Localization
* Layout unpredictability
* Builder patterns
* Multi-file context issues
* Generated code
* Performance
* Mixed UI frameworks
* Intentional deviations
* False positive control

These constraints directly inform *which rules can be strict* and *which must be heuristic*.
