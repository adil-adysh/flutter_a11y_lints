# FAQL Language Specification

**Last Updated:** December 06, 2025

## 1\. Introduction

FAQL (Flutter Accessibility Query Language) is a domain-specific language designed to enforce accessibility standards on the Flutter `SemanticsNode` tree. It operates on a static Intermediate Representation (IR), bridging the gap between the runtime **Accessibility Tree** and the static **Widget Source Code**.

### 1.1 Execution Pipeline

Every rule follows a strict three-phase evaluation process:

1. **Selection (Scope):** The runtime identifies if a node matches the `on <selector>` criteria.
2. **Filtering (Guard):** The `when:` clause is evaluated. If it evaluates to `false`, the rule is short-circuited (skipped).
3. **Assertion (Compliance):** The `ensure:` clause is evaluated. If it evaluates to `false`, a violation is reported.

-----

## 2\. Type System

FAQL is strongly typed. It explicitly distinguishes between the **Semantics Context** (`this`) and the **Source Context** (`widget`).

### 2.1 Primitive Types

| Type | Description | Nullable? |
| :--- | :--- | :--- |
| `String` | UTF-16 character sequence. | Yes |
| `Int` | 64-bit signed integer. | Yes |
| `Bool` | Boolean value (`true` / `false`). | Yes |
| `Node` | A reference to a `SemanticsNode`. | No |
| `NodeList` | An ordered collection of Nodes (e.g., `children`). | No (Empty list) |

### 2.2 Null Handling (Safe Navigation)

FAQL implements "Safe Failure" semantics. The compiler never crashes on missing data.

* **Access:** Accessing a missing property or index returns `null` (SafeValue).
* **Comparisons:**
  * `null == null` $\rightarrow$ `true`
  * `null == <value>` $\rightarrow$ `false`
  * `if (null)` $\rightarrow$ evaluates to `false` (Rule skip or failure).

-----

## 3\. Grammar (EBNF)

The syntax is LL(1) compatible.

```ebnf
rule_unit     ::= 'rule' string_literal 'on' selector '{' body '}'

/* 1. Selectors */
selector      ::= term ('||' term)*
term          ::= 'any' 
                | 'role' '(' enum_ref ')' 
                | 'type' '(' identifier ')' 
                | 'kind' '(' enum_ref ')'

enum_ref      ::= identifier '.' identifier   // e.g., Role.button

/* 2. Body Structure */
body          ::= meta? when? ensure report
meta          ::= 'meta' '{' (identifier ':' string_literal)* '}'
when          ::= 'when:' expression
ensure        ::= 'ensure:' expression
report        ::= 'report:' string_literal

/* 3. Expressions & Logic */
expression    ::= logical_or
logical_or    ::= logical_and ('||' logical_and)*
logical_and   ::= equality ('&&' equality)*

/* 4. String Fluent Matching */
equality      ::= relational (('==' | '!=' ) relational)*
                | string_expr '.' 'matches' '(' string_literal ')'

/* 5. Relational & Primitives */
relational    ::= additive (('<' | '>' | '<=' | '>=') additive)*
additive      ::= primitive
state_check   ::= primitive 'is' 'defined'  // The "is defined" Check

primitive     ::= '(' expression ')'
                | traversal
                | index_access
                | widget_access
                | literal
                | identifier        // Implicit 'this' property
                | 'this'            // Explicit 'this' reference

/* 6. Traversal, Indexing, & Source Access */
traversal     ::= relation '.' ('length' | aggregator '(' expression ')')
                | 'closest' '(' selector ')'
                | 'this' '.' relation // Explicit navigation

index_access  ::= identifier '[' integer ']'

// Source Code Access
widget_access ::= 'widget' '<' type_param '>' '(' string_literal ')'

relation      ::= 'children' | 'descendants' | 'ancestors' | 'siblings' 
                | 'parent'   | 'firstChild'  | 'lastChild' | 'onlyChild'

type_param    ::= 'int' | 'string' | 'bool'
```

-----

## 4\. Selectors & Context

### 4.1 Selectors

Selectors define the scope using strict Enum references.

* `on role(Role.button)`: Matches semantic roles.
* `on type(InkWell)`: Matches the specific Widget class name.
* `on kind(Kind.input)`: Matches a macro group (e.g., text fields, sliders).

### 4.2 Context State (Variables)

These keywords resolve to properties of the current Semantics Node (`this`).

| Keyword | Type | Mapping |
| :--- | :--- | :--- |
| `focusable` | `Bool` | `this.isFocusable` |
| `enabled` | `Bool` | `this.isEnabled` |
| `checked` | `Bool` | `this.isChecked` |
| `toggled` | `Bool` | `this.isToggled` |
| `hidden` | `Bool` | `this.isHidden` |
| `label` | `String` | `this.semanticsLabel` |
| `hint` | `String` | `this.semanticsHint` |
| `value` | `String` | `this.semanticsValue` |

-----

## 5\. Tree Traversal & Relations

Relations allow navigation through the **Semantics Graph**.

| Relation | Type | Description |
| :--- | :--- | :--- |
| **Singular** | | |
| `parent` | `Node?` | The immediate semantic container. |
| `firstChild` | `Node?` | Alias for `children[0]`. |
| `lastChild` | `Node?` | Alias for `children[last]`. |
| `onlyChild` | `Node?` | Returns node **iff** count is exactly 1. |
| `closest(sel)`| `Node?` | Finds first ancestor matching the selector. |
| **Collections** | | |
| `children` | `List` | Immediate direct items (Depth 1). |
| `descendants`| `List` | **Recursive** subtree items (Depth N). |
| `ancestors` | `List` | Path from parent to root. |
| `siblings` | `List` | Nodes sharing the same parent. |

### 5.2 Aggregators & Scoping

Aggregators operate on lists. Loops use an **explicit scope variable `it`**.

* `.any( it.role == ... )`
* `.all( it.enabled )`
* `.none( ... )`
* `.filter( ... )`

-----

## 6\. Context Resolution: Semantics vs. Source

FAQL provides two distinct keywords to handle the separation between the Accessibility Tree (Result) and the Widget Tree (Source).

### 6.1 The Semantic Context (`this`)

* **Target:** The `SemanticsNode` (Runtime/Graph representation).
* **Usage:** Used to check relationships, computed labels, and accessibility roles.
* **Implicit:** The keyword `this` is optional.
  * `ensure: label == "Go"` is equivalent to `ensure: this.label == "Go"`.

### 6.2 The Source Context (`widget`)

* **Target:** The Widget AST (Source Code representation).
* **Usage:** Used to check hardcoded configuration parameters.
* **Syntax:** `widget<Type>("paramName")`

### 6.3 Static Definition Check (`is defined`)

The `is defined` operator is a special postfix operator designed for static analysis. It distinguishes between a value that is **explicitly set in code** versus a value that is **default/null**.

* **Syntax:** `<expression> is defined`
* **Returns:** `Bool` (`true` if the AST contains an explicit assignment, `false` otherwise).

**Truth Table:**

| Code Example | Expression | Result |
| :--- | :--- | :--- |
| `Slider(min: 0)` | `widget<int>("min") is defined` | **`true`** |
| `Slider(min: 0)` | `widget<int>("max") is defined` | **`false`** |
| `Slider(min: null)` | `widget<int>("min") is defined` | **`true`** (It is defined as null) |
| `Slider(/* empty */)` | `widget<int>("min") is defined` | **`false`** |

**Why this is needed:**
In accessibility testing, we often need to know if the developer *forgot* to set a label (undefined), or if they deliberately set it to empty (defined but empty). `is defined` captures this intent.

-----

## 7\. Operators & Precedence

1. `widget<>()`, `[]` (Indexing), `()` (Grouping)
2. `.` (Dot Access)
3. `.matches()` (String Fluent Match)
4. `*`, `/`
5. `+`, `-`
6. `<`, `<=`, `>`, `>=`
7. `is defined` (State Check)
8. `==`, `!=`
9. `&&`
10. `||`

-----

## 8\. Examples

### 8.1 Usage of `is defined`

```kotlin
rule "explicit-semantic-label" on role(Role.button) {
    // We only want to check buttons where the developer TRIED to add a label
    // If they didn't define it at all, a different rule handles that.
    
    when: widget<string>("semanticsLabel") is defined

    ensure: label.matches("Submit")
    report: "If you define a label manually, it must match the standard 'Submit'."
}
```

### 8.2 Explicit `this` vs `widget`

```kotlin
rule "custom-button-config" on type(MyCustomButton) {
    // Check Source: Did the dev set the danger flag in code?
    when: widget<bool>("isDangerous") == true

    // Check Semantics: Does the node reflect that danger?
    ensure: this.label.matches("Delete") 
         || this.hint.matches("Irreversible")

    report: "Dangerous buttons must have clear warning labels."
}
```
