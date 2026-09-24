# FAQL 4 Core: correctness-first accessibility queries

**Status:** Proposed design, 2026-09-24. This document is a target architecture and migration guide; its examples are not a description of the current FAQL parser or public API.

## 1. Goal and boundary

FAQL 4 Core should let `flutter_a11y_lints` query accessibility facts that static analysis can establish reliably. Its priorities are correctness, low false-positive rates, explicit uncertainty, a small language surface, and extension by adding facts and predicates rather than syntax.

Initial queries should cover known interactive controls without labels, explicit semantic roles and actions, merge/exclude misuse, known widget relationships, and literal source properties. They must not claim actual TalkBack or VoiceOver output, rendered geometry, visual order, runtime state transitions, or arbitrary Dart data flow.

A fact being exact does not make a rule conclusion exact. A literal label `"72"` can be certain while a claim that it needs a unit remains a policy heuristic.

## 2. Architecture and ownership

```text
Dart source → analyzer → WidgetTree → Semantic IR → typed fact store
                                                  ↓
                                          FAQL standard library
                                                  ↓
                                    parser / validator / evaluator
                                                  ↓
                                           diagnostics / JSON / SARIF
```

- Flutter-specific knowledge belongs in semantic synthesis and fact extraction.
- Reusable accessibility concepts belong in the query standard library.
- Individual accessibility policies belong in `.faql` queries.
- Source and semantic nodes must retain stable identities and source locations. A widget edge is not necessarily an edge in the runtime accessibility tree; model those relations separately.
- The fact store is an immutable snapshot for one analysis scope. Facts carry scope and provenance; consumers must not mutate Semantic IR while evaluating queries.

This architecture is incremental. The existing files under `lib/src/faql`, `lib/src/semantics`, `lib/src/widget_tree`, and `lib/rules` remain the implementation until migrated.

## 3. Explicit knowledge, including unknown

Absence of a positive fact is **not** proof of a negative one. Define a closed, typed state for properties whose absence matters:

```text
LabelState = unknown | absent | dynamic | static
EnabledState = unknown | enabled | disabled
FocusableState = unknown | focusable | notFocusable
VisibilityState = unknown | visible | hidden
```

The exact enum/API names may change, but their meanings must not. A dynamic label means a label-producing expression is present and its runtime value cannot be resolved; it does **not** prove that the resulting string is nonempty. A known unlabeled control has `LabelState.absent` only after its relevant known widget semantics, merge/exclude context, and alternate label sources have been examined. Unresolved custom widget behavior is `unknown`.

Use `isDefinitelyUnlabeled()` for a conservative finding, never `not hasAccessibleLabel()` where label knowledge is partial. Apply the same rule to enabled, interactive, visibility, and focusability claims. A node without an accessibility focus index is not thereby hidden.

## 4. Core fact vocabulary

The first fact-store slice is intentionally small:

| Family | Facts (illustrative names) | Notes |
| --- | --- | --- |
| Identity/structure | `Node`, `WidgetType`, `Parent`, `Slot`, `SourceLocation` | Keep widget and semantic relations distinguishable. |
| Control flow | `Branch`, branch group/value | Do not combine mutually exclusive alternatives in one finding. |
| Semantics | `Role`, `ControlKind`, `Action`, enabled/focusable/label states | Typed values, with explicit unknown. |
| Name/state | `LabelSource`, `StaticLabel`, `Tooltip`, `Value`, checked/toggled state | A static string is not proof of an adequate name. |
| Composition | merge/exclude, boundary, known composite/pure-container | Record only justified properties. |
| Source properties | constructor and resolved string/bool/int arguments | Emit values only when statically resolved. |
| Evidence | origin, source span, derivation inputs, analysis scope | Preserve enough to explain a finding. |

`WidgetNode.slots` already captures `child`, `title`, `leading`, and `trailing`. Preserve a slot edge when building the new facts. Example: `Slot(tile, "trailing", deleteButton)`. Do not silently equate a named widget slot with an accessibility child.

Generic constant properties replace ad hoc adapter fields such as `assetPath`, `backgroundImageProvided`, and `childWidgetType`. A source expression with no resolved constant produces unknown, not a made-up string or Boolean.

Do not store rule-specific derived fields such as `hasButtonDescendant`, `labeledChildrenCount`, or `focusableDescendantCount`. Derive them through `Descendant`, typed node views, and `count`. The first implementation can traverse indexed parents and children; it does not need general user-defined recursion.

## 5. Provenance and conservative views

Track semantic evidence as `exact`, `derived`, or `heuristic`.

- **Exact:** literal properties, explicit `Semantics` arguments, verified known-widget behavior.
- **Derived:** safe conclusions from exact inputs, such as ancestry or a verified merged label.
- **Heuristic:** layout grouping, naming guesses, inferred custom-widget behavior.

Derived provenance must retain its inputs. If any needed input is heuristic, the conclusion cannot silently become exact. A conservative view admits exact facts and derived facts whose premises and derivation are safe. Expanded mode may additionally use heuristic facts. Rule precision is separate: even a rule using exact strings can be heuristic policy.

Define which predicates are **complete** for their scoped domain. Conservative negation of a partial predicate must fail validation. For instance, known widget identity can be complete while accessible-label presence may be partial. Use positive predicates expressing proven absence. This contract also applies inside `exists` and `count`: an unknown candidate or unresolved branch must not produce a false proof of absence or an invalid count.

## 6. Minimal query language

Start with metadata, `from`, `where`, `select`, Boolean operators, comparisons, `exists`, `count`, and built-in member predicates. Provide typed variables, source spans for errors, and semantic validation before evaluation. No user-defined classes, modules, recursion, data-flow syntax, path queries, optimizer hints, or arbitrary Dart evaluation.

Illustrative syntax, subject to parser validation during implementation:

```faql
/**
 * @id flutter-a11y/a01/unlabeled-interactive
 * @rule-id a01_unlabeled_interactive
 * @severity warning
 * @mode conservative
 */
from InteractiveControl control
where
  control.isDefinitelyEnabled() and
  control.isDefinitelyUnlabeled()
select control, "Interactive control must have an accessible label."
```

Built-in views can initially include `SemanticNode`, `InteractiveControl`, `MaterialButtonControl`, `ImageNode`, `SemanticsNode`, `MergeSemanticsNode`, and `ListTileNode`. A view includes only nodes for which its membership is established. Keep a small tree and accessibility standard library: parent, child, ancestor, descendant, slot, widget type, definite state, label source, action, merge, and exclude. Add methods only when supported by facts.

A possible later rule counts independent actions under `MergeSemantics`:

```faql
from MergeSemanticsNode merge
where count(InteractiveControl control |
  control = merge.getADescendant()
) >= 2
select merge, "Merged semantics contain multiple independent actions."
```

This is a **candidate** rule: validate Flutter's actual merge behavior, branch co-occurrence, and known implicit actions before enabling it by default. Syntax examples do not imply that the current interpreter supports this form.

The initial evaluator can scan indexed typed views, filter, traverse cached relationships, and emit deduplicated tuples. Profile before building a general optimizer. Invalid rules should produce actionable configuration diagnostics without inventing accessibility violations.

## 7. Query identity and reporting

A `queryId` uniquely identifies a query; a `ruleId` identifies the public accessibility rule. Multiple queries may share a rule ID, for example two A04 cases. The catalog is a list with indexes by query ID, rule ID, and mode. Reject duplicate query IDs; do not overwrite one A04 query with another. Preserve source locations and evidence in findings. Keep deterministic ordering and deduplication rules across multiple queries.

## 8. Initial rule scope

| Mode | Candidate existing rules | Gate |
| --- | --- | --- |
| Conservative | A01, narrow A03/A04, A05, A21, A22 | Recheck each premise and real Flutter behavior in tests. |
| Expanded | A02, A06, A07, A09, A13, A15 | Their accessibility conclusion needs contextual judgment or missing evidence. |
| Future conservative candidate | Multiple independent actions under MergeSemantics | Validate actual semantics and mutually exclusive branches first. |

Existing labels, numbers, and source properties may be known exactly while the corresponding policy remains uncertain. Keep unsupported cases silent in conservative mode.

## 9. Near-term fact additions and later domains

1. Preserve named widget slots and source-to-semantic node mapping.
2. Extract statically resolved string, Boolean, and integer constructor properties.
3. Add explicit visibility facts for applicable `Offstage`, `Visibility`, and `ExcludeSemantics` cases; account for maintained semantics. Never infer hidden from nonfocusable.
4. Add literal size constraints only when a future rule can prove the effective interactive target size; a small `SizedBox` around an `IconButton` alone may not prove its final hit region.
5. Later add focus configuration, gesture kinds and explicit semantic actions, list item context, and form associations as concrete rules require them.
6. Introduce separate `Invocation`/`Callback` facts before tackling announcement frequency or async updates. Do not force source-level behavior into `SemanticNode`.

Runtime geometry, localized text values, exact screen-reader output, visual traversal order, and arbitrary program/data flow remain out of scope.

## 10. Current correctness work and migration

The current `FaqlRuleCatalog` uses `collection[spec.code]`, so queries with the same public code can overwrite each other. `SemanticNeighborhood.isHidden()` treats a missing focus index as hidden. Correct both semantics before trusting related conservative rules. Review root conditional alternatives and custom-widget summary integration before relying on them. `blocksBehind` does not alone identify which nodes sit behind an overlay.

Migration stages:

1. Fix catalog identity and incorrect hidden-state inference; audit conditional branches and choose a canonical generated-rule path.
2. Build and directly test immutable structural, semantic, primitive-property, and provenance facts without changing the rule language.
3. Implement the small parser/validator/evaluator with safe negation and explicit unknown handling.
4. Port only validated conservative queries, comparing old/new findings on the same fixtures and explaining every difference.
5. Remove one-off bridge fields after equivalent general queries exist. Move heuristic policies only after the conservative core is stable.

A possible target layout is `lib/src/facts/`, `lib/src/query/`, `lib/src/query_stdlib/`, and a single generated built-in query bundle. This is a destination, not a reason to move existing files before their responsibilities change.

## 11. Acceptance invariants

- Unknown evidence alone cannot generate a conservative finding.
- Nonfocusable and hidden are different states.
- Every finding can identify its rule query, source location, supporting facts, and provenance.
- A derived fact cannot gain stronger provenance than its premises.
- Mutually exclusive branches cannot jointly satisfy a count or relationship rule.
- Query code cannot depend on Dart analyzer internals.
- Adding a rule normally changes only a `.faql` file; adding information normally changes extraction plus a standard-library predicate.
- Two queries may report one public rule without collisions.
- Conservative/expanded behavior and any changed findings are covered by focused fixtures.

**Design principle:** extend the database of justified facts and reusable predicates before extending the grammar.
