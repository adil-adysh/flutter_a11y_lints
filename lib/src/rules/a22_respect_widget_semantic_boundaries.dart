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
