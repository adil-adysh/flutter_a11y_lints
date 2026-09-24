import '../facts/fact_store.dart';
import 'ast.dart';
import 'compiler.dart';
import 'stdlib.dart';

class Faql4Violation {
  const Faql4Violation(this.nodeId, this.query, this.bindings);
  final int nodeId;
  final CompiledQuery query;
  final Map<String, int> bindings;
}

class Faql4Evaluator {
  List<Faql4Violation> evaluate(
      CompiledQuery query, AccessibilityFactStore store) {
    final facts = query.mode == FactMode.conservative
        ? store.conservative
        : store.expanded;
    final roots = facts.nodes
        .where(
            (node) => Faql4StandardLibrary.matchesView(query.view, node, facts))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return [
      for (final root in roots)
        if (query.where == null ||
            _bool(query.where!, store, facts, {query.variable: root.id}))
          Faql4Violation(
              root.id, query, Map.unmodifiable({query.variable: root.id}))
    ];
  }

  bool _bool(ExpressionAst e, AccessibilityFactStore store, FactStoreView facts,
          Map<String, int> bindings) =>
      switch (e) {
        AndAst v => _bool(v.left, store, facts, bindings) &&
            _bool(v.right, store, facts, bindings),
        OrAst v => _bool(v.left, store, facts, bindings) ||
            _bool(v.right, store, facts, bindings),
        NotAst v => !_bool(v.inner, store, facts, bindings),
        ExistsAst v => _candidates(v.view, store, facts, bindings).any(
            (id) => _bool(v.body, store, facts, {...bindings, v.variable: id})),
        ComparisonAst v => _compare(_value(v.left, store, facts, bindings),
            v.operator, _value(v.right, store, facts, bindings)),
        MemberCallAst v => _value(v, store, facts, bindings) == true,
        _ => false,
      };

  Iterable<int> _candidates(String view, AccessibilityFactStore store,
          FactStoreView facts, Map<String, int> bindings) =>
      facts.nodes
          .where((node) =>
              bindings.values.every((id) => store.compatible(node.id, id)) &&
              Faql4StandardLibrary.matchesView(view, node, facts))
          .map((node) => node.id);

  Object? _value(ExpressionAst e, AccessibilityFactStore store,
      FactStoreView facts, Map<String, int> bindings) {
    if (e case LiteralAst v) return v.value;
    if (e case VariableAst v) return bindings[v.name];
    if (e case CountAst v) {
      final candidates = _candidates(v.view, store, facts, bindings)
          .where((id) =>
              _bool(v.body, store, facts, {...bindings, v.variable: id}))
          .toList();
      var maximum = 0;
      for (final seed in candidates) {
        final count =
            candidates.where((id) => store.compatible(seed, id)).length;
        if (count > maximum) maximum = count;
      }
      return maximum;
    }
    final v = e as MemberCallAst;
    final id = bindings[v.variable]!;
    if (v.member == 'getWidgetType') return store.nodeById(id)?.widgetType;
    final relations = switch (v.member) {
      'getParent' => [store.parentOf(id)?.id],
      'getAChild' =>
        store.childrenOf(id, compatibleWith: bindings.values).map((n) => n.id),
      'getAnAncestor' =>
        store.ancestorsOf(id, compatibleWith: bindings.values).map((n) => n.id),
      'getADescendant' => store
          .descendantsOf(id, compatibleWith: bindings.values)
          .map((n) => n.id),
      'getASibling' =>
        store.siblingsOf(id, compatibleWith: bindings.values).map((n) => n.id),
      _ => null,
    };
    if (relations != null) {
      return (relations as Iterable<Object?>).whereType<int>();
    }
    Object? fact;
    for (final item in facts.factsFor(id)) {
      if (item.name == Faql4StandardLibrary.booleanMembers[v.member]) {
        fact = item.value;
        break;
      }
    }
    return switch (v.member) {
      'isDefinitelyUnlabeled' => fact == 'absent',
      'hasAccessibleLabel' => fact == 'static' || fact == 'dynamic',
      'hasStaticLabel' => fact == 'static',
      _ => fact == true
    };
  }

  bool _compare(Object? left, String op, Object? right) {
    final equal = left is Iterable
        ? left.contains(right)
        : right is Iterable
            ? right.contains(left)
            : left == right;
    if (op == '=') return equal;
    if (op == '!=') return !equal;
    if (left is int && right is int)
      return switch (op) {
        '>' => left > right,
        '>=' => left >= right,
        '<' => left < right,
        '<=' => left <= right,
        _ => false
      };
    return false;
  }
}
