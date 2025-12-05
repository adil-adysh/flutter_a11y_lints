
# FAQL Language Specification

**Version:** 3.0 (Candidate)
**Status:** Draft / Implementation Ready
**Last Updated:** December 05, 2025

## 1\. Introduction

FAQL (Flutter Accessibility Query Language) is a domain-specific language designed to enforce accessibility standards on the Flutter `SemanticsNode` tree. It operates on a static Intermediate Representation (IR) of the code, enabling accessibility compliance checks without requiring a runtime environment.

### 1.1 Execution Pipeline

Every rule follows a strict three-phase evaluation process:

1.  **Selection (Scope):** The runtime identifies if a node matches the `on <selector>` criteria.
2.  **Filtering (Guard):** The `when:` clause is evaluated. If it evaluates to `false`, the rule is short-circuited (skipped).
3.  **Assertion (Compliance):** The `ensure:` clause is evaluated. If it evaluates to `false`, a violation is reported.

-----

## 2\. Type System

FAQL is strongly typed with explicit casting from the untyped AST.

### 2.1 Primitive Types

| Type | Description | Nullable? |
| :--- | :--- | :--- |
| `String` | UTF-16 character sequence. | Yes |
| `Int` | 64-bit signed integer. | Yes |
| `Bool` | Boolean value (`true` / `false`). | Yes |
| `Node` | A reference to a `SemanticsNode` (the context `this`). | No |
| `NodeList` | An ordered collection of Nodes (e.g., `children`). | No (Empty list) |

### 2.2 Null Handling (Safe Navigation)

FAQL implements "Safe Failure" semantics to prevent runtime crashes during static analysis:

  * **Prop Access:** Accessing a missing property returns `null`.
  * **Casting:** Casting `null` to any type returns `null`.
  * **Comparison:**
      * `null == null` $\rightarrow$ `true`
      * `null == <value>` $\rightarrow$ `false`
      * Relational ops (`>`, `<`, etc.) with `null` always evaluate to `false`.
  * **Boolean Logic:** `null` in a condition (e.g., `if (null)`) evaluates to `false`.

-----

## 3\. Grammar (EBNF)

The syntax is LL(1) compatible.

```ebnf
rule_unit     ::= 'rule' string_literal 'on' selector '{' body '}'

selector      ::= term ('||' term)*
term          ::= 'any' 
                | 'role' '(' identifier ')' 
                | 'type' '(' identifier ')' 
                | 'kind' '(' identifier ')'

body          ::= meta? when? ensure report
meta          ::= 'meta' '{' (identifier ':' string_literal)* '}'
when          ::= 'when:' expression
ensure        ::= 'ensure:' expression
report        ::= 'report:' string_literal

expression    ::= logical_or
logical_or    ::= logical_and ('||' logical_and)*
logical_and   ::= equality ('&&' equality)*
equality      ::= relational (('==' | '!=' | '~=') relational)*
relational    ::= additive (('<' | '>' | '<=' | '>=') additive)*
additive      ::= primitive

primitive     ::= '(' expression ')'
                | traversal
                | prop_access
                | literal
                | identifier (Context State)

traversal     ::= relation '.' ('length' | aggregator '(' expression ')')
prop_access   ::= 'prop' '(' string_literal ')' cast?
cast          ::= 'as' ('string' | 'int' | 'bool') | '.is_resolved'
```

-----

## 4\. Selectors & Context

### 4.1 Selectors

Selectors define the scope of the rule.

  * `on any`: Matches all nodes.
  * `on role(id)`: Matches `SemanticsFlag` (e.g., `button`, `textField`).
  * `on type(id)`: Matches the Widget class name (e.g., `InkWell`).
  * `on kind(id)`: Matches a macro group of roles.
      * *Implementation Note:* The compiler must maintain a lookup table for kinds (e.g., `kind(input)` $\rightarrow$ `textField || slider || switch`).

### 4.2 Context State (Variables)

These keywords resolve to boolean properties of the current `Node` (`this`).

| Keyword | Mapping |
| :--- | :--- |
| `focusable` | `isFocusable` |
| `enabled` | `isEnabled` |
| `checked` | `isChecked` |
| `toggled` | `isToggled` |
| `hidden` | `isHidden` |
| `merges_descendants` | `isMergingSemanticsOfDescendants` |
| `has_tap` | `onTap != null` |
| `has_long_press` | `onLongPress != null` |

-----

## 5\. Tree Traversal

### 5.1 Relations

Relations return a `NodeList` representing graph edges.

  * `children`: Immediate structural descendants.
  * `siblings`: Nodes sharing the same parent (excluding `this`).
  * `ancestors`: Path from parent up to root.
  * `next_focus`: The next node in linear traversal order.
  * `prev_focus`: The previous node in linear traversal order.

### 5.2 Aggregators

Aggregators operate on a `NodeList`.

  * `.any(expression)`: Returns `true` if *at least one* node satisfies the expression.
  * `.all(expression)`: Returns `true` if *all* nodes satisfy the expression.
  * `.none(expression)`: Returns `true` if *zero* nodes satisfy the expression.
  * `.length`: Returns the count of nodes as an `Int`.

-----

## 6\. Operators

### 6.1 Operator Precedence

(Highest to Lowest)

1.  `()` Grouping, `.` Access, `prop()`
2.  `!` Not, `-` Negation
3.  `*`, `/`
4.  `+`, `-`
5.  `<`, `<=`, `>`, `>=`
6.  `==`, `!=`, `~=`
7.  `&&`
8.  `||`

### 6.2 Comparison Operators

  * `==` / `!=`: Strict equality.
  * `~=`: **Loose Match**.
      * If operands are strings: Case-insensitive, trimmed equality check.
      * Otherwise: Returns `false`.

-----

## 7\. AST Property Access

The `prop` function bridges the gap between the Semantic Tree and the raw Widget AST.

### 7.1 Syntax

`prop("parameterName")`

### 7.2 Resolution & Casting

Since the AST is untyped at this level, explicit casting is required.

  * **Resolution Check:** `.is_resolved` returns `true` if the value is a static constant.
  * **Casting:** `as string`, `as int`, `as bool`.

### Example

```kotlin
// Check if 'divisions' is set to 5
when: prop("divisions").is_resolved
ensure: prop("divisions") as int == 5
```

-----

## 8\. Examples

### 8.1 Basic Attribute Check

```kotlin
rule "button-label" on role(button) {
    meta { severity: "error" }
    ensure: is_not_empty
    report: "Buttons must have a semantic label."
}
```

### 8.2 Complex Traversal

```kotlin
rule "no-nested-interactables" on role(button) {
    // Ensure no ancestor is also a button
    ensure: ancestors.none( role == "button" )
    report: "Interactive elements cannot be nested."
}
```

### 8.3 List Validation

```kotlin
rule "bottom-nav-items" on type(BottomNavigationBar) {
    ensure: children.length >= 2 && children.length <= 5
    report: "Bottom Navigation must have between 2 and 5 items."
}
```
