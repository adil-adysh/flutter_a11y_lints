# Agent guide: flutter_a11y_lints

## Project and source of truth

This is a Dart static analyzer for Flutter accessibility. The current pipeline parses Dart, builds a widget tree, synthesizes Semantic IR, and runs FAQL rules. Read the implementation before assuming an older design note describes current behavior.

- `README.md`: user-facing usage.
- `lib/src/widget_tree/`: source-derived widgets, named slots, and conditional branches.
- `lib/src/semantics/`: known widget semantics, semantic synthesis, and tree relationships.
- `lib/src/query/`: in-progress FAQL 4 Core parser, compiler, standard library, and evaluator.
- `lib/src/faql/` and `lib/src/bridge/`: temporary legacy parser, evaluator, and Semantic IR adapter retained for migration parity.
- `lib/rules/`: current rule sources, catalog, runner, and generated bundles.
- `test/faql/`, `test/semantics/`, `test/rules/`: focused tests.
- `test_flutter/`: focused runtime contract fixtures against Flutter's real
  semantics tree.
- `doc/docs/faql4_core_design.md`: target architecture and migration contract. Some facts and Core compiler pieces are implemented; bundled rules are not yet migrated.
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

## Runtime-evidence workflow

Flutter runtime tests are a bounded oracle for known framework behavior, not
runtime input to the analyzer. They can establish how a documented Flutter
constructor composes semantics; they cannot establish application-specific
state, custom-widget behavior, rendered layout, timing, or what a screen
reader will announce on a user's device.

For a semantics-sensitive modeling decision, work through this evidence chain:

1. Identify the relevant official Flutter contract and its exact scope.
2. Add a minimal fixture under `test_flutter/` that observes that contract in
   the supported Flutter SDK.
3. Encode only the observed, documented contract in Semantic IR and fact tests.
4. Let a conservative FAQL rule use the resulting fact only when its source
   premises are complete and proven.

Keep facts `unknown` when source behavior is dynamic, custom, version-sensitive,
ambiguous, or outside the runtime fixture's scope. In particular, never infer
hidden content from its absence in focus traversal, or a child's effective name
solely from an ancestor label. A runtime contract confirms framework behavior;
the analyzer remains source-based and must not imagine program-specific facts.

Every new runtime fixture must include a reviewable decision record adjacent to
the fixture:

```dart
// Runtime contract: ...
// IR mapping: ...
// Conservative consequence: ...
// Deliberate unknown boundary: ...
```

### Flutter contract-test starter

Use a narrow observable assertion and always dispose the semantics handle:

```dart
testWidgets('ExcludeSemantics removes its child from traversal', (tester) async {
  // Runtime contract: ExcludeSemantics(excluding: true) excludes child semantics.
  // IR mapping: descendantReplacement is excluded for this known widget.
  // Conservative consequence: rules may use only the explicit exclusion fact.
  // Deliberate unknown boundary: custom exclusion widgets remain unknown.
  final handle = tester.ensureSemantics();
  try {
    await tester.pumpWidget(
      const MaterialApp(
        home: ExcludeSemantics(
          child: Semantics(label: 'Private detail'),
        ),
      ),
    );

    final labels = tester.semantics
        .simulatedAccessibilityTraversal()
        .map((node) => node.label);
    expect(labels, isNot(contains('Private detail')));
  } finally {
    handle.dispose();
  }
});
```

Run runtime contracts separately with:

```sh
flutter test test_flutter/
```

### Static-model starter

After the runtime contract is established, test source modeling independently
before adding a rule fixture. Use the repository's test helpers and assert the
IR state, fact value, provenance, and unknown boundary directly:

```dart
final tree = await buildTestSemanticTree('''
  ExcludeSemantics(child: Semantics(label: 'Private detail'))
''');
final facts = SemanticFactExtractor().extract(tree);
final node = tree.root;
final exclusionFact = facts.store.conservative
    .factsFor(node.id!)
    .singleWhere((fact) => fact.name == 'isDefinitelyExcludingDescendants');

expect(node.descendantReplacement, DescendantReplacementState.excluded);
expect(exclusionFact.value, isTrue);
expect(exclusionFact.provenance, FactProvenance.exact);

final dynamicTree = await buildTestSemanticTree(
  'ExcludeSemantics(excluding: purchasePending, child: const Text("Private"))',
);
expect(
  dynamicTree.root.descendantReplacement,
  DescendantReplacementState.unknown,
);
```

Adapt the fact accessors and enum names to the nearby implementation rather
than adding a test-only abstraction. Add a rule fixture only after this fact
contract passes; the rule test should prove a violation, valid counterexample,
and relevant unknown and branch cases.

## Working in this repository

1. Inspect the nearby implementation, relevant tests, and any existing rule before editing. Keep changes scoped to the request.
2. For a new or revised rule, write down the user-facing barrier, proof obligations, uncertainty, and why the diagnostic is actionable.
3. Test one positive case, one valid counterexample, and an unknown/dynamic case where applicable. Include branch/merge cases when relevant. Avoid tests that merely repeat implementation details.
4. When modifying fact extraction, test facts independently of query evaluation; when modifying queries, compare their findings against the existing rule behavior and explain any change.
5. Keep `.faql` sources and generated bundles consistent. Inspect `tool/generate_rules.dart` and the catalog's actual import path before regenerating; there is existing path drift. Do not edit generated files by hand as a substitute for fixing generation.
6. Do not refactor the project into the proposed FAQL 4 layout just to satisfy documentation. Follow the staged migration in the design.

## FAQL 4 migration status

- Typed facts, a branch-safe FAQL 4 Core compiler, and the Core evaluator are
  implemented. Core predicates evaluate typed node facts only; serialized
  `SemanticFact(name, value)` records are diagnostic compatibility output.
  Source-derived `BranchPath` propagation is proven through WidgetTree,
  Semantic IR, fact graphs, relationships, `exists`, and `count`.
- `lib/rules/builtin_faql_rules.g.dart` is the canonical generated Core bundle.
  It contains only the approved migrated conservative queries. Legacy `.faql`
  files, `lib/src/faql/`, and the bridge remain parity references for rules not
  yet replaced.
- Do not regenerate from legacy sources, delete legacy code before each
  replacement rule has passing proof fixtures, or claim branch safety from
  scalar `branchGroupId`/`branchValue` metadata.

## Verification

Run the narrowest relevant checks during development, then the appropriate repository-wide checks before claiming a code change is complete:

```sh
dart pub get
dart format --output=none --set-exit-if-changed lib test tool
dart analyze
dart test
```

For a change that models Flutter runtime semantics, also run `flutter pub get`
and `flutter test test_flutter/`. Keep those runtime checks separate from
`dart test` so a framework-contract failure is distinguishable from a
source-model or rule failure.

If a check cannot run in the environment, state that plainly. For documentation-only changes, verify paths, links, Markdown structure, and the Git diff; Dart tests are unnecessary unless executable files changed.

## Communication

Use precise distinctions: **implemented**, **proposed**, **proven**, **derived**, and **heuristic**. Explain any changed findings or remaining uncertainty. Accessibility guidance and examples should read clearly in a linear screen-reader reading order; avoid relying on diagrams or color alone.
