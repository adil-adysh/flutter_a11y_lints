# Agent guide: flutter_a11y_lints

## Project and source of truth

This is a Dart static analyzer for Flutter accessibility. The current pipeline parses Dart, builds a widget tree, synthesizes Semantic IR, and runs FAQL rules. Read the implementation before assuming an older design note describes current behavior.

- `README.md`: user-facing usage.
- `lib/src/widget_tree/`: source-derived widgets, named slots, and conditional branches.
- `lib/src/semantics/`: known widget semantics, semantic synthesis, and tree relationships.
- `lib/src/faql/` and `lib/src/bridge/`: current FAQL parser, validator, evaluator, and Semantic IR adapter.
- `lib/rules/`: current rule sources, catalog, runner, and generated bundles.
- `test/faql/`, `test/semantics/`, `test/rules/`: focused tests.
- `doc/docs/faql4_core_design.md`: **proposed** next architecture and migration sequence. Its example query syntax, fact store, views, and directory layout are not implemented APIs.
- Other files in `doc/docs/` may describe earlier designs. Resolve conflicts against the current code and the explicit proposal above; flag material uncertainty.

## Design constraints

Prioritize justified accessibility findings over rule count. Static analysis cannot establish rendered layout, actual assistive-technology announcements, runtime state changes, or arbitrary user intent.

- Keep unknown separate from proven absence. A missing positive fact is not proof of a negative fact.
- Treat source widget edges, named slots, and semantic tree edges as different relationships.
- Do not equate absence from the accessibility focus list with hidden content.
- Preserve mutually exclusive conditional branches; never count facts from incompatible branches together.
- Track where facts came from: exact, safely derived, or heuristic. Keep rule confidence separate from fact provenance.
- Conservative findings require proven premises. Keep contextual judgments and guesses in expanded/heuristic mode with clear wording.
- Prefer general typed facts and reusable predicates over rule-specific bridge getters or grammar additions.
- Do not claim that a custom widget has known semantics when its implementation or relevant behavior is unresolved.
- Give multiple queries distinct internal identities even when they report the same public rule ID.
- Verify Flutter behavior for semantics-sensitive changes; the model is an approximation of runtime semantics.

## Working in this repository

1. Inspect the nearby implementation, relevant tests, and any existing rule before editing. Keep changes scoped to the request.
2. For a new or revised rule, write down the user-facing barrier, proof obligations, uncertainty, and why the diagnostic is actionable.
3. Test one positive case, one valid counterexample, and an unknown/dynamic case where applicable. Include branch/merge cases when relevant. Avoid tests that merely repeat implementation details.
4. When modifying fact extraction, test facts independently of query evaluation; when modifying queries, compare their findings against the existing rule behavior and explain any change.
5. Keep `.faql` sources and generated bundles consistent. Inspect `tool/generate_rules.dart` and the catalog's actual import path before regenerating; there is existing path drift. Do not edit generated files by hand as a substitute for fixing generation.
6. Do not refactor the project into the proposed FAQL 4 layout just to satisfy documentation. Follow the staged migration in the design.

## Verification

Run the narrowest relevant checks during development, then the appropriate repository-wide checks before claiming a code change is complete:

```sh
dart pub get
dart format --output=none --set-exit-if-changed lib test tool
dart analyze
dart test
```

If a check cannot run in the environment, state that plainly. For documentation-only changes, verify paths, links, Markdown structure, and the Git diff; Dart tests are unnecessary unless executable files changed.

## Communication

Use precise distinctions: **implemented**, **proposed**, **proven**, **derived**, and **heuristic**. Explain any changed findings or remaining uncertainty. Accessibility guidance and examples should read clearly in a linear screen-reader reading order; avoid relying on diagrams or color alone.
