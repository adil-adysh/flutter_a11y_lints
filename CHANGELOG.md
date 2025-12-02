# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2025-12-02

### Added (0.3.0)

- **Rule A03** Decorative images must be excluded when they are purely ornamental.
- **Rule A04** Informative images in avatars/ListTile leading slots now require labels.
- **Rule A05** Guards against redundant `Semantics` wrappers on material buttons.
- **Rule A18** Detects hidden focus traps created via `Offstage`/`Visibility`.
- **Rule A21** Enforces `IconButton.tooltip` usage instead of wrapping with `Tooltip`.
- **Rule A22** Prevents `MergeSemantics` from collapsing ListTile-family widgets.
- Expanded example app with guided sections that demonstrate each lint's failure and fix.

### Changed (0.3.0)

- Reworked **Rule A02** to only inspect text for interactive widgets and ignore legitimate content labels, reducing false positives on plain text.
- CLI output now surfaces all new rule identifiers so violations appear in `a11y` runs.
- Test harness expanded to cover every new rule plus the updated A02 scenarios.

### Fixed (0.3.0)

- Hidden-focus widgets in the test fixture now reflect real-world violation patterns, ensuring the semantic IR pipeline produces the right flags for A18.
- Example content now distinguishes decorative vs informative assets to avoid ambiguous samples when validating A03/A04.

## [0.1.0] - 2025-12-02

### Added (0.1.0)

- Initial release of semantic IR-based accessibility analyzer
- CLI tool `a11y` for analyzing Flutter projects
- **Rule A01**: Unlabeled Interactive Controls - detects interactive widgets without accessible labels
- **Rule A02**: Avoid Redundant Role Words - flags labels with redundant words like "button"
- **Rule A06**: Merge Multi-Part Single Concept - detects controls that should use MergeSemantics
- **Rule A07**: Replace Semantics Cleanly - ensures ExcludeSemantics is used when replacing labels
- Full type resolution using analyzer package's AnalysisContextCollection
- Semantic IR pipeline: AST → WidgetNode → SemanticNode → SemanticTree
- KnownSemantics metadata for 50+ Flutter widgets
- Integration test suite (10 tests covering all rules)
- Comprehensive documentation and examples

### Features (0.1.0)

- **Easy to use**: Simple `a11y lib/` command
- **High confidence**: Uses full type resolution, not heuristics
- **Real-world tested**: Successfully analyzes actual Flutter projects
- **CI/CD ready**: Exit codes and parseable output
- **Fast**: Analyzes typical Flutter projects in seconds

## [0.2.1] - 2025-12-02

### Changed (0.2.1)

- Upgrade compatibility for Dart 3.9.x resolver ecosystem
- Bump dependencies: analyzer ^9.0.0, meta ^1.17.0, path ^1.9.0
- Dev deps: lints ^6.0.0, test ^1.27.0
- SDK constraint: '>=3.5.0 <4.0.0'

### Fixed (0.2.1)

- Reduce dependency solver conflicts when used alongside modern Flutter apps
- Expose `a11y` executable for global activation (`dart pub global activate flutter_a11y_lints`)

[0.3.0]: https://github.com/adil-adysh/flutter_a11y_lints/releases/tag/v0.3.0
[0.2.1]: https://github.com/adil-adysh/flutter_a11y_lints/releases/tag/v0.2.1
[0.1.0]: https://github.com/adil-adysh/flutter_a11y_lints/releases/tag/v0.1.0
