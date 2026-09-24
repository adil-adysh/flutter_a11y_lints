/// Provenance is deliberately separate from a query's confidence policy.
enum FactProvenance { exact, derived, heuristic }

enum FactMode { conservative, expanded }

class Branch {
  const Branch(this.group, this.value);

  final int group;
  final int value;
}

class BranchPath {
  const BranchPath(this.constraints);
  final List<Branch> constraints;

  bool compatibleWith(BranchPath other) {
    for (final left in constraints) {
      for (final right in other.constraints) {
        if (left.group == right.group && left.value != right.value)
          return false;
      }
    }
    return true;
  }
}

class FactNode {
  const FactNode({
    required this.id,
    required this.widgetType,
    this.branch,
    this.branchPath,
  });

  final int id;
  final String widgetType;
  final Branch? branch;
  final BranchPath? branchPath;
  BranchPath get effectiveBranchPath =>
      branchPath ??
      (branch == null ? const BranchPath([]) : BranchPath([branch!]));
}

class SemanticFact {
  const SemanticFact({
    required this.nodeId,
    required this.name,
    required this.value,
    required this.provenance,
  });

  final int nodeId;
  final String name;
  final Object? value;
  final FactProvenance provenance;
}

/// An immutable, indexed projection of semantic IR for FAQL evaluation.
class AccessibilityFactStore {
  const AccessibilityFactStore._(
    this._nodes,
    this._facts,
    this._children,
    this._parents,
  );

  factory AccessibilityFactStore.empty() => const AccessibilityFactStore._(
        <int, FactNode>{},
        <int, List<SemanticFact>>{},
        <int, List<int>>{},
        <int, int>{},
      );

  final Map<int, FactNode> _nodes;
  final Map<int, List<SemanticFact>> _facts;
  final Map<int, List<int>> _children;
  final Map<int, int> _parents;

  FactStoreView get conservative => FactStoreView(this, FactMode.conservative);
  FactStoreView get expanded => FactStoreView(this, FactMode.expanded);

  Iterable<FactNode> get nodes => _nodes.values;

  FactNode? nodeById(int id) => _nodes[id];

  AccessibilityFactStore addNode(FactNode node) {
    return AccessibilityFactStore._(
      {..._nodes, node.id: node},
      _facts,
      _children,
      _parents,
    );
  }

  AccessibilityFactStore add(SemanticFact fact) {
    final next = <int, List<SemanticFact>>{..._facts};
    next[fact.nodeId] = [...(next[fact.nodeId] ?? const []), fact];
    return AccessibilityFactStore._(_nodes, next, _children, _parents);
  }

  AccessibilityFactStore addParent(
      {required int parentId, required int childId}) {
    if (_parents.containsKey(childId)) {
      throw ArgumentError.value(
          childId, 'childId', 'A child already has a parent.');
    }
    final next = <int, List<int>>{..._children};
    next[parentId] = [...(next[parentId] ?? const []), childId];
    return AccessibilityFactStore._(
      _nodes,
      _facts,
      next,
      {..._parents, childId: parentId},
    );
  }

  bool compatible(int leftId, int rightId) {
    final left = _nodes[leftId];
    final right = _nodes[rightId];
    return left == null ||
        right == null ||
        left.effectiveBranchPath.compatibleWith(right.effectiveBranchPath);
  }

  FactNode? parentOf(
    int nodeId, {
    Iterable<int> compatibleWith = const [],
  }) {
    final parentId = _parents[nodeId];
    if (parentId == null ||
        !_isCompatibleWithAll(parentId, [nodeId, ...compatibleWith])) {
      return null;
    }
    return _nodes[parentId];
  }

  Iterable<FactNode> childrenOf(
    int nodeId, {
    Iterable<int> compatibleWith = const [],
  }) sync* {
    final bindings = [nodeId, ...compatibleWith];
    for (final childId in _children[nodeId] ?? const []) {
      if (!_isCompatibleWithAll(childId, bindings)) continue;
      final child = _nodes[childId];
      if (child != null) yield child;
    }
  }

  Iterable<FactNode> ancestorsOf(
    int nodeId, {
    Iterable<int> compatibleWith = const [],
  }) sync* {
    var parentId = _parents[nodeId];
    final bindings = [nodeId, ...compatibleWith];
    while (parentId != null) {
      if (!_isCompatibleWithAll(parentId, bindings)) break;
      final parent = _nodes[parentId];
      if (parent != null) yield parent;
      parentId = _parents[parentId];
    }
  }

  Iterable<FactNode> descendantsOf(
    int nodeId, {
    Iterable<int> compatibleWith = const [],
  }) sync* {
    final bindings = [nodeId, ...compatibleWith];
    final pending = <int>[...(_children[nodeId] ?? const [])];
    var index = 0;
    while (index < pending.length) {
      final id = pending[index++];
      if (!_isCompatibleWithAll(id, bindings)) continue;
      final node = _nodes[id];
      if (node != null) yield node;
      pending.addAll(_children[id] ?? const []);
    }
  }

  Iterable<FactNode> siblingsOf(
    int nodeId, {
    Iterable<int> compatibleWith = const [],
  }) sync* {
    final parentId = _parents[nodeId];
    if (parentId == null) return;
    final bindings = [nodeId, ...compatibleWith];
    for (final siblingId in _children[parentId] ?? const []) {
      if (siblingId == nodeId || !_isCompatibleWithAll(siblingId, bindings))
        continue;
      final sibling = _nodes[siblingId];
      if (sibling != null) yield sibling;
    }
  }

  bool _isCompatibleWithAll(int candidateId, Iterable<int> boundIds) {
    return boundIds.every((boundId) => compatible(candidateId, boundId));
  }

  List<SemanticFact> _factsFor(int nodeId, FactMode mode) {
    final facts = _facts[nodeId] ?? const [];
    if (mode == FactMode.expanded) return facts;
    return facts
        .where((fact) => fact.provenance != FactProvenance.heuristic)
        .toList();
  }
}

class FactStoreView {
  const FactStoreView(this._store, this.mode);

  final AccessibilityFactStore _store;
  final FactMode mode;

  Iterable<FactNode> get nodes => _store.nodes;
  List<SemanticFact> factsFor(int nodeId) => _store._factsFor(nodeId, mode);
}
