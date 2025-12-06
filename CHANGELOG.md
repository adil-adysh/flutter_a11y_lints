# Changelog

## 0.6.0

**The FAQL Integration Release**
This release fully integrates the FAQL engine into the linter, migrating core rules to the declarative format and significantly expanding CLI capabilities for developers and CI pipelines.

### New

- **FAQL Engine Integration:** Implemented the `FaqlRuleRunner` and Grammar Adaptor, bridging the FAQL parser with the linter's semantic analysis pipeline.
- **Rule Migration:** Migrated 11 core accessibility rules (A02–A07, A09, A13, A15, A21, A22) from legacy Dart implementations to `.faql` definitions.
- **Multi-Rule Support:** Added support for defining multiple accessibility rules within a single `.faql` file for better organization.
- **CLI Enhancements:**
  - **Pipeline Control:** Added `--fail-on-warnings` (or `--fail`) to force strict exit codes in CI/CD.
  - **Output Formats:** Introduced `--reporter` with support for `console`, `json`, and `machine` formats.
  - **Custom Rules:** Added `--rules-dir` to load custom `.faql` rules from a local directory.
  - **Developer Tools:** Added `--list-rules`, `--show-rule`, `--validate-faql` (syntax check), and `--init` (generate starter config).
  - **Filtering:** Added `--exclude` to skip specific files (defaults to generated files) and flags to run specific engines (`--faql-only`, `--dart-only`).

### Improved

- **Cleanup:** Removed Windows-specific CMake configurations and test runners to streamline the package structure.
- **Performance:** Refactored the FAQL AST to use enums and cached expression parsers for faster rule evaluation.

## 0.5.0

**The Foundation Release**
This release established the theoretical groundwork and core infrastructure for the Flutter Accessibility Query Language.

### New

- **FAQL Specification:** Published the comprehensive "Flutter Accessibility Query Language" specification and implementation guide.
- **Parser & Interpreter:** Implemented the core FAQL parser, including string literal handling, precompiled regex support, and the strict interpreter logic.
- **Test Infrastructure:** Reorganized the test suite to support the new language architecture, adding dedicated tests for the parser and interpreter components.

### Improved

- **Semantic Schema:** Enhanced the underlying semantic tree to support the granular attribute extraction required by the FAQL specification.

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
