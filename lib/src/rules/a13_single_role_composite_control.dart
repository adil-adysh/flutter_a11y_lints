import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_tree.dart';

/// A13 — Single Semantic Role For Composite Controls
/// Conservative heuristic: when a non-focusable parent contains multiple
/// focusable children (two or more) that likely form one visual control,
/// suggest merging into a single control.
class A13SingleRoleCompositeControl {
  static const code = 'a13_single_role_composite_control';
  static const message =
      'Composite control should present a single semantic role';
  static const correctionMessage =
      'Merge child controls into a single composite control or use MergeSemantics';

  static List<A13Violation> checkTree(SemanticTree tree) {
    final violations = <A13Violation>[];

    for (final node in tree.physicalNodes) {
      // Skip nodes that are themselves focus targets.
      if (node.isFocusable) continue;
      // Count focusable descendant nodes (accessibility focus targets)
      var count = 0;
      void visit(SemanticNode n) {
        if (n.isFocusable) count++;
        for (final c in n.children) visit(c);
      }

      for (final child in node.children) {
        visit(child);
        if (count >= 2) break;
      }

      if (count >= 2 && !node.mergesDescendants) {
        violations.add(A13Violation(node: node, focusableCount: count));
      }
    }

    return violations;
  }
}

class A13Violation {
  final SemanticNode node;
  final int focusableCount;
  A13Violation({required this.node, required this.focusableCount});

  String get description =>
      '${node.widgetType} contains $focusableCount focusable children; consider presenting a single composite control.';
}
