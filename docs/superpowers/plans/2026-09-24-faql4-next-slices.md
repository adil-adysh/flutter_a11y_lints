# FAQL 4 Next Slices Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the fact-first FAQL 4 cutover after the foundation commits.

**Architecture:** Extend the immutable fact store from `SemanticTree`, compile the full Core grammar into typed relational plans, then port rules onto standard-library views. The legacy adapter/selector engine remains unavailable to FAQL 4 and is deleted only after its replacements pass fixture tests.

**Tech Stack:** Dart, analyzer AST, `petitparser` only if retained for the new grammar, `package:test`.

**Spec:** `doc/docs/faql4_core_design.md`

## Global Constraints

- Unknown information must not produce a conservative finding.
- Keep widget edges, named slots, semantic edges, and incompatible branches distinct.
- Conservative mode admits only exact or safely-derived facts; expanded mode admits heuristics with visible provenance.
- Do not infer hidden from absence from the focus list or use custom-widget summaries for conservative findings.
- Use `queryId` for uniqueness and permit multiple queries to share a public `ruleId`.

## Review Focus

- A dynamic or unresolved label must not be reported as definitely absent.
- A count or `exists` expression must not combine mutually exclusive branches.
- `Offstage`, `Visibility`, and `ExcludeSemantics` must not be conflated with non-focusability.
- Primitive-property extraction must omit non-constant expressions instead of inventing a value.
- A catalog with two A04 queries must preserve both results and their common public rule ID.

---

### Task 1: Complete semantic facts and remove adapter dependencies

**Files:**
- Modify: `lib/src/semantics/semantic_node.dart`, `lib/src/semantics/semantic_builder.dart`, `lib/src/facts/fact_store.dart`, `lib/src/facts/semantic_fact_extractor.dart`
- Delete: `lib/src/bridge/semantic_faql_adapter.dart`
- Test: `test/facts/semantic_fact_extractor_test.dart`, `test/semantics/semantic_builder_test.dart`

**Interfaces:**
- Produces `AccessibilityFactStore` structural facts for node/type/parent/slot/location/branch and semantic/property facts with provenance.
- Consumes annotated `SemanticTree` nodes and the existing `WidgetNode.slots`/raw constructor attributes.

- [ ] Add failing tests for named slots, literal string/bool/int properties, explicit visibility, and unresolved custom widgets.
- [ ] Run `dart test test/facts/semantic_fact_extractor_test.dart test/semantics/semantic_builder_test.dart`; confirm each new assertion fails because the fact is missing.
- [ ] Carry slot identities into `SemanticNode`, preserve them through `copyWith`/tree annotation, and emit `slot:<name>` relationship facts.
- [ ] Extract only literal/resolved primitive properties; emit visibility only for explicit source constructs; map custom unresolved nodes to unknown facts.
- [ ] Run the task tests and `dart format --output=none --set-exit-if-changed lib test`; commit `feat: extract complete FAQL 4 facts`.

### Task 2: Implement the complete typed FAQL 4 Core compiler

**Files:**
- Split `lib/src/query/faql4.dart` into AST, lexer, parser, validator, compiler, evaluator, and standard-library modules under `lib/src/query/`.
- Test: `test/query/faql4_test.dart` plus parser/validator/evaluator-focused test files.

**Interfaces:**
- Consumes `AccessibilityFactStore` and a FAQL source string.
- Produces `CompiledQuery` with metadata, typed bindings, mode, query plan, and select tuple.

- [ ] Write failing parser tests for metadata, `from`, `where`, `select`, comparisons, nested `and`/`or`/`not`, `exists`, and `count`.
- [ ] Write failing validator tests for unknown views/predicates, type mismatches, missing metadata, and conservative negation of partial predicates.
- [ ] Implement tokenization and AST parsing without legacy selectors, `ensure`, source access, casts, or user-defined recursion.
- [ ] Implement typed views/predicates and branch-compatible parent/child/ancestor/descendant/sibling traversal; evaluate `exists` and `count` against indexes.
- [ ] Run `dart test test/query`; commit `feat: implement FAQL 4 Core compiler`.

### Task 3: Port and verify conservative rules

**Files:**
- Modify: `lib/rules/a01_unlabeled_interactive.faql`, `a03_decorative_images_excluded.faql`, both A04 files, `a05_no_redundant_button_semantics.faql`, `a21_use_iconbutton_tooltip.faql`, `a22_respect_widget_semantic_boundaries.faql`
- Create: `lib/rules/merge_multiple_actions.faql`
- Modify: `tool/generate_rules.dart`, `lib/rules/builtin_faql_rules.g.dart`, `lib/rules/faql_rule_catalog.dart`
- Test: `test/rules/conservative_rules_test.dart`, `test/rules/query_catalog_test.dart`

**Interfaces:**
- Consumes Core views/predicates and generic properties from Tasks 1–2.
- Produces bundled conservative `CompiledQuery` instances keyed by `queryId`.

- [ ] Write failing fixture tests for each rule’s violation, valid counterexample, unknown/dynamic case, and relevant branch/merge case.
- [ ] Port each rule as an FAQL 4 query; give the two A04 sources distinct IDs and `a04_informative_images_labeled` as their common public ID.
- [ ] Regenerate the single bundle and test catalog indexes by query ID, rule ID, and mode.
- [ ] Run `dart test test/rules test/query`, then commit `feat: port conservative FAQL 4 rules`.

### Task 4: Port expanded rules and make mode visible

**Files:**
- Modify: `lib/rules/a02_avoid_redundant_role_words.faql`, `a06_merge_multi_part_single_concept.faql`, `a07_replace_semantics_cleanly.faql`, `a09_numeric_values_require_units.faql`, `a13_single_role_composite_control.faql`, `a15_map_custom_gestures_to_on_tap.faql`
- Modify: `lib/rules/faql_rule_runner.dart`, `bin/a11y.dart`, generated bundle
- Test: `test/rules/expanded_rules_test.dart`, `test/rules/faql_rule_runner_test.dart`

**Interfaces:**
- Consumes expanded facts and compiled query mode.
- Produces diagnostics that retain query identity and make heuristic provenance inspectable in JSON/SARIF output where available.

- [ ] Write failing tests proving expanded queries are excluded from the default conservative runner and included only when explicitly requested.
- [ ] Port each listed query with `@mode expanded`; retain only evidence-backed heuristic predicates.
- [ ] Regenerate the bundle, run the expanded fixtures, and commit `feat: add expanded FAQL 4 rules`.

### Task 5: Remove the retired implementation and complete migration verification

**Files:**
- Delete: `lib/src/faql/`, remaining legacy `.faql` source syntax, and obsolete debug tools.
- Modify: public exports, CLI validation/listing/showing behavior, README, migration documentation, and tests.
- Test: full repository test suite.

**Interfaces:**
- Produces a single FAQL 4 public rule-loading API and one generated bundle.

- [ ] Write failing CLI/catalog tests that reject selector/`ensure` source with a FAQL 4 validation error and accept a custom FAQL 4 directory.
- [ ] Delete the legacy engine only after the replacement test passes; ensure custom rules have a migration error rather than silent fallback.
- [ ] Run `dart pub get`, formatting check, `dart analyze`, `dart test`, and regenerate rules followed by `git diff --exit-code`.
- [ ] Compare legacy fixtures with conservative output and document intentional changes caused by explicit unknown/visibility semantics.
- [ ] Commit `refactor: remove legacy FAQL engine`.

## Completion audit

- Every query source and the generated bundle parse with the FAQL 4 compiler.
- The catalog retains both A04 query IDs and reports the shared public ID.
- No code path imports `semantic_faql_adapter.dart` or `lib/src/faql/`.
- Repository-wide format, analysis, and test commands pass from a clean checkout.
