# Changelog

## 0.5.0

### New
- Added comprehensive documentation for the FAQL (Flutter Accessibility Query Language), including a language specification and implementation guide.
- Implemented a semantic schema for more robust extraction of accessibility attributes.

### Improved
- Enhanced CI/CD pipeline for more reliable and efficient builds.
- Added a `--fail-on-warnings` flag to the CLI for stricter linting.
- Reorganized and expanded tests for the FAQL parser and interpreter, improving test coverage.

### Refactor
- Improved code formatting and readability across the project.

## 0.4.0

### New

- Added multiple new accessibility rules for:
  - Decorative and informative images.
  - Composite and dynamic controls.
  - Numeric values, toggle states, custom gestures, and minimum tap targets.
- Improved semantic analysis accuracy using unit-aware constant evaluation.
- Expanded documentation for all lint rules with clearer guidance and examples.
- Added comprehensive tests covering composite, recursive, dynamic, and quick-path widgets.

### Improved

- More accurate widget summary synthesis and semantic tree processing.
- Enhanced label extraction and control-flow handling for complex widgets.
- Better caching of semantic summaries using stable identifiers.

### Refactor

- Simplified and centralized constant evaluation logic.
- General code quality improvements across semantic builder and tree logic.

---

## 0.3.0

### New

- Added new lint rules:
  - A03, A04, A05 — image semantics and redundant wrappers.
  - A18 — hidden focus traps.
  - A21 — tooltip guidance for IconButton.
  - A22 — ListTile semantic boundaries.
- Expanded semantic node structure with additional fields and metadata.
- Introduced `SemanticNeighborhood` and new semantic utility classes.

### Improved

- Updated A02, A06, and A07 with clearer messages and suggestions.
- Improved semantic tree builder: better handling of conditional branches and label extraction.
- Added tests for A01 and several new rule scenarios.

---

## 0.2.1

### Improved

- Dart SDK compatibility upgrades.
- Upgraded `analyzer`, `meta`, `path`, `lints`, and `test` dependencies.

### New

- Exposed `a11y` executable for global activation.

---

## 0.2.0

### Improved

- Updated pub.dev publishing requirements.
- Added `.pubignore` and prepared structure for package publishing.
- Adjusted directory naming to follow Dart conventions (`docs/` → `doc/`).

---

## 0.1.0 — First Functional Release

### New

- Introduced standalone semantic IR analyzer.
- Implemented initial lint rules: **A01**, **A02**, **A06**, **A07**.
- Added `a11y` CLI tool for running lint checks.
- All tests passing for initial analyzer pipeline.
