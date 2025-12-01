# 📄 Document 4 — Rule Development Guidelines for `flutter_a11y_lints`

Precision, Heuristics, False-Positive Control, and Best Practices for Implementing Accessibility Lint Rules

**Version:** 1.0
**Purpose:** Provide coding agents and maintainers with a rigorous framework for designing new lint rules, balancing correctness, signal-to-noise ratio, and developer trust. This document ensures that every rule added to `flutter_a11y_lints` meets high standards of reliability, clarity, and real-world applicability.

---

## 1. Introduction

Accessibility linting is fundamentally different from style linting or API misuse detection.
You are not only checking code, but trying to infer **user experience quality**, **interaction semantics**, and **assistive technology behavior** from static code.

Because static analysis cannot access:

* layout,
* translation keys,
* runtime values,
* app-specific design patterns,
* multiple files of context,

lint rules must be designed very carefully.

This document outlines guiding principles and rule-design patterns to ensure the entire lint ecosystem remains:

* **trustworthy**
* **minimally annoying**
* **high-impact**
* **safe**
* **configurable**
* **scalable**
* **developer-friendly**

---

## 2. Core Philosophy

A rule must satisfy **at least one** of the following:

### ✔ High Confidence

It should fire only when the AST *directly proves* an accessibility issue.

### ✔ High Severity

It should protect the user from a significant barrier (e.g., unlabeled buttons).

### ✔ High Clarity

The violation must be clear, teachable, and easy for developers to fix.

Rules that cannot meet these criteria belong in the **heuristic** category, INFO level, or behind feature flags.

---

## 3. The Three Categories of Rules

Every rule belongs to exactly one category:

### A. High-Confidence Rules (Conservative Mode)

* Based on deterministic AST patterns
* Near-zero false positives
* Always WARNING
* Enabled by default

#### Characteristics (High Confidence)

* Uses literal values
* Uses direct widget class matching
* Does not rely on naming heuristics
* Does not require cross-file reasoning
* Does not require interpreting localizations

#### Examples (High Confidence)

* Missing tooltip on `IconButton`
* Redundant `Semantics(button: true)`
* Literal small tap targets
* Drag handle icons missing `ExcludeSemantics`

### B. Medium-Confidence Rules (Heuristic Mode)

* Requires contextual assumption
* Can be INFO or WARNING depending on severity
* Enabled only in expanded mode

#### Characteristics (Medium Confidence)

* Interprets widget relationships
* Evaluates likely UX issues
* Depends partly on naming patterns / heuristics
* May be false-positive in apps with custom design systems

#### Examples (Medium Confidence)

* Multi-part controls (icon + text combo requiring `MergeSemantics`)
* Numeric values missing units
* Contextual label detection in lists
* Debouncing screen reader announcements

### C. Low-Confidence / Advisory Rules

* Purely suggestive
* Not strict
* INFO only
* Often disabled unless explicitly turned on

#### Examples (Low Confidence)

* Hint should describe action, not meaning
* Validation feedback patterns
* Focus order heuristics

---

## 4. Rule Design Checklist

Every newly proposed rule must answer the following:

### 1. What accessibility problem does this rule solve?

* Reference WCAG success criteria when applicable.

### 2. Can this be detected statically with high confidence?

* If yes → Conservative Mode (WARNING).
* If no → Expanded Mode (INFO).

### 3. Is this rule stable across apps?

Does it break in:

* design systems?
* localization?
* generated code?
* Cupertino vs Material?

### 4. What is the false-positive risk?

Classify rule:

* **Low risk** → Safe to enable by default
* **Medium risk** → Off-by-default
* **High risk** → Advisory only

### 5. Does the rule protect end users from harm?

Prioritize:

* unlabeled controls
* incorrect semantics
* broken navigation
* duplicate announcements
* misleading state

### 6. Is the correction actionable and unambiguous?

A developer should always know *exactly what to fix*.

### 7. Does the rule run efficiently?

Avoid rules that require:

* scanning entire AST more than once,
* nested complexity > O(n),
* expensive string or tree operations per node.

---

## 5. Principles for False-Positive Control

Static analysis must lean towards **safety** and **trustworthiness**:

### Rule 1 — Literal-only conditions when possible

Example:
Tap target rule warns only when numeric literal < 48.
Not when dynamic expressions or variables are used.

### Rule 2 — Do not assume custom widgets are broken

The rule should only apply to known Flutter primitives.

### Rule 3 — Never require knowing the widget’s final size or position

Layout cannot be reliably inferred.

### Rule 4 — Do not inspect i18n expressions

Localization keys cannot be assumed to contain problematic text.

### Rule 5 — Avoid multi-file reasoning

Do not attempt complex resolution across files for performance and correctness.

### Rule 6 — Avoid text-similarity heuristics unless opt-in

Heuristics like:

* “label contains the word button”
* “hint repeats label”
  are inherently imperfect.

### Rule 7 — Every rule must support inline ignores

```dart
// ignore: flutter_a11y_rule_name
```

### Rule 8 — Must skip generated files

Never lint:

* `*.g.dart`
* `*.freezed.dart`
* `*.gen.dart`
* `generated/**`

### Rule 9 — Never assume visual order from widget order

UI layout is unpredictable without runtime information.

### Rule 10 — Only warn when the AST is unquestionably wrong

Avoid speculative warnings.

---

## 6. Best Practices for Implementation

### ✔ Always start with `fileUsesFlutter(unit)`

Skip early for speed.

### ✔ Keep visitors narrow and specific

Only register for necessary node types.

### ✔ Use shared utilities

No duplicate AST logic spread across rule files.

### ✔ Prefer early returns in logic

```dart
if (!isX(node)) return;
if (!hasY(node)) return;
report(...)
```

### ✔ Keep warning messages

* Short
* Direct
* Action-oriented
* Non-judgmental

### ✔ Provide correction examples in documentation

But do not overload diagnostic message.

### ✔ Keep rule code simple and readable

Other maintainers should be able to understand rule logic instantly.

---

## 7. Patterns to Avoid in Rule Implementation

These patterns almost always produce false positives or unstable rules:

### 🚫 Avoid interpreting layout

(e.g., `Row`, `Column`, padding relationships)

### 🚫 Avoid interpreting the meaning of images unless filename is literal

(do not guess based on context heuristics)

### 🚫 Avoid detecting “semantic duplicates” across multiple files

(too expensive + unreliable)

### 🚫 Avoid deep widget-tree path inference

(e.g., “`Text` next to this icon so they belong together”)

### 🚫 Avoid semantic role inference for unknown widgets

(custom widgets may do everything correctly internally)

### 🚫 Avoid depending on static types when analyzers can’t always resolve them

(e.g., with dynamic or builder patterns)

---

## 8. Rule Documentation Template

````markdown
### AXX: Rule Name (flutter_a11y_rule_name)
**Severity:** WARNING / INFO  
**Confidence:** High / Medium / Low  
**Description:**  
Clear, short explanation of the issue.

**Rationale:**  
Why this matters for accessibility.

**Detects:**  
Precise list of AST patterns.

**Does NOT detect:**  
List what intentionally remains unhandled.

**Violation Example:**
```dart
<example>
```

**Correct Pattern:**

```dart
<example>
```

**False-Positive Considerations:**
Explicitly state when a false positive may occur.

**Related WCAG:**
(optional)
````

This template standardizes quality and readability across contributors.

---

## 9. How to Decide Severity Level

### **WARNING** → Only if

* High-confidence detection
* Fix is always correct
* Very low false-positive risk
* Protects usability significantly

Examples: `A01`, `A05`, `A21`, `A24`.

### **INFO** → When

* Heuristic rule
* Fix may vary
* Suggestive guidance

Examples: `A06`, `A09`, `A23`, `A17`.

### **OFF by default** → When

* Experimental
* Difficult to detect safely
* High FP risk

---

## 10. Heuristic Rules: Special Guidelines

For heuristic/app-structure-based rules:

* Always mark as INFO by default
* Describe the rule as “Consider…” instead of commanding
* Do not enforce correctness through strict interpretation
* Provide a configuration to disable per-project
* Keep detection narrow
* Document expected false positives

Heuristic rules are valuable but must not undermine developer confidence.

---

## 11. Designing Rules for Expandability

As the linter grows:

* New rules must not degrade performance.
* New rules must not break CI pipelines for existing users.
* Every new rule should be categorized early.

### Future Designers Must

* Add new rule to the correct category
* Justify confidence level
* Provide test cases across edge scenarios
* Ensure config toggles work properly
* Keep rule logic easy to extend

---

## 12. Summary

This document provides a full framework for designing accessibility lint rules that:

* minimize false positives
* maximize developer trust
* categorize rules by confidence
* build on consistent architectural decisions
* preserve performance
* avoid overreach in static analysis

It forms the fourth cornerstone of the linting system alongside:

1. **Document 1:** High-confidence rule specification
2. **Document 2:** Real-world challenges
3. **Document 3:** System architecture
4. **Document 4:** Rule development guidelines (this document)
