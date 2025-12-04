# FAQL Specification (v2.0)

**Target Domain:** Flutter Static Accessibility Analysis
**Execution Model:** AST-Based Semantic Tree Inspection

## 1\. Overview

FAQL (Flutter Accessibility Query Language) is a domain-specific language designed to enforce accessibility standards on the Flutter `SemanticsNode` tree. It operates on an Intermediate Representation (IR) of the code, allowing for static verification of accessibility properties without running the app.

### 1.1 The Evaluation Pipeline

Each rule is evaluated against a node in three distinct phases:

1. **Selection ($O(1)$):** The runtime quickly identifies if the node matches the `on <selector>` criteria.
2. **Filtering (Guard):** The `when:` clause is evaluated. If `false`, the rule is skipped (short-circuit).
3. **Assertion (Compliance):** The `ensure:` clause is evaluated. If `false`, a violation is reported.

-----

## 2\. Rule Structure

A rule consists of a header (Definition) and a body (Logic).

```kotlin
rule "rule-id" on <selector> {
    meta { 
        severity: "error" 
        // Additional metadata (optional)
    }

    when: <condition>    // The Gatekeeper (Optional)
    ensure: <condition>  // The Inspector (Required)
    
    report: "Error message with ${interpolation}"
}
```

-----

## 3\. Selectors

Selectors determine the scope of a rule. They are evaluated before the rule body is instantiated.

| Selector | Description | Example |
| :--- | :--- | :--- |
| `any` | Matches every node in the tree. | `on any` |
| `role(id)` | Matches a specific `SemanticRole` (enum). | `on role(button)` |
| `type(id)` | Matches the Dart Class Name of the originating Widget. | `on type(InkWell)` |
| `kind(id)` | Matches a generalized control category. | `on kind(slider)` |

**Combinators:** Selectors can be combined using `||` (OR).

* *Example:* `on role(button) || role(toggle)`

-----

## 4\. Logic & Keywords

### 4.1 The Clauses

* **`when:` (Precondition)**
  * Acts as a guard clause.
  * **Behavior:** If this expression evaluates to `false`, execution stops, and the node is considered "Not Applicable." No error is reported.
  * *Use Case:* Preventing crashes or irrelevant checks (e.g., don't check text contrast on an invisible node).
* **`ensure:` (Assertion)**
  * The core compliance check.
  * **Behavior:** If this expression evaluates to `false`, the rule has failed.
  * *Use Case:* Enforcing the standard (e.g., "Must have a label").

### 4.2 Property Access (`prop`)

FAQL allows access to raw AST properties via the `prop()` function. Because static analysis cannot always guarantee types, explicit casting is required.

* **`prop(name)`**: Fetches the raw argument from the Widget definition.
* **`.is_resolved`**: Returns `true` if the static analyzer successfully determined a constant value for this property.

**Casting Syntax:**

* `prop(x) as string` (Evaluates to `String?`)
* `prop(x) as int` (Evaluates to `Int?`)
* `prop(x) as bool` (Evaluates to `Bool?`)

### 4.3 Semantic State (Booleans)

These keywords access the calculated state of the `SemanticsNode`.

* `focusable`, `enabled`, `toggled`, `checked`
* `hidden` (Is the node effectively invisible to accessibility tools?)
* `merging` (Does this node merge its descendants?)
* `has_tap`, `has_long_press` (Action availability)

-----

## 5\. Tree Traversal

Rules can inspect the graph surrounding the current node (`this`).

### 5.1 Relations

| Relation | Context |
| :--- | :--- |
| `children` | Immediate structural descendants. |
| `siblings` | Nodes sharing the same parent. |
| `ancestors` | The path from `this` up to the root. |
| `next_focus` | The next node in the *Linear Traversal Order*. |
| `prev_focus` | The previous node in the *Linear Traversal Order*. |

### 5.2 Aggregators

Used to evaluate conditions over a list of nodes found via relations.

* `.any(condition)`: True if at least one matches.
* `.all(condition)`: True if everyone matches.
* `.none(condition)`: True if zero match.
* `.count`: Returns the integer number of items.

*Example:* `ensure: children.none(focusable)` (Ensure no children are focusable).

-----

## 6\. Operators & Types

### 6.1 Comparison

* Standard: `==`, `!=`, `>`, `<`, `>=`, `<=`
* Loose String Match: `~=` (Case-insensitive equality), `!~=`

### 6.2 String Operations

* `contains "substring"`
* `matches "regex"`
* `is_empty`, `is_not_empty`

### 6.3 Logic

* `&&` (AND), `||` (OR), `!` (NOT)

-----

## 7\. Examples

### A. The "Guard" Pattern (Safe Property Access)

*Scenario:* Ensure a custom `step` property on a Slider is valid, but only if the developer actually defined it.

```kotlin
rule "slider-step-limit" on kind(slider) {
    // 1. Guard: Only run if 'divisions' is defined and statically known
    when: prop(divisions).is_resolved

    // 2. Assert: Check the value
    ensure: prop(divisions) as int <= 10

    report: "Sliders should not have more than 10 divisions for ease of use."
}
```

### B. Structural Integrity (Traversal)

*Scenario:* A button must not contain another button (nested touch targets).

```kotlin
rule "no-nested-buttons" on role(button) {
    // Check all ancestors to ensure none of them are buttons
    ensure: ancestors.none( role == "button" )

    report: "Nested interactive elements detected. This button is inside another button."
}
```
