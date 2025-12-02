# Flutter A11y Semantic IR Analyzer

A standalone accessibility analyzer for Flutter applications using semantic intermediate representation (IR) for deep, contextual accessibility analysis.

## Overview

Unlike simple AST-based linters, this analyzer builds a **semantic tree** that understands the accessibility semantics of your Flutter widget tree, enabling more accurate and context-aware accessibility checks.

### Why Semantic IR?

- **Context-aware analysis**: Understands widget composition and semantic relationships
- **Accurate label detection**: Derives effective labels from Text children, tooltips, and Semantics widgets
- **Merging semantics**: Correctly handles `MergeSemantics` and semantic exclusion
- **Enabled state tracking**: Only flags controls that are actually interactive
- **Zero false positives**: Deep analysis eliminates common heuristic-based false alarms

## Installation

### As a standalone tool

From the repository root:
```bash
cd semantic_ir_linter
dart pub get
```

## Usage

### Command Line

Analyze a single file:
```bash
dart run bin/flutter_a11y_analyzer.dart lib/main.dart
```

Analyze a directory:
```bash
dart run bin/flutter_a11y_analyzer.dart lib/
```

### Output Example

```
Flutter A11y Semantic Analyzer
==============================
Analyzing: lib/

Analyzing: main.dart
Found 2 accessibility issue(s):

WARNING: Interactive iconButton must have an accessible label
  at lib/main.dart:50:13
  Add a tooltip, Text child, or Semantics label

WARNING: Interactive iconButton must have an accessible label
  at lib/main.dart:296:22
  Add a tooltip, Text child, or Semantics label
```

## Rules

### A01: Unlabeled Interactive Controls

**Rule ID**: `a01_unlabeled_interactive`

Interactive controls must expose an accessible label so screen readers can announce them properly.

#### ❌ Bad

```dart
IconButton(
  icon: Icon(Icons.add),
  onPressed: () {},
  // Missing tooltip!
)

ElevatedButton(
  onPressed: () {},
  child: Icon(Icons.save),  // Icon-only, no text!
)
```

#### ✅ Good

```dart
IconButton(
  icon: Icon(Icons.add),
  onPressed: () {},
  tooltip: 'Add item',  // ✓ Has tooltip
)

ElevatedButton(
  onPressed: () {},
  child: Text('Save'),  // ✓ Has text label
)

// Or use Semantics wrapper
Semantics(
  label: 'Save document',
  child: ElevatedButton(
    onPressed: () {},
    child: Icon(Icons.save),
  ),
)
```

## Architecture

The analyzer works in several phases:

1. **AST Parsing**: Standard Dart analyzer parses source files
2. **Widget Tree Building**: Constructs `WidgetNode` tree from AST
3. **Semantic Tree Building**: Converts to `SemanticNode` tree using KnownSemantics metadata (v2.6)
4. **Rule Execution**: Runs accessibility rules against semantic tree
5. **Reporting**: Outputs violations with file locations

### Key Components

- **KnownSemantics**: JSON metadata defining Flutter widget semantics (v2.6)
- **WidgetTreeBuilder**: Builds widget tree from expressions
- **SemanticBuilder**: Derives semantic properties and labels
- **SemanticTree**: Final IR with accessibility-focusable nodes
- **Rules**: Individual accessibility checkers

## Testing

The analyzer includes unit tests that work on real Flutter code:

```bash
dart test
```

Note: Tests require proper Flutter package resolution, so they work best when testing against actual Flutter projects rather than isolated code snippets.

## Integration with CI/CD

### GitHub Actions

```yaml
- name: Run Flutter A11y Analyzer
  run: |
    cd semantic_ir_linter
    dart pub get
    dart run bin/flutter_a11y_analyzer.dart ../your_app/lib/
```

### Pre-commit Hook

```bash
#!/bin/bash
cd semantic_ir_linter
dart run bin/flutter_a11y_analyzer.dart ../your_app/lib/
if [ $? -ne 0 ]; then
  echo "❌ Accessibility issues found. Please fix before committing."
  exit 1
fi
```

## Comparison with custom_lint

| Feature | Semantic IR Analyzer | custom_lint |
|---------|---------------------|-------------|
| Deep semantic analysis | ✅ Yes | ❌ Limited to AST |
| Label derivation | ✅ Full context | ⚠️ Heuristic |
| Standalone testing | ✅ Built-in | ⚠️ Complex |
| IDE integration | ⚠️ CLI only | ✅ Real-time |
| API stability | ✅ Self-contained | ⚠️ Breaking changes |

The semantic IR analyzer trades real-time IDE feedback for deeper, more accurate analysis with cleaner testing.

## Development

The package structure:

```text
semantic_ir_linter/
├── bin/
│   └── flutter_a11y_analyzer.dart    # CLI entry point
├── lib/
│   └── src/
│       ├── pipeline/                  # Widget → Semantic builders
│       ├── semantics/                 # Core semantic IR types
│       └── utils/                     # Helper utilities
├── data/
│   └── known_semantics_v2.6.json     # Widget metadata
├── test/
│   └── analyzer_test.dart            # Unit tests
└── README.md
```

## Future Enhancements

- [ ] More accessibility rules (A02-A08, A21)
- [ ] JSON/SARIF output formats for tooling integration
- [ ] Watch mode for continuous analysis
- [ ] Language server protocol (LSP) for IDE integration
- [ ] Quick fixes and auto-corrections
- [ ] Configuration file support

## Related Documentation

- [Semantic IR Architecture](../docs/semantic_ir_architecture.md)
- [KnownSemantics v2.6 Spec](../docs/known_semantics_v2.6.md)
- [Flutter Accessibility Guide](https://docs.flutter.dev/development/accessibility-and-localization/accessibility)

## License

MIT License - See [../LICENSE](../LICENSE) file for details.

