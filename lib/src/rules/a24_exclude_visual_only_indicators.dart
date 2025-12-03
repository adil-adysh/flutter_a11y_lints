import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_tree.dart';

/// A24 — Exclude visual-only drag handle icons
class A24ExcludeVisualOnlyIndicators {
  static const code = 'a24_exclude_visual_only_indicators';
  static const message =
      'Visual-only drag indicator should be excluded from semantics';
  static const correctionMessage =
      'Wrap drag handle icons with ExcludeSemantics or remove from semantics tree';

  static final _iconNames = {'drag_handle', 'drag_indicator'};

  static List<A24Violation> checkTree(SemanticTree tree) {
    final violations = <A24Violation>[];
    for (final node in tree.physicalNodes) {
      if (node.widgetType != 'Icon') continue;
      // If any ancestor excludes descendants, it's fine.
      if (_hasExcludeAncestor(node, tree)) continue;
      final ast = node.astNode;
      if (ast is! InstanceCreationExpression) continue;
      if (ast.argumentList.arguments.isEmpty) continue;
      final first = ast.argumentList.arguments.first;
      // PrefixedIdentifier like Icons.drag_handle
      if (first is PrefixedIdentifier) {
        final name = first.identifier.name;
        if (_iconNames.contains(name)) {
          violations.add(A24Violation(node: node, iconName: name));
        }
      }
    }
    return violations;
  }

  static bool _hasExcludeAncestor(SemanticNode node, SemanticTree tree) {
    var current = node;
    while (current.parentId != null) {
      final parent = tree.byId[current.parentId!];
      if (parent == null) break;
      if (parent.excludesDescendants) return true;
      current = parent;
    }
    return false;
  }
}

class A24Violation {
  final SemanticNode node;
  final String iconName;

  A24Violation({required this.node, required this.iconName});

  String get description =>
      'Icon ${iconName} should be excluded from semantics when purely visual.';
}
