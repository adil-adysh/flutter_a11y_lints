// Rule: A22 — Respect Widget Semantic Boundaries
//
// Purpose: Avoid wrapping widgets (like ListTile and its variants) that
// already provide a coherent semantic boundary in MergeSemantics or similar
// wrappers; doing so can interfere with the widget's built-in accessibility
// behavior.
//
// Testing: Write tests under `test/rules/a22_respect_widget_semantic_boundaries_test.dart`.
// Use small widget snippets (ListTile, CheckboxListTile, etc.) and assert that
// `checkTree` reports MergeSemantics wrappers around those widgets.
//
// See also:
// - `lib/src/semantics/semantic_node.dart` (mergesDescendants, widgetType)
// - `lib/src/semantics/semantic_tree.dart` (physicalNodes)
// - `test/rules/test_semantic_utils.dart`

import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_tree.dart';

/// A22: Respect widget semantic boundaries (ListTile family).
class A22RespectWidgetSemanticBoundaries {
  static const code = 'a22_respect_widget_semantic_boundaries';
  static const message =
      'Avoid wrapping ListTile family widgets in MergeSemantics';
  static const correctionMessage =
      'Remove the MergeSemantics wrapper to keep the widget\'s built-in semantics.';

  static const _listTileWidgets = {
    'ListTile',
    'CheckboxListTile',
    'SwitchListTile',
    'RadioListTile',
  };

  static bool check(SemanticNode node) {
    if (node.widgetType != 'MergeSemantics') return false;
    for (final child in node.children) {
      if (_listTileWidgets.contains(child.widgetType)) {
        return true;
      }
    }
    return false;
  }

  static List<A22Violation> checkTree(SemanticTree tree) {
    final violations = <A22Violation>[];
    for (final node in tree.physicalNodes) {
      if (!check(node)) continue;
      final child = node.children.firstWhere(
        (childNode) => _listTileWidgets.contains(childNode.widgetType),
      );
      violations.add(A22Violation(wrapperNode: node, childNode: child));
    }
    return violations;
  }
}

class A22Violation {
  A22Violation({required this.wrapperNode, required this.childNode});

  final SemanticNode wrapperNode;
  final SemanticNode childNode;

  SemanticNode get node => wrapperNode;

  String get description =>
      '${childNode.widgetType} already merges semantics; remove the surrounding MergeSemantics widget.';
}
