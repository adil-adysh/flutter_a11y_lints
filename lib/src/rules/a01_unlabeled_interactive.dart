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
  static bool check(SemanticNode node) {
    // Must be interactive and enabled
    if (!_isInteractive(node)) return false;
    
    // Must be a primary control (not a nested interactive element)
    if (!_isPrimaryControl(node)) return false;

    // Must not have a label
    return node.labelGuarantee == LabelGuarantee.none;
  }

  static bool _isInteractive(SemanticNode node) =>
      node.isEnabled && (node.hasTap || node.hasLongPress);

  static bool _isPrimaryControl(SemanticNode node) {
    final primaryControls = {
      ControlKind.iconButton,
      ControlKind.elevatedButton,
      ControlKind.textButton,
      ControlKind.floatingActionButton,
    };
    return primaryControls.contains(node.controlKind);
  }

  /// Get violations for a semantic tree
  static List<A01Violation> checkTree(SemanticTree tree) {
    final violations = <A01Violation>[];
    
    void visit(SemanticNode node) {
      if (check(node)) {
        violations.add(A01Violation(node: node));
      }
      for (final child in node.children) {
        visit(child);
      }
    }

    visit(tree.root);
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
