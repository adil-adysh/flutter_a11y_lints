import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_tree.dart';

/// A15 — Mirror custom gestures to semantics actions
/// Conservative: flag `GestureDetector` usages that have tap handlers but
/// no accessible label or semantics wrapper.
class A15MapCustomGesturesToOnTap {
  static const code = 'a15_map_custom_gestures_to_on_tap';
  static const message = 'Custom gestures should surface semantic actions';
  static const correctionMessage =
      'Add a Semantics( button: true ) or provide an accessible label for GestureDetector';

  static List<A15Violation> checkTree(SemanticTree tree) {
    final violations = <A15Violation>[];
    for (final node in tree.physicalNodes) {
      if (node.widgetType == 'GestureDetector') {
        // If this node or any ancestor provides a label or semantics wrapper, skip.
        if (_hasAccessibleLabelOrSemantics(node, tree)) continue;
        violations.add(A15Violation(node: node));
      }
    }
    return violations;
  }

  static bool _hasAccessibleLabelOrSemantics(
      SemanticNode node, SemanticTree tree) {
    var current = node;
    while (true) {
      if (current.labelGuarantee != LabelGuarantee.none) return true;
      if (current.widgetType == 'Semantics') return true;
      if (current.parentId == null) break;
      final p = tree.byId[current.parentId!];
      if (p == null) break;
      current = p;
    }
    return false;
  }
}

class A15Violation {
  final SemanticNode node;
  A15Violation({required this.node});
  String get description =>
      'GestureDetector at ${node.offset} should expose semantic action';
}
