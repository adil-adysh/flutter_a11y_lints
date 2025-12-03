# GitHub Copilot Instructions for flutter_a11y_lints

## TL;DR for Copilot

- This repo is a **standalone semantic IR analyzer**, not a `custom_lint` plugin. Entry points are `bin/a11y.dart` (CLI) and `lib/flutter_a11y_lints.dart` (library export).
- Core pipeline: build `WidgetNode` trees → convert to `SemanticNode` IR → run rule sweeps that return violation objects.
- Rules live under `lib/src/rules/`. Each rule exposes static metadata, pure helper methods, and a `checkTree(SemanticTree tree)` that returns typed violations.
- Tests are hand-written in `test/rules/*.dart` plus semantic tree utilities in `test/semantics/`. Running `dart test` from repo root is the canonical verification path.
- Structured documentation for reasoning lives in `doc/docs/*.md`. Reach for those before re-deriving architecture.

## Architecture Snapshot

| Layer | Implementation hints |
| --- | --- |
| CLI runner | `bin/a11y.dart` wires analyzer contexts, filters Flutter units via `fileUsesFlutter`, builds trees per build method, runs every rule, and prints friendly diagnostics. Keep CLI output human-readable, not IDE-formatted. |
| Widget tree | `lib/src/widget_tree/widget_tree_builder.dart` walks resolved AST (supports conditionals, spreads, loops). Use `WidgetNode.branchGroupId` to avoid double counting mutually exclusive branches. |
| Semantic IR | `lib/src/semantics/semantic_builder.dart`, `semantic_node.dart`, `semantic_tree.dart`. The builder consults `KnownSemanticsRepository` (data JSON under `data/known_semantics_v2.6.json`). Nodes expose accessibility traits (role, controlKind, labels, gestures, boundaries). |
| Rules | Each rule inspects the semantic tree to enforce a WCAG-inspired heuristic. They should not touch analyzer directly—only semantic IR. |

Keep the IR deterministic: no async, no analyzer queries inside rules. All heavy lifting belongs to the builders.

## Creating or Updating Rules

1. **Pick a slot:** add a new file under `lib/src/rules/` with name `aXX_description.dart`. Export it from `lib/flutter_a11y_lints.dart` and invoke it inside `FlutterA11yAnalyzer._analyzeFile` in `bin/a11y.dart`. Rules should remain stateless.
2. **Structure:**
   ```dart
   import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
   import 'package:flutter_a11y_lints/src/semantics/semantic_tree.dart';

   class A99MyRule {
     static const code = 'a99_my_rule';
     static const message = 'Short human warning';
     static const correctionMessage = 'Actionable remediation';

     static List<A99Violation> checkTree(SemanticTree tree) {
       final hits = <A99Violation>[];
       for (final node in tree.accessibilityFocusNodes) {
         if (_violates(node)) {
           hits.add(A99Violation(node: node));
         }
       }
       return hits;
     }

     static bool _violates(SemanticNode node) {
       // pure logic only
       return node.isEnabled && node.labelGuarantee == LabelGuarantee.none;
     }
   }

   class A99Violation {
     const A99Violation({required this.node});
     final SemanticNode node;
   }
   ```
   - Use helper getters like `SemanticNode.effectiveLabel`, `node.controlKind`, or group metadata provided by the builder.
   - Never mutate `SemanticNode` instances. Clone only with `copyWith` during builder phases, not in rules.
3. **Reporting:** Convert violations to `A11yIssue` inside `FlutterA11yAnalyzer._analyzeFile`. Keep severity as `'warning'` unless the rule is guaranteed to be fatal.

## Testing New Rules

- Place tests under `test/rules/`, mirroring the rule filename (e.g., `a01_unlabeled_interactive_test.dart`).
- Tests generally:
  1. Build sample widget trees using helper builders in `test/semantics/semantic_builder_test.dart` or inline semantic nodes.
  2. Call `Rule.checkTree(tree)` and assert on number/content of violations.
- Use `dart test` from repo root. When targeting a single file use `dart test test/rules/a01_unlabeled_interactive_test.dart`.
- Fixtures that resemble real Flutter projects live under `test/unit_test_assets/`. Prefer building trees programmatically before reaching for disk fixtures.

## Key Data & Utilities

- `data/known_semantics_v2.6.json`: authoritative catalogue of widget semantics. Update via the documented generator before hand editing. Keep schema unchanged (see `lib/src/semantics/known_semantics.dart`).
- `lib/src/utils/flutter_utils.dart`: minimal Flutter detection (string match). Extend only if analyzer API access is necessary.
- `lib/src/utils/method_utils.dart`: `findBuildMethods` and `extractBuildBodyExpression`. When adjusting, ensure they still capture function-body expressions and block returns.
- `lib/src/widget_tree/widget_tree_builder.dart`: handles `IfElement`, `ConditionalExpression`, spreads, cascades. When adding new collection forms, respect branch grouping so rules do not flag mutually-exclusive widgets twice.

## Coding Standards & Conventions

- Imports: Dart SDK → package (`analyzer`, `path`, etc.) → relative project files. No `custom_lint_builder` imports remain in the repo.
- File encoding is ASCII (UTF-8 without BOM). Add comments sparingly—only to clarify complex heuristics.
- Rule constants (`code`, `message`, `correctionMessage`) should start with the `aXX_` identifier and contain user-facing copy ready for CLI output.
- When matching widget types rely on semantic metadata (`node.controlKind`, `node.role`) instead of stringly-typed comparisons whenever possible.
- Keep public API of `lib/flutter_a11y_lints.dart` synchronized with actual rule files so downstream users can import the analyzers programmatically.

## Extending the Architecture

- **New gestures / properties:** annotate them in `SemanticNode`, populate values in the semantic builder, and update `KnownSemanticsRepository` if the data is static per widget.
- **New output formats:** add converters in `bin/a11y.dart` (e.g., JSON/SARIF). Preserve the default human-readable report.
- **Performance:** tree building happens per `build` method; cache resolved units or known semantics but never share mutable state between analyses.
- **Docs:** when adding a rule, briefly document it in `README.md` (Implemented Rules) and, if necessary, `doc/docs/accessibility_rules_reference.md`.

## Accessibility Mindset

- Prioritize WCAG principles: perceivable, operable, understandable, robust.
- Rules should avoid false positives: check `node.isEnabled`, `node.labelGuarantee`, and ancestor semantics before warning.
- Prefer semantic-tree level fixes over raw AST to keep heuristics resilient to widget refactors.

## Reference Material

- `doc/docs/semantic_ir_architecture.md` – full stack description.
- `doc/docs/accessibility_rules_reference.md` – rule catalogue with scenarios.
- Flutter accessibility docs: <https://docs.flutter.dev/development/accessibility-and-localization/accessibility>
- WCAG 2.1 quick reference: <https://www.w3.org/WAI/WCAG21/quickref/>

Use this file as the high-level compass. Dive into the referenced source files for ground truth before implementing major changes.
