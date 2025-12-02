import 'semantic_node.dart';

/// Annotated semantic tree with physical and accessibility-focused views.
class SemanticTree {
  SemanticTree._({
    required this.root,
    required this.physicalNodes,
    required this.accessibilityFocusNodes,
    required this.byId,
  });

  final SemanticNode root;
  final List<SemanticNode> physicalNodes;
  final List<SemanticNode> accessibilityFocusNodes;
  final Map<int, SemanticNode> byId;

  static SemanticTree fromRoot(SemanticNode root) {
    final physical = <SemanticNode>[];
    final focusable = <SemanticNode>[];
    final byId = <int, SemanticNode>{};

    var nextId = 0;
    var nextFocusOrder = 0;

    SemanticNode annotate(
      SemanticNode node, {
      int? parentId,
      int depth = 0,
      int siblingIndex = 0,
      bool ancestorBlocksFocus = false,
    }) {
      final id = nextId++;
      final preOrderIndex = physical.length;
      physical.add(node); // placeholder, replaced after children processed

      var annotated = node.copyWith(
        id: id,
        parentId: parentId,
        depth: depth,
        siblingIndex: siblingIndex,
        preOrderIndex: preOrderIndex,
      );

      int? focusInsertIndex;
      if (!ancestorBlocksFocus &&
          annotated.isFocusable &&
          annotated.isEnabled) {
        annotated = annotated.copyWith(focusOrderIndex: nextFocusOrder++);
        focusInsertIndex = focusable.length;
        focusable.add(annotated);
      }

      final childNodes = <SemanticNode>[];
      final hidesDescendants =
          node.mergesDescendants || node.excludesDescendants;
      final nextAncestorBlocksFocus = ancestorBlocksFocus || hidesDescendants;

      for (var i = 0; i < node.children.length; i++) {
        final child = annotate(
          node.children[i],
          parentId: id,
          depth: depth + 1,
          siblingIndex: i,
          ancestorBlocksFocus: nextAncestorBlocksFocus,
        );
        childNodes.add(child);
      }

      annotated = annotated.copyWith(children: childNodes);
      if (focusInsertIndex != null) {
        focusable[focusInsertIndex] = annotated;
      }

      physical[preOrderIndex] = annotated;
      byId[id] = annotated;
      return annotated;
    }

    final annotatedRoot = annotate(root);

    return SemanticTree._(
      root: annotatedRoot,
      physicalNodes: physical,
      accessibilityFocusNodes: focusable,
      byId: byId,
    );
  }
}
