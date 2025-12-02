import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_tree.dart';

/// A07: Replace Semantics Cleanly
/// 
/// Detects Semantics widgets with custom labels that don't exclude
/// children's semantics, causing double announcements.
class A07ReplaceSemanticsCleanly {
  static const code = 'a07_replace_semantics_cleanly';
  static const message = 'Semantics replacement doesn\'t exclude children';
  static const correctionMessage = 
      'Wrap children with ExcludeSemantics to prevent double announcements';

  /// Check if a semantic node violates this rule
  static bool check(SemanticNode node) {
    // Must have a custom label
    if (node.labelSource != LabelSource.semanticsWidget) return false;
    if (node.label == null || node.label!.isEmpty) return false;

    // Must have children with their own labels
    if (node.children.isEmpty) return false;

    // Should exclude descendants when providing replacement label
    if (node.excludesDescendants) return false;

    // Check if children have labels
    var childrenWithLabels = 0;
    for (final child in node.children) {
      if (child.label != null && child.label!.isNotEmpty) {
        childrenWithLabels++;
      }
    }

    // Violation: has replacement label but children also have labels
    return childrenWithLabels > 0;
  }

  /// Get violations for a semantic tree
  static List<A07Violation> checkTree(SemanticTree tree) {
    final violations = <A07Violation>[];
    
    void visit(SemanticNode node) {
      if (check(node)) {
        violations.add(A07Violation(node: node));
      }
      for (final child in node.children) {
        visit(child);
      }
    }

    visit(tree.root);
    return violations;
  }
}

class A07Violation {
  final SemanticNode node;

  A07Violation({required this.node});

  String get description {
    final childLabels = node.children
        .where((c) => c.label != null && c.label!.isNotEmpty)
        .map((c) => '"${c.label}"')
        .take(3)
        .join(', ');
    return 'Semantics with custom label "${node.label}" doesn\'t exclude '
        'children ($childLabels...), causing double announcements';
  }
}
