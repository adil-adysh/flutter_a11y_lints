import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_tree.dart';
import 'package:flutter_a11y_lints/src/semantics/known_semantics.dart';

/// A01: Label Non-Text Controls
///
/// Detects interactive controls that lack accessible labels.
/// All icon-only or custom painted interactive controls must have
/// an accessible label source (tooltip parameter or Semantics.label).
class A01UnlabeledInteractive {
  static const code = 'a01_unlabeled_interactive';
  static const message = 'Interactive control must have an accessible label';
  static const correctionMessage =
      'Add a tooltip, Text child, or Semantics label';

  /// Check if a semantic node violates this rule
  static bool check(
    SemanticTree tree,
    SemanticNode node,
  ) {
    // Must be interactive and enabled
    if (!_isInteractive(node)) return false;

    // Must be a primary control (not a nested interactive element)
    if (!_isPrimaryControl(node)) return false;

    // Must not have a label
    if (node.labelGuarantee != LabelGuarantee.none &&
        node.effectiveLabel != null) {
      return false;
    }

    // Allow Semantics parents with explicit labels to satisfy requirement
    if (_ancestorProvidesLabel(tree, node)) {
      return false;
    }

    return true;
  }

  static bool _isInteractive(SemanticNode node) =>
      node.isEnabled && (node.hasTap || node.hasLongPress);

  static bool _isPrimaryControl(SemanticNode node) {
    final primaryControls = {
      ControlKind.iconButton,
      ControlKind.elevatedButton,
      ControlKind.textButton,
      ControlKind.floatingActionButton,
      ControlKind.filledButton,
      ControlKind.outlinedButton,
    };
    return primaryControls.contains(node.controlKind);
  }

  static bool _ancestorProvidesLabel(SemanticTree tree, SemanticNode node) {
    var current = node;
    while (current.parentId != null) {
      final parent = tree.byId[current.parentId!];
      if (parent == null) break;
      final hasExplicitLabel = parent.labelGuarantee != LabelGuarantee.none &&
          parent.effectiveLabel != null;
      final semanticsWrapper = parent.widgetType == 'Semantics';
      if (semanticsWrapper && hasExplicitLabel) {
        return true;
      }
      current = parent;
    }
    return false;
  }

  /// Get violations for a semantic tree
  static List<A01Violation> checkTree(SemanticTree tree) {
    final violations = <A01Violation>[];
    for (final node in tree.accessibilityFocusNodes) {
      if (check(tree, node)) {
        violations.add(A01Violation(node: node));
      }
    }
    return violations;
  }
}

class A01Violation {
  final SemanticNode node;

  A01Violation({required this.node});

  String get description {
    return 'Interactive ${node.widgetType} (${node.controlKind.name}) '
        'must have an accessible label';
  }
}
