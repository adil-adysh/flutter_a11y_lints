// Rule: A05 — No Redundant Button Semantics
//
// Purpose: Find Semantics wrappers applied to Material button widgets that
// redundantly re-declare the button role (e.g., `button: true`) without
// providing meaningful custom semantics. Such wrappers often cause duplicated
// announcements. The rule prefers using the button's built-in semantics or
// providing a meaningful custom label while excluding descendants.
//
// Testing: Put tests in `test/rules/a05_no_redundant_button_semantics_test.dart`.
// Use the analyzer-backed helpers to synthesize widget snippets and assert
// whether `checkTree` identifies redundant wrappers.
//
// See also:
// - `lib/src/semantics/semantic_node.dart` (child scanning and `controlKind`)
// - `lib/src/semantics/semantic_tree.dart` (iterate `physicalNodes`)
// - `lib/src/semantics/known_semantics.dart` (material button mappings)
// - `test/rules/test_semantic_utils.dart`

import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_a11y_lints/src/semantics/known_semantics.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_tree.dart';

/// A05: No redundant Semantics wrappers on Material buttons.
class A05NoRedundantButtonSemantics {
  static const code = 'a05_no_redundant_button_semantics';
  static const message = 'Remove redundant Semantics wrapper around button';
  static const correctionMessage =
      'Remove the Semantics wrapper or provide a custom label instead of button:true.';

  static const _materialControls = <ControlKind>{
    ControlKind.iconButton,
    ControlKind.elevatedButton,
    ControlKind.textButton,
    ControlKind.filledButton,
    ControlKind.outlinedButton,
    ControlKind.floatingActionButton,
  };

  static bool check(SemanticNode node) {
    if (node.widgetType != 'Semantics') return false;
    if (node.children.isEmpty) return false;
    if (node.excludesDescendants) return false;

    final creation = node.astNode;
    if (creation is! InstanceCreationExpression) return false;

    final wrapsMaterialButton = node.children.any(
      (child) => _materialControls.contains(child.controlKind),
    );
    if (!wrapsMaterialButton) return false;

    final hasMeaningfulSemantics = _hasMeaningfulSemanticsArgs(creation);
    final setsButtonTrue = _literalBoolArg(creation, 'button') == true;

    if (!setsButtonTrue && hasMeaningfulSemantics) {
      return false;
    }

    return setsButtonTrue || !hasMeaningfulSemantics;
  }

  static List<A05Violation> checkTree(SemanticTree tree) {
    final violations = <A05Violation>[];
    for (final node in tree.physicalNodes) {
      if (check(node)) {
        violations.add(A05Violation(node: node));
      }
    }
    return violations;
  }
}

class A05Violation {
  A05Violation({required this.node});

  final SemanticNode node;

  String get description =>
      'Semantics wrapper around ${node.children.first.widgetType} is redundant; '
      'use the button\'s built-in semantics or provide a custom label.';
}

const _meaningfulArgNames = {
  'label',
  'tooltip',
  'hint',
  'value',
  'attributedLabel',
  'attributedHint',
  'attributedValue',
};

bool _hasMeaningfulSemanticsArgs(InstanceCreationExpression creation) {
  for (final argument in creation.argumentList.arguments) {
    if (argument is! NamedExpression) continue;
    final name = argument.name.label.name;
    if (!_meaningfulArgNames.contains(name)) continue;
    final expression = argument.expression.unParenthesized;
    if (expression is NullLiteral) {
      continue;
    }
    return true;
  }
  return false;
}

bool? _literalBoolArg(InstanceCreationExpression creation, String name) {
  for (final argument in creation.argumentList.arguments) {
    if (argument is NamedExpression && argument.name.label.name == name) {
      final expression = argument.expression.unParenthesized;
      if (expression is BooleanLiteral) {
        return expression.value;
      }
      if (expression is NullLiteral) {
        return false;
      }
      return null;
    }
  }
  return null;
}

// Notes:
// - `_hasMeaningfulSemanticsArgs` checks for presence of Semantics named
//   arguments that are likely to change announcements (label, hint, value,
//   attributed variants). It treats `null` as absence. It is conservative —
//   if a complex expression is provided (not a NullLiteral) we consider it
//   meaningful even if we cannot statically evaluate it.
// - `_literalBoolArg` extracts boolean literal values for named arguments
//   like `button: true` or `header: true`. If the argument exists but is not
//   a boolean literal the function returns `null` to indicate uncertainty.
//   Consumers should treat `null` as unknown rather than `false`.
