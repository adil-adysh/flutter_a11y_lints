import 'semantic_node.dart';
import 'known_semantics.dart';

/// Annotated semantic-composition forest with a conservative accessibility
/// projection.
///
/// This module transforms a raw `SemanticNode` tree into an annotated
/// `SemanticTree` that includes:
/// - `physicalNodes`: the full DFS-ordered list of nodes (including merged
///    descendants). `preOrderIndex` corresponds to this ordering.
/// - `provenAccessibilityNodes`: nodes proven to participate independently in
///    the accessibility approximation. This collection is deliberately not an
///    accessibility traversal order; source order cannot prove runtime focus
///    order.
/// - `byId`: lookup table used by rules to find annotated nodes quickly.
///
/// Important behaviour:
/// - When composition proves descendants are merged, replaced, or excluded,
///   children remain in `physicalNodes` but are not focus targets. When that
///   composition is unknown, children are likewise omitted from this proven
///   focus view without being classified as hidden.
class SemanticTree {
  SemanticTree._({
    required this.root,
    required this.roots,
    required this.physicalNodes,
    required this.provenAccessibilityNodes,
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

  /// Independently exposed nodes. Iteration order is an implementation detail
  /// for deterministic diagnostics, never a screen-reader traversal claim.
  final List<SemanticNode> provenAccessibilityNodes;

  /// Compatibility view for older callers that selected focusable exposed
  /// nodes. It does not encode next/previous accessibility traversal.
  @Deprecated('Use provenAccessibilityNodes and explicit traversal facts.')
  List<SemanticNode> get accessibilityFocusNodes => List.unmodifiable(
        provenAccessibilityNodes.where(
          (node) => node.isFocusable && node.isEnabled,
        ),
      );

  /// Semantic-tree construction never invents traversal order. Explicit
  /// traversal relationships are extracted into [AccessibilityFactGraph].
  Iterable<SemanticNode> get explicitTraversalNodes => const [];
  final Map<int, SemanticNode> byId;

  static SemanticTree fromRoot(SemanticNode root) => fromRoots([root]);

  /// Annotates a complete semantic forest without discarding conditional
  /// alternatives.
  static SemanticTree fromRoots(List<SemanticNode> roots) {
    if (roots.isEmpty) {
      throw ArgumentError.value(roots, 'roots', 'must not be empty');
    }
    final physical = <SemanticNode>[];
    final byId = <int, SemanticNode>{};

    var nextId = 0;

    SemanticNode annotate(
      SemanticNode node, {
      int? parentId,
      int depth = 0,
      int siblingIndex = 0,
      bool ancestorBlocksFocus = false,
      SemanticExposureState ancestorExposure = SemanticExposureState.exposed,
      SemanticInclusionState ancestorInclusion =
          SemanticInclusionState.included,
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
      final exposureState = switch (ancestorExposure) {
        SemanticExposureState.hidden => SemanticExposureState.hidden,
        SemanticExposureState.unknown => SemanticExposureState.unknown,
        SemanticExposureState.exposed => annotated.exposureState,
      };
      annotated = annotated.copyWith(exposureState: exposureState);
      final inclusionState = switch (ancestorInclusion) {
        SemanticInclusionState.excluded => SemanticInclusionState.excluded,
        SemanticInclusionState.unknown => SemanticInclusionState.unknown,
        SemanticInclusionState.included => annotated.inclusionState,
      };
      annotated = annotated.copyWith(inclusionState: inclusionState);

      final childNodes = <SemanticNode>[];
      // Descendants remain physical nodes regardless of composition. Only
      // proven exposure may enter the focus view; unknown composition therefore
      // propagates unknown exposure instead of assuming the child is exposed.
      final hidesDescendants = node.mergeState == SemanticMergeState.merged ||
          node.descendantReplacement == DescendantReplacementState.replaced ||
          node.descendantReplacement == DescendantReplacementState.excluded;
      final nextAncestorBlocksFocus = ancestorBlocksFocus || hidesDescendants;
      final nextAncestorExposure = hidesDescendants
          ? SemanticExposureState.hidden
          : node.mergeState == SemanticMergeState.unknown ||
                  node.descendantReplacement ==
                      DescendantReplacementState.unknown
              ? SemanticExposureState.unknown
              : exposureState;
      final nextAncestorInclusion = node.descendantReplacement ==
                  DescendantReplacementState.replaced ||
              node.descendantReplacement == DescendantReplacementState.excluded
          ? SemanticInclusionState.excluded
          : node.mergeState == SemanticMergeState.unknown ||
                  node.descendantReplacement ==
                      DescendantReplacementState.unknown
              ? SemanticInclusionState.unknown
              : inclusionState;

      for (var i = 0; i < node.children.length; i++) {
        final child = annotate(
          node.children[i],
          parentId: id,
          depth: depth + 1,
          siblingIndex: i,
          ancestorBlocksFocus: nextAncestorBlocksFocus,
          ancestorExposure: nextAncestorExposure,
          ancestorInclusion: nextAncestorInclusion,
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
      physical[preOrderIndex] = annotated;
      byId[id] = annotated;
      return annotated;
    }

    final annotatedRoots = <SemanticNode>[];
    for (var i = 0; i < roots.length; i++) {
      annotatedRoots.add(annotate(roots[i], siblingIndex: i));
    }
    // Widget source structure cannot prove rendered geometry, list position,
    // or visual grouping. Preserve only source/composition relationships.
    final processedRoots = List<SemanticNode>.unmodifiable(annotatedRoots);

    // Rebuild physical and conservative accessibility projection lists, as
    // well as the `byId` map, to reference the processed nodes.
    final newPhysical = <SemanticNode>[];
    final newById = <int, SemanticNode>{};
    final newProvenAccessibility = <SemanticNode>[];

    void collect(SemanticNode n) {
      newPhysical.add(n);
      if (n.id != null) newById[n.id!] = n;
      if (n.exposureState == SemanticExposureState.exposed &&
          n.inclusionState == SemanticInclusionState.included) {
        newProvenAccessibility.add(n);
      }
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
      provenAccessibilityNodes: newProvenAccessibility,
      byId: newById,
    );
  }
}
