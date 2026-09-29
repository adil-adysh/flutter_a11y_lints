import 'semantic_node.dart';
import 'semantic_tree.dart';
import '../facts/fact_store.dart' show Branch, BranchPath;

/// Utility helpers for reasoning about nearby semantic nodes.
///
/// `SemanticNeighborhood` is a convenience wrapper around `SemanticTree` to
/// provide common source/composition queries used by heuristic rules (nearby
/// siblings and source order, for example). Important: callers must
/// consider `areMutuallyExclusive` when using nearby nodes — widgets produced
/// by different branches of the same conditional may look adjacent in the
/// IR but cannot co-occur at runtime.
class SemanticNeighborhood {
  SemanticNeighborhood(this.tree);

  final SemanticTree tree;

  SemanticNode? parentOf(SemanticNode node) {
    final parentId = node.parentId;
    if (parentId == null) return null;
    return tree.byId[parentId];
  }

  List<SemanticNode> siblingsOf(SemanticNode node) {
    final parent = parentOf(node);
    if (parent == null) return [node];
    return parent.children;
  }

  /// The preceding node in deterministic source/composition order. This is
  /// not a rendered or accessibility traversal order.
  SemanticNode? previousInSourceOrder(SemanticNode node) {
    final index = node.preOrderIndex;
    if (index == null || index <= 0) return null;
    if (index - 1 >= tree.physicalNodes.length) return null;
    return tree.physicalNodes[index - 1];
  }

  /// The following node in deterministic source/composition order. This is
  /// not a rendered or accessibility traversal order.
  SemanticNode? nextInSourceOrder(SemanticNode node) {
    final index = node.preOrderIndex;
    if (index == null) return null;
    if (index + 1 >= tree.physicalNodes.length) return null;
    return tree.physicalNodes[index + 1];
  }

  /// Returns true only when the model explicitly proves semantic exposure is
  /// hidden. Absence from [SemanticTree.accessibilityFocusNodes] is not proof
  /// of hidden content: it can also represent unknown composition or a node
  /// that is not focusable.
  bool isHidden(SemanticNode node) =>
      node.exposureState == SemanticExposureState.hidden;

  /// Nearby nodes in deterministic source/composition order, not visual or
  /// accessibility traversal order.
  Iterable<SemanticNode> neighborsInSourceOrder(
    SemanticNode node, {
    int radius = 3,
  }) sync* {
    final index = node.preOrderIndex;
    if (index == null) return;
    for (var delta = -radius; delta <= radius; delta++) {
      if (delta == 0) continue;
      final candidate = index + delta;
      if (candidate < 0 || candidate >= tree.physicalNodes.length) {
        continue;
      }
      yield tree.physicalNodes[candidate];
    }
  }

  Iterable<SemanticNode> siblingsBefore(SemanticNode node) sync* {
    final parent = parentOf(node);
    if (parent == null) return;
    for (var i = 0; i < node.siblingIndex; i++) {
      yield parent.children[i];
    }
  }

  Iterable<SemanticNode> siblingsAfter(SemanticNode node) sync* {
    final parent = parentOf(node);
    if (parent == null) return;
    for (var i = node.siblingIndex + 1; i < parent.children.length; i++) {
      yield parent.children[i];
    }
  }

  Iterable<SemanticNode> sameLayoutGroup(SemanticNode node) sync* {
    final groupId = node.layoutGroupId;
    if (groupId == null) return;
    for (final candidate in tree.physicalNodes) {
      if (candidate.layoutGroupId == groupId) {
        yield candidate;
      }
    }
  }

  Iterable<SemanticNode> sameListItemGroup(SemanticNode node) sync* {
    final groupId = node.listItemGroupId;
    if (groupId == null) return;
    for (final candidate in tree.physicalNodes) {
      if (candidate.listItemGroupId == groupId) {
        yield candidate;
      }
    }
  }

  /// Returns true when [a] and [b] assign different values to any shared
  /// unresolved conditional. Complete paths are required: scalar branch
  /// metadata is used only as a derived compatibility path for manually
  /// constructed legacy nodes.
  bool areMutuallyExclusive(SemanticNode a, SemanticNode b) =>
      !_effectivePath(a).compatibleWith(_effectivePath(b));

  BranchPath _effectivePath(SemanticNode node) {
    if (node.branchPath.constraints.isNotEmpty) return node.branchPath;
    if (node.branchGroupId != null && node.branchValue != null) {
      return BranchPath([Branch(node.branchGroupId!, node.branchValue!)]);
    }
    return const BranchPath([]);
  }
}
