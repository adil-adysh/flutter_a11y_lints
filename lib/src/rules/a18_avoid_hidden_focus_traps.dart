// Rule: A18 — Avoid Hidden Focus Traps
//
// Purpose: Detect widgets (Offstage/Visibility) that remain in the tree but
// visually hide descendant focusable elements, which can trap screen-readers
// or keyboard focus users. Encourage disabling focusable children or
// removing them while hidden.
//
// Testing: Add tests in `test/rules/a18_avoid_hidden_focus_traps_test.dart`.
// Create Offstage/Visibility snippets with focusable descendants and assert
// that `checkTree` returns violations for hidden-but-focusable subtrees.
//
// See also:
// - `lib/src/semantics/semantic_node.dart` (focusable detection helpers)
// - `lib/src/semantics/semantic_tree.dart` (physicalNodes traversal)
// - `lib/src/semantics/known_semantics.dart` (Offstage/Visibility semantics hints)
// - `test/rules/test_semantic_utils.dart`

import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_a11y_lints/src/semantics/known_semantics.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_tree.dart';

/// A18: Avoid hidden focus traps created by Offstage/Visibility.
class A18AvoidHiddenFocusTraps {
  static const code = 'a18_avoid_hidden_focus_traps';
  static const message = 'Hidden focusable widgets can trap screen readers';
  static const correctionMessage =
      'Remove the hidden focusable widget or disable it while offstage/hidden.';

  static List<A18Violation> checkTree(SemanticTree tree) {
    final violations = <A18Violation>[];

    for (final node in tree.physicalNodes) {
      final violation = _checkNode(node);
      if (violation != null) {
        violations.add(violation);
      }
    }

    return violations;
  }

  static A18Violation? _checkNode(SemanticNode node) {
    if (node.widgetType != 'Offstage' && node.widgetType != 'Visibility') {
      return null;
    }

    final creation = node.astNode;
    if (creation is! InstanceCreationExpression) {
      return null;
    }

    final bool? hidesContent;
    if (node.widgetType == 'Offstage') {
      final value = _literalBoolArgument(creation, 'offstage');
      if (value != true) return null;
      hidesContent = true;
    } else {
      final value = _literalBoolArgument(creation, 'visible');
      if (value != false) return null;
      hidesContent = true;
    }

    if (hidesContent != true) return null;
    if (!_hasFocusableDescendant(node)) {
      return null;
    }

    return A18Violation(node: node);
  }

  static bool _hasFocusableDescendant(SemanticNode node) {
    final stack = <SemanticNode>[...node.children];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      final interactive = (current.isFocusable && current.isEnabled) ||
          (current.controlKind != ControlKind.none && current.isEnabled) ||
          current.hasTap ||
          current.hasLongPress ||
          current.hasIncrease ||
          current.hasDecrease;
      if (interactive) {
        return true;
      }
      stack.addAll(current.children);
    }
    return false;
  }

  static bool? _literalBoolArgument(
    InstanceCreationExpression creation,
    String name,
  ) {
    for (final argument in creation.argumentList.arguments) {
      if (argument is NamedExpression && argument.name.label.name == name) {
        final expression = argument.expression;
        if (expression is BooleanLiteral) {
          return expression.value;
        }
        return null;
      }
    }
    return null;
  }
}

class A18Violation {
  A18Violation({required this.node});

  final SemanticNode node;

  String get description =>
      '${node.widgetType} hides a focusable widget while remaining in the tree.';
}
