# Typed Accessibility Fact Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace ad-hoc semantic fact payloads and overloaded IR booleans with a typed, evidence-carrying accessibility model that FAQL can project safely.

**Architecture:** Preserve the existing source widget graph and semantic composition graph, then add a separate accessibility approximation and typed fact families. The legacy fact projection and bridge remain until each migrated query has equivalent coverage.

**Tech Stack:** Dart analyzer, Flutter widget-test semantics API, FAQL 4 Core.

**Spec:** `doc/docs/faql4_core_design.md` plus the user-provided typed-fact architecture proposal.

## Global Constraints

- Conservative findings require complete exact/safely-derived premises; unknown and dynamic evidence suppress them.
- Preserve full `BranchPath` compatibility in every graph, derivation, traversal, and aggregate.
- Runtime fixtures validate documented Flutter framework contracts only; no layout, timing, arbitrary data flow, or screen-reader-output inference.
- Do not delete legacy FAQL or bridge code until equivalent replacement coverage passes.
- Existing dirty legacy rule edits are migration reference material and must not be staged accidentally.

## Review Focus

- An offstage node stays semantically/focus independently unknown or exposed as documented; it is never automatically excluded.
- Dynamic Semantics arguments never become positive or negative definite facts.
- A derived fact retains source/derivation references and never upgrades heuristic input to exact.
- Merge/replacement/exclusion never make unrelated children names or actions available.
- Branch-incompatible nodes cannot jointly satisfy an action, relationship, or aggregate predicate.

---

### Task 1: Typed evidence substrate

**Files:** create `lib/src/facts/model/{evidence,structure_facts,composition_facts,naming_facts,role_action_facts,state_facts,exposure_facts}.dart`; modify `lib/src/facts/fact_store.dart`, `lib/src/facts/semantic_fact_extractor.dart`; test `test/facts/typed_fact_model_test.dart`.

**Produces:** `FactEvidence`, typed knowledge/provenance, source spans, derivation input references, and typed fact records; `SemanticFact` becomes an FAQL projection.

- [ ] Write failing evidence/provenance and branch tests.
- [ ] Implement immutable typed models and projection compatibility.
- [ ] Run focused fact tests and commit `feat: add typed fact evidence model`.

### Task 2: Separate semantic composition and accessibility approximation

**Files:** create `lib/src/accessibility/{accessibility_node,accessibility_tree,traversal_graph}.dart`; modify semantic builder/tree and extractor; test `test/accessibility/`.

**Produces:** physical semantic composition separate from conservative emitted accessibility nodes and explicit traversal relationships.

- [ ] Write failing replacement, merge, and source-slot separation tests.
- [ ] Build accessibility approximation from composition states without inferring traversal order.
- [ ] Run focused semantics/accessibility tests and commit.

### Task 3: Typed action and role/state vocabulary

**Files:** modify known-semantics metadata, semantic nodes/builders, fact models/extractor, stdlib; test facts/query/runtime fixtures.

**Produces:** `ActionKind → ActionAvailability`, expanded normalized roles, and typed control states.

- [ ] Write failing literal/dynamic action and state tests.
- [ ] Implement explicit-Semantics and verified-framework mappings.
- [ ] Run focused tests and commit.

### Task 4: Exposure and visibility correction

**Files:** modify exposure models/extractor/stdlib; add `test_flutter/exposure_runtime_test.dart`; update fact/query tests.

**Produces:** separate visual visibility, hit-test, semantic inclusion, and accessibility-focus exposure facts.

- [ ] Add runtime contract fixtures for Offstage, Visibility, ExcludeSemantics, replacement, and focus blocking.
- [ ] Write failing static-model tests for each independent state.
- [ ] Implement mappings, run Dart/Flutter tests, and commit.

### Task 5: Names, values, input, and form facts

**Files:** modify naming/state models, semantic builder/extractor, known widget schema and stdlib; tests in facts/query.

**Produces:** label/value/hint/tooltip/range/input/validation facts with local versus effective-name separation.

- [ ] Add failing static/dynamic/unknown tests.
- [ ] Implement literal and safely-derived extraction only.
- [ ] Run focused tests and commit.

### Task 6: Explicit semantic relationships

**Files:** modify fact models/extractor/accessibility graph/stdlib; tests in facts/query.

**Produces:** controls-node IDs, traversal IDs, list/group context, and only proven static associations.

- [ ] Add failing relationship and branch-compatibility tests.
- [ ] Implement source-literal relationship extraction and indexes.
- [ ] Run focused tests and commit.

### Task 7: Typed FAQL projection and rule migration gates

**Files:** modify FAQL standard library/compiler/evaluator and rule tests.

**Produces:** standard-library predicates backed solely by typed facts, safe-negation completeness metadata, and migration matrices for every rule.

- [ ] Add validator/evaluator tests for typed actions/states/exposure predicates.
- [ ] Replace adapter-only predicates only after matching fact coverage exists.
- [ ] Regenerate Core bundle, run full Dart/Flutter gates, and commit.

### Task 8: Legacy retirement

**Files:** legacy FAQL/bridge/generated artifacts and migration documentation.

**Produces:** deletion only after all replacement rules and custom-rule migration tests pass.

- [ ] Verify parity/change matrix and custom-rule errors.
- [ ] Remove obsolete code and stale bundles.
- [ ] Run `flutter pub get`, format, analyze, Dart tests, Flutter tests, and commit.
