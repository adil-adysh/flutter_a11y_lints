// Rule: A21 — Prefer IconButton.tooltip
//
// Purpose: Suggest using `IconButton.tooltip` parameter rather than wrapping
// an `IconButton` with a `Tooltip` widget. This reduces widget nesting and
// ensures the tooltip is associated directly with the control's semantics.
//
// Testing: Add tests in `test/rules/a21_use_iconbutton_tooltip_test.dart`.
// Build examples wrapping IconButton in Tooltip and assert `checkTree`
// returns violations when the IconButton itself lacks a tooltip parameter.
//
// See also:
// - `lib/src/semantics/semantic_node.dart` (`labelSource`, `controlKind`)
// - `lib/src/semantics/semantic_tree.dart`
// - `lib/src/semantics/known_semantics.dart` (IconButton mapping)
// - `test/rules/test_semantic_utils.dart`

import 'package:flutter_a11y_lints/src/semantics/known_semantics.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_tree.dart';

/// A21: Prefer IconButton.tooltip over wrapping in Tooltip widget.
class A21UseIconButtonTooltip {
  static const code = 'a21_use_iconbutton_tooltip';
  static const message =
      'Use the IconButton.tooltip parameter instead of wrapping with Tooltip';
  static const correctionMessage =
      'Move the tooltip text into the IconButton.tooltip parameter.';

  static bool check(SemanticNode node) {
    if (node.widgetType != 'Tooltip') return false;
    if (node.children.isEmpty) return false;

    SemanticNode? iconButton;
    for (final child in node.children) {
      if (child.controlKind == ControlKind.iconButton) {
        iconButton = child;
        break;
      }
    }

    if (iconButton == null) return false;

    final hasTooltipParam = iconButton.labelSource == LabelSource.tooltip;
    if (hasTooltipParam) return false;

    return true;
  }

  static List<A21Violation> checkTree(SemanticTree tree) {
    final violations = <A21Violation>[];
    for (final node in tree.physicalNodes) {
      if (check(node)) {
        final child = node.children.firstWhere(
          (childNode) => childNode.controlKind == ControlKind.iconButton,
        );
        violations.add(A21Violation(tooltipNode: node, iconButtonNode: child));
      }
    }
    return violations;
  }
}

class A21Violation {
  A21Violation({required this.tooltipNode, required this.iconButtonNode});

  final SemanticNode tooltipNode;
  final SemanticNode iconButtonNode;

  SemanticNode get node => tooltipNode;

  String get description =>
      'Tooltip widget wraps an IconButton; move the tooltip text to the IconButton.tooltip parameter.';
}
