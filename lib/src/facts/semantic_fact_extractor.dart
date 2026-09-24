import '../semantics/semantic_node.dart';
import '../semantics/semantic_tree.dart';
import '../semantics/known_semantics.dart';
import 'fact_store.dart';

enum LabelState { unknown, absent, dynamic, static }

/// Converts the semantic IR into general-purpose facts. Query code must not
/// inspect analyzer nodes or widget constructor syntax directly.
class SemanticFactExtractor {
  ExtractedSemanticFacts extract(SemanticTree tree) {
    var store = AccessibilityFactStore.empty();
    final labelStates = <int, LabelState>{};

    for (final node in tree.physicalNodes) {
      final id = node.id!;
      final branch = node.branchGroupId == null || node.branchValue == null
          ? null
          : Branch(node.branchGroupId!, node.branchValue!);
      store = store.addNode(FactNode(id: id, widgetType: node.widgetType, branch: branch));
      final labelState = _labelState(node);
      labelStates[id] = labelState;
      store = store
          .add(SemanticFact(nodeId: id, name: 'labelState', value: labelState.name, provenance: FactProvenance.exact))
          .add(SemanticFact(nodeId: id, name: 'labelSource', value: node.labelSource.name, provenance: FactProvenance.exact))
          .add(SemanticFact(nodeId: id, name: 'role', value: node.role.name, provenance: node.isHeuristic ? FactProvenance.heuristic : FactProvenance.exact))
          .add(SemanticFact(nodeId: id, name: 'controlKind', value: node.controlKind.name, provenance: node.isHeuristic ? FactProvenance.heuristic : FactProvenance.exact))
          .add(SemanticFact(nodeId: id, name: 'enabled', value: node.isEnabled, provenance: FactProvenance.exact))
          .add(SemanticFact(nodeId: id, name: 'focusable', value: node.isFocusable, provenance: FactProvenance.exact))
          .add(SemanticFact(nodeId: id, name: 'tap', value: node.hasTap, provenance: FactProvenance.exact))
          .add(SemanticFact(nodeId: id, name: 'longPress', value: node.hasLongPress, provenance: FactProvenance.exact))
          .add(SemanticFact(nodeId: id, name: 'mergesDescendants', value: node.mergesDescendants, provenance: FactProvenance.exact))
          .add(SemanticFact(nodeId: id, name: 'excludesDescendants', value: node.excludesDescendants, provenance: FactProvenance.exact))
          .add(SemanticFact(nodeId: id, name: 'semanticBoundary', value: node.isSemanticBoundary, provenance: FactProvenance.exact));
      if (node.parentId != null) {
        store = store.addParent(parentId: node.parentId!, childId: id);
      }
    }
    return ExtractedSemanticFacts(store, labelStates);
  }

  LabelState _labelState(SemanticNode node) {
    switch (node.labelGuarantee) {
      case LabelGuarantee.hasStaticLabel:
        return LabelState.static;
      case LabelGuarantee.hasLabelButDynamic:
        return LabelState.dynamic;
      case LabelGuarantee.none:
        return node.role == SemanticRole.unknown && node.controlKind == ControlKind.none
            ? LabelState.unknown
            : LabelState.absent;
    }
  }
}

class ExtractedSemanticFacts {
  const ExtractedSemanticFacts(this.store, this._labelStates);

  final AccessibilityFactStore store;
  final Map<int, LabelState> _labelStates;

  LabelState labelStateFor(int nodeId) => _labelStates[nodeId] ?? LabelState.unknown;
}
