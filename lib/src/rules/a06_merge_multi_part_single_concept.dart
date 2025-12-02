import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_tree.dart';

/// A06: Merge Multi-Part Single Concept
///
/// Detects interactive widgets with multiple semantic children that should
/// be announced as a single unit (e.g., icon + text in a button).
class A06MergeMultiPartSingleConcept {
  static const code = 'a06_merge_multi_part_single_concept';
  static const message = 'Interactive control has multiple semantic parts';
  static const correctionMessage =
      'Use MergeSemantics to combine icon and text into a single announcement';

  /// Check if a semantic node violates this rule
  static bool check(SemanticNode node) {
    // Must be interactive
    if (!node.isEnabled || !node.hasTap) return false;

    // Must have multiple children with labels
    if (node.children.length < 2) return false;

    // Check if children have their own labels (not merged)
    var childrenWithLabels = 0;
    for (final child in node.children) {
      if (child.label != null && child.label!.isNotEmpty) {
        childrenWithLabels++;
      }
    }

    // If we have 2+ children with labels and the parent doesn't merge,
    // it's likely a violation (icon + text that should be merged)
    return childrenWithLabels >= 2 && !node.mergesDescendants;
  }

  /// Get violations for a semantic tree
  static List<A06Violation> checkTree(SemanticTree tree) {
    final violations = <A06Violation>[];

    void visit(SemanticNode node) {
      if (check(node)) {
        violations.add(A06Violation(node: node));
      }
      for (final child in node.children) {
        visit(child);
      }
    }

    visit(tree.root);
    return violations;
  }
}

class A06Violation {
  final SemanticNode node;

  A06Violation({required this.node});

  String get description {
    final childLabels = node.children
        .where((c) => c.label != null && c.label!.isNotEmpty)
        .map((c) => '"${c.label}"')
        .join(', ');
    return 'Interactive ${node.widgetType} has ${node.children.length} '
        'separate semantic parts: $childLabels. Consider using MergeSemantics.';
  }
}
