# Flutter A11y Lints

A semantic IR-based accessibility analyzer for Flutter applications that provides deep, contextual accessibility analysis.

## Overview

Unlike simple AST-based linters, this analyzer builds a **semantic tree** that understands the accessibility semantics of your Flutter widget tree, enabling more accurate and context-aware accessibility checks.

### Why Semantic IR?

- **Context-aware analysis**: Understands widget composition and semantic relationships
- **Accurate label detection**: Derives effective labels from Text children, tooltips, and Semantics widgets
- **Merging semantics**: Correctly handles `MergeSemantics` and semantic exclusion
- **Enabled state tracking**: Only flags controls that are actually interactive
- **High confidence**: Deep analysis eliminates common heuristic-based false alarms

## Installation

Add to your `dev_dependencies`:

```yaml
dev_dependencies:
  flutter_a11y_lints: ^0.0.1
```

Then run:

```bash
dart pub get
```

## Usage

### Command Line

Analyze a single file:

```bash
dart run flutter_a11y_lints:analyze lib/main.dart
```

Analyze a directory:

```bash
dart run flutter_a11y_lints:analyze lib/
```

### From Project Root

If you have the package locally:

```bash
dart run bin/a11y.dart lib/
```

### Output Example

```text
Flutter A11y Semantic Analyzer
==============================
Analyzing: lib/

Analyzing: main.dart
Found 3 accessibility issue(s):

WARNING: Interactive iconButton must have an accessible label
  at lib/main.dart:50:13
  Add a tooltip, Text child, or Semantics label

WARNING: Label contains redundant role words: button
  at lib/main.dart:85:15
  Remove words like "button", "icon" from label - the role is announced automatically

WARNING: Interactive control has multiple semantic parts
  at lib/main.dart:120:9
  Use MergeSemantics to combine icon and text into a single announcement
```

## Implemented Rules

### A01: Unlabeled Interactive Controls

**Rule ID**: `a01_unlabeled_interactive`  
**Severity**: WARNING

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

---

### A02: Avoid Redundant Role Words

**Rule ID**: `a02_avoid_redundant_role_words`  
**Severity**: WARNING

Don't include words like "button", "icon", "selected" in labels that are already announced by the widget's semantic role.

#### ❌ Bad

```dart
IconButton(
  tooltip: 'Save button',  // "button" is redundant
  icon: Icon(Icons.save),
  onPressed: onSave,
)

ElevatedButton(
  onPressed: onSubmit,
  child: Text('Submit button'),  // "button" is redundant
)
```

#### ✅ Good

```dart
IconButton(
  tooltip: 'Save',  // Role announced automatically
  icon: Icon(Icons.save),
  onPressed: onSave,
)

ElevatedButton(
  onPressed: onSubmit,
  child: Text('Submit'),  // Clean label
)
```

**Screen Reader Output**:
- Bad: "Save button, button" (redundant)
- Good: "Save, button" (clean)

---

### A06: Merge Multi-Part Single Concept

**Rule ID**: `a06_merge_multi_part_single_concept`  
**Severity**: WARNING

Use `MergeSemantics` for composite values/controls that should be announced as one unit (e.g., icon + text).

#### ❌ Bad

```dart
InkWell(
  onTap: save,
  child: Row(
    children: [
      Icon(Icons.save),  // Announced separately
      Text('Save'),      // Announced separately
    ],
  ),
)
// Screen reader: "save icon" → swipe → "Save text"
```

#### ✅ Good

```dart
MergeSemantics(
  child: InkWell(
    onTap: save,
    child: Row(
      children: [
        Icon(Icons.save),
        Text('Save'),
      ],
    ),
  ),
)
// Screen reader: "Save, button" (single announcement)
```

---

### A07: Replace Semantics Cleanly

**Rule ID**: `a07_replace_semantics_cleanly`  
**Severity**: WARNING

When providing a custom semantic label, wrap children in `ExcludeSemantics` to prevent double announcements.

#### ❌ Bad

```dart
Semantics(
  label: 'Score: 72 points, up 2',
  child: Row(
    children: [
      Text('72'),           // Also announced
      Icon(Icons.trending_up),
      Text('+2'),           // Also announced
    ],
  ),
)
// Announces: "Score 72 points up 2, 72, trending up, +2" (confusing!)
```

#### ✅ Good

```dart
Semantics(
  label: 'Score: 72 points, up 2',
  child: ExcludeSemantics(  // Children excluded
    child: Row(
      children: [
        Text('72'),
        Icon(Icons.trending_up),
        Text('+2'),
      ],
    ),
  ),
)
// Announces: "Score 72 points up 2" (once, clear)
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
    dart run bin/a11y.dart ../your_app/lib/
```

### Pre-commit Hook

```bash
#!/bin/bash
cd semantic_ir_linter
dart run bin/a11y.dart ../your_app/lib/
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
flutter_a11y_lints/
├── bin/
│   └── a11y.dart                    # CLI entry point
├── lib/
│   ├── flutter_a11y_lints.dart       # Public API
│   └── src/
│       ├── pipeline/                  # Widget → Semantic builders
│       ├── semantics/                 # Core semantic IR types
│       ├── rules/                     # Accessibility rules (A01, A02, A06, A07)
│       └── utils/                     # Helper utilities
├── data/
│   └── known_semantics_v2.6.json     # Widget metadata
├── test/
│   └── integration_test.dart         # Integration tests
└── README.md
```

## Future Enhancements

- [x] Core semantic IR pipeline
- [x] Rules: A01, A02, A06, A07
- [ ] Additional rules (A03, A04, A05, A08, A21)
- [ ] JSON/SARIF output formats for tooling integration
- [ ] Watch mode for continuous analysis
- [ ] Language server protocol (LSP) for IDE integration
- [ ] Quick fixes and auto-corrections
- [ ] Configuration file support
- [ ] pub.dev executable for `dart run flutter_a11y_lints:analyze`

## Related Documentation

- [Semantic IR Architecture](docs/semantic_ir_architecture.md)
- [Accessibility Rules Reference](docs/accessibility_rules_reference.md)
- [Implementation Summary](docs/IMPLEMENTATION_SUMMARY.md)
- [Flutter Accessibility Guide](https://docs.flutter.dev/development/accessibility-and-localization/accessibility)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)

## License

MIT License - See [LICENSE](LICENSE) file for details.

## Contributing

Contributions welcome! Please:

1. Check existing issues or create a new one
2. Fork the repository
3. Create a feature branch
4. Add tests for new rules
5. Submit a pull request

See [docs/accessibility_rules_reference.md](docs/accessibility_rules_reference.md) for rule development guidelines.

