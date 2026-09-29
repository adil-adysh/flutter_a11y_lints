import 'semantic_node.dart';
import 'semantic_tree.dart';

/// A conservative, source-derived approximation of Flutter's emitted
/// accessibility tree. It is intentionally separate from semantic
/// composition: source/semantic nodes can contribute without becoming an
/// independently exposed accessibility node.
class AccessibilityApproximationNode {
  const AccessibilityApproximationNode({
    required this.id,
    required this.semanticNodeId,
    required this.inclusion,
    required this.exposure,
    this.parentId,
  });

  final int id;
  final int semanticNodeId;
  final SemanticInclusionState inclusion;
  final SemanticExposureState exposure;
  final int? parentId;
}

/// Immutable accessibility projection. Unknown composition never becomes an
/// emitted node or an inferred focus target.
class AccessibilityTreeApproximation {
  const AccessibilityTreeApproximation._(this.nodes, this._bySemanticNodeId);

  final List<AccessibilityApproximationNode> nodes;
  final Map<int, AccessibilityApproximationNode> _bySemanticNodeId;

  AccessibilityApproximationNode? forSemanticNode(int semanticNodeId) =>
      _bySemanticNodeId[semanticNodeId];

  static AccessibilityTreeApproximation fromSemanticTree(SemanticTree tree) {
    final nodes = <AccessibilityApproximationNode>[];
    final bySemanticNodeId = <int, AccessibilityApproximationNode>{};
    for (final semantic in tree.physicalNodes) {
      final id = semantic.id!;
      if (semantic.inclusionState != SemanticInclusionState.included ||
          semantic.exposureState != SemanticExposureState.exposed) {
        continue;
      }
      final parent = semantic.parentId == null
          ? null
          : bySemanticNodeId[semantic.parentId!];
      final node = AccessibilityApproximationNode(
        id: id,
        semanticNodeId: id,
        inclusion: semantic.inclusionState,
        exposure: semantic.exposureState,
        parentId: parent?.id,
      );
      nodes.add(node);
      bySemanticNodeId[id] = node;
    }
    return AccessibilityTreeApproximation._(
      List.unmodifiable(nodes),
      Map.unmodifiable(bySemanticNodeId),
    );
  }
}
