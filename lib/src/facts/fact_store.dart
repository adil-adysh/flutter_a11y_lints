/// Provenance is deliberately separate from a query's confidence policy.
enum FactProvenance { exact, derived, heuristic }

enum FactMode { conservative, expanded }

class Branch {
  const Branch(this.group, this.value);

  final int group;
  final int value;
}

class FactNode {
  const FactNode({required this.id, required this.widgetType, this.branch});

  final int id;
  final String widgetType;
  final Branch? branch;
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
  const AccessibilityFactStore._(this._nodes, this._facts, this._children);

  factory AccessibilityFactStore.empty() => const AccessibilityFactStore._(
        <int, FactNode>{},
        <int, List<SemanticFact>>{},
        <int, List<int>>{},
      );

  final Map<int, FactNode> _nodes;
  final Map<int, List<SemanticFact>> _facts;
  final Map<int, List<int>> _children;

  FactStoreView get conservative => FactStoreView(this, FactMode.conservative);
  FactStoreView get expanded => FactStoreView(this, FactMode.expanded);

  Iterable<FactNode> get nodes => _nodes.values;

  AccessibilityFactStore addNode(FactNode node) {
    return AccessibilityFactStore._({..._nodes, node.id: node}, _facts, _children);
  }

  AccessibilityFactStore add(SemanticFact fact) {
    final next = <int, List<SemanticFact>>{..._facts};
    next[fact.nodeId] = [...(next[fact.nodeId] ?? const []), fact];
    return AccessibilityFactStore._(_nodes, next, _children);
  }

  AccessibilityFactStore addParent({required int parentId, required int childId}) {
    final next = <int, List<int>>{..._children};
    next[parentId] = [...(next[parentId] ?? const []), childId];
    return AccessibilityFactStore._(_nodes, _facts, next);
  }

  bool compatible(int leftId, int rightId) {
    final left = _nodes[leftId]?.branch;
    final right = _nodes[rightId]?.branch;
    return left == null || right == null || left.group != right.group || left.value == right.value;
  }

  Iterable<FactNode> descendantsOf(int nodeId) sync* {
    final pending = <int>[...(_children[nodeId] ?? const [])];
    var index = 0;
    while (index < pending.length) {
      final id = pending[index++];
      if (!compatible(nodeId, id)) continue;
      final node = _nodes[id];
      if (node != null) yield node;
      pending.addAll(_children[id] ?? const []);
    }
  }

  List<SemanticFact> _factsFor(int nodeId, FactMode mode) {
    final facts = _facts[nodeId] ?? const [];
    if (mode == FactMode.expanded) return facts;
    return facts.where((fact) => fact.provenance != FactProvenance.heuristic).toList();
  }
}

class FactStoreView {
  const FactStoreView(this._store, this.mode);

  final AccessibilityFactStore _store;
  final FactMode mode;

  Iterable<FactNode> get nodes => _store.nodes;
  List<SemanticFact> factsFor(int nodeId) => _store._factsFor(nodeId, mode);
}
