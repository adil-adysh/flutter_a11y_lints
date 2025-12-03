import 'semantic_node.dart';

/// Annotated semantic tree with physical and accessibility-focused views.
///
/// This module transforms a raw `SemanticNode` tree into an annotated
/// `SemanticTree` that includes:
/// - `physicalNodes`: the full DFS-ordered list of nodes (including merged
///    descendants). `preOrderIndex` corresponds to this ordering.
/// - `accessibilityFocusNodes`: nodes that should be considered accessibility
///    focus targets (skips children of nodes that `mergesDescendants` or
///    `excludesDescendants`). This view models what a screen reader or
///    assistive focus traversal would encounter.
/// - `byId`: lookup table used by rules to find annotated nodes quickly.
///
/// Important behaviour:
/// - When a node has `mergesDescendants` or `excludesDescendants` set, its
///   children are still present in `physicalNodes` (so heuristics can inspect
///   them), but they are not added to `accessibilityFocusNodes`. This mirrors
///   run-time semantics where merged/excluded descendants are not individually
///   focusable.
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
      // Assign a stable id and pre-order index based on the current physical
      // nodes list length. We add a placeholder entry into `physical` so that
      // child nodes can compute their own preOrderIndex relative to this
      // node; the placeholder is replaced after children are annotated.
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
      // Decide whether this node itself should be included in the
      // `accessibilityFocusNodes` list. If any ancestor blocks focus (for
      // example a BlockSemantics overlay) or the node is not focusable or not
      // enabled, it shouldn't be added. Note: nodes that merge or exclude
      // descendants still can be focus targets themselves — children are the
      // ones that get skipped from the accessibility list.
      if (!ancestorBlocksFocus &&
          annotated.isFocusable &&
          annotated.isEnabled) {
        annotated = annotated.copyWith(focusOrderIndex: nextFocusOrder++);
        focusInsertIndex = focusable.length;
        focusable.add(annotated);
      }

      final childNodes = <SemanticNode>[];
        // If a node merges or excludes descendants, it hides its children from
        // the accessibility-focused view; for the purposes of determining which
        // nodes are assigned `focusOrderIndex`, we propagate `ancestorBlocksFocus`.
        // `hidesDescendants` means children should not be individual focus
        // targets even though they remain in `physicalNodes` for heuristic
        // inspection.
        final hidesDescendants = node.mergesDescendants || node.excludesDescendants;
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
