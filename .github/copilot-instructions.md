# GitHub Copilot Instructions for flutter_a11y_lints

## Project Overview

This is a **Flutter accessibility lints plugin** built using the `custom_lint` framework. It provides automated accessibility checks for Flutter applications to help developers build more inclusive apps.

## Project Purpose

- Enforce Flutter accessibility best practices through custom lint rules
- Detect common accessibility anti-patterns in Flutter widget trees
- Guide developers toward accessible UI implementations
- Support WCAG (Web Content Accessibility Guidelines) compliance

## Technology Stack

- **Language**: Dart
- **Framework**: custom_lint_builder (^0.8.1)
- **Analyzer**: analyzer package (^8.4.0)
- **Test Framework**: test (^1.26.3)

## Project Structure

```
lib/
├── flutter_a11y_lints.dart          # Main library export
├── src/
    ├── plugin.dart                   # Plugin entry point
    ├── rules/                        # Individual lint rule implementations
    │   ├── a01_label_non_text_controls.dart
    │   ├── a02_avoid_redundant_role_words.dart
    │   ├── a03_decorative_images_excluded.dart
    │   ├── a04_informative_images_labeled.dart
    │   ├── a05_no_redundant_button_semantics.dart
    │   ├── a06_merge_multi_part_single_concept.dart
    │   ├── a07_replace_semantics_cleanly.dart
    │   ├── a08_block_semantics_only_for_true_modals.dart
    │   └── a21_use_iconbutton_tooltip.dart
    └── utils/                        # Helper utilities
        ├── ast_utils.dart
        ├── flutter_imports.dart
        └── type_utils.dart
```

## Coding Standards

### Import Organization

1. **Always hide `LintCode` from analyzer package** to avoid conflicts:
   ```dart
   import 'package:analyzer/error/error.dart' hide LintCode;
   ```

2. Standard import order:
   - Dart SDK imports
   - Package imports (analyzer, custom_lint_builder)
   - Relative imports (utils)

### Lint Rule Implementation Pattern

Each lint rule should follow this structure:

```dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class RuleName extends DartLintRule {
  const RuleName() : super(code: _code);

  static const _code = LintCode(
    name: 'flutter_a11y_rule_name',
    problemMessage: 'Clear description of the issue',
    correctionMessage: 'Actionable fix suggestion',
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      // Rule logic here
      
      // Report errors using:
      reporter.atNode(node).report(_code);
    });
  }
}
```

### Custom Lint API Usage

- Use `context.registry` to register node visitors
- Use `await resolver.getResolvedUnitResult()` to get compilation unit
- Report errors with `reporter.atNode(node).report(code)`
- Always check `fileUsesFlutter()` before running Flutter-specific checks

### Utility Functions

Leverage the utility functions in `utils/`:
- `fileUsesFlutter(unit)` - Check if file imports Flutter
- `isType(type, package, className)` - Type checking helper
- `isIconButton()`, `isMaterialButton()`, `isSemantics()` - Widget type checks
- `hasTextChild()`, `hasCallbackArg()` - AST traversal helpers
- `getStringLiteralArg()`, `getBoolLiteralArg()` - Argument extraction

## Accessibility Rules Implemented

| Code | Rule | Description |
|------|------|-------------|
| FLA01 | Label Non-Text Controls | Interactive controls without text need tooltips/labels |
| FLA02 | Avoid Redundant Role Words | Don't use "button" in button labels |
| FLA03 | Decorative Images Excluded | Mark decorative images with excludeFromSemantics |
| FLA04 | Informative Images Labeled | Provide semantic labels for content images |
| FLA05 | No Redundant Button Semantics | Don't wrap Material buttons with redundant Semantics |
| FLA06 | Merge Multi-Part Concepts | Combine related icon+text into single semantic node |
| FLA07 | Replace Semantics Cleanly | Use excludeSemantics when providing replacement labels |
| FLA08 | Block Semantics for Modals | Only use BlockSemantics for true modal overlays |
| FLA21 | Use IconButton Tooltip | Prefer IconButton.tooltip over Tooltip wrapper |

## Testing Guidelines

- Each rule has a corresponding test file in `test/rules/`
- Test both positive (should trigger) and negative (should not trigger) cases
- Use the `custom_lint_builder` testing utilities
- Run tests with: `dart test`

## Development Workflow

1. Create rule implementation in `lib/src/rules/`
2. Add rule to plugin in `lib/src/plugin.dart`
3. Write comprehensive tests in `test/rules/`
4. Update documentation in README.md
5. Verify with the test app in `a11y_test_app/`

## Accessibility Principles

When suggesting code changes, prioritize:
- **Perceivable**: Information must be presentable to users in ways they can perceive
- **Operable**: Interface components must be operable by all users
- **Understandable**: Information and UI operation must be understandable
- **Robust**: Content must work with current and future assistive technologies

## Common Patterns to Enforce

✅ **Good**:
```dart
IconButton(
  icon: Icon(Icons.delete),
  tooltip: 'Delete item',
  onPressed: () {},
)
```

❌ **Bad**:
```dart
IconButton(
  icon: Icon(Icons.delete),
  onPressed: () {},
) // Missing tooltip
```

## References

- [Flutter Accessibility Guide](https://docs.flutter.dev/development/accessibility-and-localization/accessibility)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [custom_lint Documentation](https://pub.dev/packages/custom_lint)

## Notes for GitHub Copilot

- Prioritize accessibility in all suggestions
- Follow the established pattern for new lint rules
- Ensure proper error reporting with actionable messages
- Test changes against the `a11y_test_app` example
- Keep rule logic focused and maintainable
