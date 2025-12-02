# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-12-02

### Added
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

### Features
- **Easy to use**: Simple `a11y lib/` command
- **High confidence**: Uses full type resolution, not heuristics
- **Real-world tested**: Successfully analyzes actual Flutter projects
- **CI/CD ready**: Exit codes and parseable output
- **Fast**: Analyzes typical Flutter projects in seconds

[0.1.0]: https://github.com/adil-adysh/flutter_a11y_lints/releases/tag/v0.1.0

## [0.2.1] - 2025-12-02

### Changed
- Upgrade compatibility for Dart 3.9.x resolver ecosystem
- Bump dependencies: analyzer ^9.0.0, meta ^1.17.0, path ^1.9.0
- Dev deps: lints ^6.0.0, test ^1.27.0
- SDK constraint: '>=3.5.0 <4.0.0'

### Fixed
- Reduce dependency solver conflicts when used alongside modern Flutter apps
- Expose `a11y` executable for global activation (`dart pub global activate flutter_a11y_lints`)

[0.2.1]: https://github.com/adil-adysh/flutter_a11y_lints/releases/tag/v0.2.1
