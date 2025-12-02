import 'semantic_node.dart';
import 'semantic_tree.dart';

/// Utility helpers for reasoning about nearby semantic nodes.
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

  bool areMutuallyExclusive(SemanticNode a, SemanticNode b) {
    if (a.branchGroupId == null || b.branchGroupId == null) return false;
    if (a.branchGroupId != b.branchGroupId) return false;
    if (a.branchValue == null || b.branchValue == null) return false;
    return a.branchValue != b.branchValue;
  }
}
