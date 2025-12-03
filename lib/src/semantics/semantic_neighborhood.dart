import 'semantic_node.dart';
import 'semantic_tree.dart';

/// Utility helpers for reasoning about nearby semantic nodes.
///
/// `SemanticNeighborhood` is a convenience wrapper around `SemanticTree` to
/// provide common queries used by heuristic rules (nearby siblings, previous
/// and next in reading order, layout groups, etc.). Important: callers must
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

  SemanticNode? previousInReadingOrder(SemanticNode node) {
    final index = node.preOrderIndex;
    if (index == null || index <= 0) return null;
    if (index - 1 >= tree.physicalNodes.length) return null;
    return tree.physicalNodes[index - 1];
  }

  SemanticNode? nextInReadingOrder(SemanticNode node) {
    final index = node.preOrderIndex;
    if (index == null) return null;
    if (index + 1 >= tree.physicalNodes.length) return null;
    return tree.physicalNodes[index + 1];
  }

  Iterable<SemanticNode> neighborsInReadingOrder(
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
  /// Returns true when `a` and `b` are known to originate from different
  /// branches of the same conditional (`if`/`else` or `?:`) and therefore
  /// cannot both be present at runtime. This is important to avoid heuristics
  /// that look for 'nearby' labels accidentally using text that only appears
  /// in an alternate branch.
  bool areMutuallyExclusive(SemanticNode a, SemanticNode b) {
    if (a.branchGroupId == null || b.branchGroupId == null) return false;
    if (a.branchGroupId != b.branchGroupId) return false;
    if (a.branchValue == null || b.branchValue == null) return false;
    return a.branchValue != b.branchValue;
  }
}
