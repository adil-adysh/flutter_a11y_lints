import 'semantic_node.dart';
import 'known_semantics.dart';

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
    required this.roots,
    required this.physicalNodes,
    required this.accessibilityFocusNodes,
    required this.byId,
  });

  final SemanticNode root;

  /// Every root in the semantic forest, in source order.
  ///
  /// A source-level conditional whose condition cannot be resolved has one
  /// root per alternative. [root] remains the first item only for legacy
  /// single-root callers; analysis must use the forest views below.
  final List<SemanticNode> roots;
  final List<SemanticNode> physicalNodes;
  final List<SemanticNode> accessibilityFocusNodes;
  final Map<int, SemanticNode> byId;

  static SemanticTree fromRoot(SemanticNode root) => fromRoots([root]);

  /// Annotates a complete semantic forest without discarding conditional
  /// alternatives.
  static SemanticTree fromRoots(List<SemanticNode> roots) {
    if (roots.isEmpty) {
      throw ArgumentError.value(roots, 'roots', 'must not be empty');
    }
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

      final annotatedSlots = <String, SemanticNode>{};
      for (final entry in node.slots.entries) {
        final originalIndex = node.children.indexWhere(
          (child) => identical(child, entry.value),
        );
        if (originalIndex >= 0) {
          annotatedSlots[entry.key] = childNodes[originalIndex];
        }
      }
      annotated =
          annotated.copyWith(children: childNodes, slots: annotatedSlots);
      if (focusInsertIndex != null) {
        focusable[focusInsertIndex] = annotated;
      }

      physical[preOrderIndex] = annotated;
      byId[id] = annotated;
      return annotated;
    }

    final annotatedRoots = <SemanticNode>[];
    for (var i = 0; i < roots.length; i++) {
      annotatedRoots.add(annotate(roots[i], siblingIndex: i));
    }
    // Second pass: assign layout and list grouping ids using conservative
    // heuristics. This allows neighborhood queries to reason about siblings
    // that participate in the same visual row/column or represent list
    // items. We produce new `SemanticNode` instances via `copyWith` while
    // preserving ids and focus indices assigned above.
    var nextLayoutGroupId = 0;
    var nextListItemGroupId = 0;

    bool _isListLikeItem(SemanticNode node) {
      return node.widgetType == 'ListTile' ||
          node.controlKind == ControlKind.listTile ||
          node.semanticIndex != null;
    }

    SemanticNode processNode(SemanticNode node) {
      // Process children first
      final processedChildren = node.children.map(processNode).toList();

      var updatedChildren = processedChildren;

      // Layout grouping heuristic: when a node is a known layout container
      // (Row/Column/Stack) or a pure container with multiple children, assign
      // a layoutGroupId to its immediate children so rules can consider them
      // as visually grouped.
      // Expand recognized layout container widget names to include Flex and
      // common scrolling/list containers so grouping heuristics apply to them.
      final layoutContainers = {
        'Row',
        'Column',
        'Stack',
        'Wrap',
        'Flex',
        'ListView',
        'CustomScrollView',
        'SingleChildScrollView',
        'ScrollView',
      };

      if ((layoutContainers.contains(node.widgetType) ||
              node.isPureContainer) &&
          processedChildren.length > 1) {
        final layoutId = nextLayoutGroupId++;
        updatedChildren = processedChildren
            .map((c) => c.copyWith(layoutGroupId: layoutId))
            .toList(growable: false);
      }

      // List-item grouping heuristic: if a parent contains contiguous
      // children that look like list items (ListTile, have semanticIndex,
      // or listTile controlKind), assign a listItemGroupId for that run and
      // mark the first child as primary in the group.
      final children = updatedChildren;
      var i = 0;
      final newChildren = <SemanticNode>[];
      while (i < children.length) {
        if (_isListLikeItem(children[i])) {
          final groupId = nextListItemGroupId++;
          var j = i;
          var primarySet = false;
          while (j < children.length && _isListLikeItem(children[j])) {
            final isPrimary = !primarySet;
            var child = children[j].copyWith(listItemGroupId: groupId);
            if (isPrimary) {
              child = child.copyWith(isPrimaryInGroup: true);
              primarySet = true;
            }
            newChildren.add(child);
            j++;
          }
          i = j;
          continue;
        }
        newChildren.add(children[i]);
        i++;
      }

      // Return a copy of the node with updated children and preserve other
      // annotated metadata.
      return node.copyWith(children: newChildren);
    }

    final processedRoots =
        annotatedRoots.map(processNode).toList(growable: false);

    // Rebuild `physical` and `focusable` lists as well as the `byId` map to
    // reference the processed nodes.
    final newPhysical = <SemanticNode>[];
    final newById = <int, SemanticNode>{};
    final newFocusable = <SemanticNode>[];

    void collect(SemanticNode n) {
      newPhysical.add(n);
      if (n.id != null) newById[n.id!] = n;
      if (n.focusOrderIndex != null) newFocusable.add(n);
      for (final c in n.children) {
        collect(c);
      }
    }

    for (final processedRoot in processedRoots) {
      collect(processedRoot);
    }

    return SemanticTree._(
      root: processedRoots.first,
      roots: processedRoots,
      physicalNodes: newPhysical,
      accessibilityFocusNodes: newFocusable,
      byId: newById,
    );
  }

  /// Returns the next accessibility focusable node after [node], or `null`
  /// if [node] has no follow-up focus target.
  SemanticNode? nextFocusable(SemanticNode node) {
    final idx = node.focusOrderIndex;
    if (idx == null) return null;
    final next = idx + 1;
    if (next < accessibilityFocusNodes.length) {
      return accessibilityFocusNodes[next];
    }
    return null;
  }

  /// Returns the previous accessibility focusable node before [node], or
  /// `null` if [node] has no previous focus target.
  SemanticNode? previousFocusable(SemanticNode node) {
    final idx = node.focusOrderIndex;
    if (idx == null) return null;
    final prev = idx - 1;
    if (prev >= 0 && prev < accessibilityFocusNodes.length) {
      return accessibilityFocusNodes[prev];
    }
    return null;
  }
}
