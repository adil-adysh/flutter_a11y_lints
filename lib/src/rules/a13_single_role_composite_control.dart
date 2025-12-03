import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_tree.dart';

/// A13 — Single Semantic Role For Composite Controls
/// Warn only when a semantic boundary/composite host aggregates multiple
/// focusable descendants without merging them into one role. Layout widgets
/// (Row/Column/ListView/etc.) are excluded to prevent noise.
class A13SingleRoleCompositeControl {
  static const code = 'a13_single_role_composite_control';
  static const message =
      'Composite control should present a single semantic role';
  static const correctionMessage =
      'Merge child controls into a single composite control or use MergeSemantics';

  static const _layoutWidgets = {
    'Row',
    'Column',
    'Wrap',
    'Flex',
    'ListView',
    'GridView',
    'Stack',
    'SizedBox',
    'Container',
    'Padding',
    'Center',
    'Align',
    'ListBody',
  };

  static List<A13Violation> checkTree(SemanticTree tree) {
    final violations = <A13Violation>[];

    for (final node in tree.physicalNodes) {
      if (!_shouldInspectNode(node)) continue;
      final focusableCount = _countFocusableDescendants(node);
      if (focusableCount >= 2) {
        violations
            .add(A13Violation(node: node, focusableCount: focusableCount));
      }
    }

    return violations;
  }

  static bool _shouldInspectNode(SemanticNode node) {
    if (node.isFocusable) return false;
    if (node.isPureContainer) return false;
    if (!node.isSemanticBoundary && !node.isCompositeControl) {
      return false;
    }
    if (_layoutWidgets.contains(node.widgetType)) {
      return false;
    }
    if (node.widgetType == 'MergeSemantics') {
      return false;
    }
    return true;
  }

  static int _countFocusableDescendants(SemanticNode node) {
    var count = 0;

    void visit(SemanticNode n) {
      if (count >= 2) return; // early exit once threshold reached
      if (n.isFocusable) {
        count++;
        if (count >= 2) return;
      }
      for (final child in n.children) {
        if (count >= 2) break;
        visit(child);
      }
    }

    for (final child in node.children) {
      if (count >= 2) break;
      visit(child);
    }

    return count;
  }
}

class A13Violation {
  final SemanticNode node;
  final int focusableCount;
  A13Violation({required this.node, required this.focusableCount});

  String get description =>
      '${node.widgetType} contains $focusableCount focusable children; consider presenting a single composite control.';
}
