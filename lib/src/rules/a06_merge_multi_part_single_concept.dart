// Rule: A06 — Merge Multi-Part Single Concept
//
// Purpose: Detect interactive controls composed of multiple semantic parts
// (e.g., icon + text) that should be merged into a single announcement
// using `MergeSemantics` to provide a concise, atomic label.
//
// Testing: Add tests under `test/rules/a06_merge_multi_part_single_concept_test.dart`.
// Create minimal widget trees with helpers and assert `checkTree` flags
// multi-part interactive nodes lacking `mergesDescendants`.
//
// See also:
// - `lib/src/semantics/semantic_node.dart` (children traversal, `mergesDescendants`)
// - `lib/src/semantics/semantic_tree.dart` (`accessibilityFocusNodes`)
// - `test/rules/test_semantic_utils.dart`

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
    final isInteractive = node.isEnabled &&
        (node.hasTap ||
            node.hasLongPress ||
            node.hasIncrease ||
            node.hasDecrease);
    if (!isInteractive) return false;

    if (node.children.length < 2) return false;
    if (node.mergesDescendants) return false;

    var childrenWithLabels = 0;
    for (final child in node.children) {
      if (_hasLabel(child)) {
        childrenWithLabels++;
      }
    }

    return childrenWithLabels >= 2;
  }

  static bool _hasLabel(SemanticNode node) {
    if (node.effectiveLabel != null && node.effectiveLabel!.isNotEmpty) {
      return true;
    }
    return node.labelGuarantee != LabelGuarantee.none;
  }

  /// Get violations for a semantic tree
  static List<A06Violation> checkTree(SemanticTree tree) {
    final violations = <A06Violation>[];
    for (final node in tree.accessibilityFocusNodes) {
      if (check(node)) {
        violations.add(A06Violation(node: node));
      }
    }
    return violations;
  }
}

class A06Violation {
  final SemanticNode node;

  A06Violation({required this.node});

  String get description {
    final childLabels = node.children
        .where((c) => c.effectiveLabel != null && c.effectiveLabel!.isNotEmpty)
        .map((c) => '"${c.effectiveLabel}"')
        .join(', ');
    return 'Interactive ${node.widgetType} has ${node.children.length} '
        'separate semantic parts: $childLabels. Consider using MergeSemantics.';
  }
}
