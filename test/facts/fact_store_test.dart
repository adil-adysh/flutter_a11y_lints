import 'package:flutter_a11y_lints/src/facts/fact_store.dart';
import 'package:test/test.dart';

void main() {
  group('AccessibilityFactStore', () {
    test('conservative facts exclude heuristic provenance', () {
      final store = AccessibilityFactStore.empty().add(
        SemanticFact(
          nodeId: 1,
          name: 'interactive',
          value: true,
          provenance: FactProvenance.heuristic,
        ),
      );

      expect(store.conservative.factsFor(1), isEmpty);
      expect(store.expanded.factsFor(1).single.value, isTrue);
    });

    test('relationships do not cross incompatible branch alternatives', () {
      final store = AccessibilityFactStore.empty()
          .addNode(const FactNode(id: 1, widgetType: 'Column'))
          .addNode(const FactNode(
              id: 2, widgetType: 'IconButton', branch: Branch(7, 0)))
          .addNode(
              const FactNode(id: 3, widgetType: 'Text', branch: Branch(7, 1)))
          .addParent(parentId: 1, childId: 2)
          .addParent(parentId: 1, childId: 3);

      expect(store.descendantsOf(2).map((node) => node.id), isEmpty);
      expect(store.descendantsOf(1).map((node) => node.id), [2, 3]);
      expect(store.compatible(2, 3), isFalse);
    });

    test('indexes semantic relationships without incompatible bindings', () {
      final store = AccessibilityFactStore.empty()
          .addNode(const FactNode(id: 1, widgetType: 'Column'))
          .addNode(
              const FactNode(id: 2, widgetType: 'Row', branch: Branch(7, 0)))
          .addNode(
              const FactNode(id: 3, widgetType: 'Text', branch: Branch(7, 1)))
          .addNode(const FactNode(
              id: 4, widgetType: 'IconButton', branch: Branch(7, 0)))
          .addParent(parentId: 1, childId: 2)
          .addParent(parentId: 1, childId: 3)
          .addParent(parentId: 2, childId: 4);

      expect(store.nodeById(4)?.widgetType, 'IconButton');
      expect(store.parentOf(4)?.id, 2);
      expect(store.parentOf(4, compatibleWith: const [3]), isNull);
      expect(store.childrenOf(1).map((node) => node.id), [2, 3]);
      expect(store.ancestorsOf(4).map((node) => node.id), [2, 1]);
      expect(store.descendantsOf(1).map((node) => node.id), [2, 3, 4]);
      expect(store.siblingsOf(2), isEmpty);
      expect(store.siblingsOf(3).map((node) => node.id), isEmpty);
      expect(
        store
            .descendantsOf(1, compatibleWith: const [3]).map((node) => node.id),
        [3],
      );
    });

    test('rejects assigning more than one semantic parent to a child', () {
      final store = AccessibilityFactStore.empty()
          .addNode(const FactNode(id: 1, widgetType: 'Column'))
          .addNode(const FactNode(id: 2, widgetType: 'Row'))
          .addNode(const FactNode(id: 3, widgetType: 'Text'))
          .addParent(parentId: 1, childId: 3);

      expect(
        () => store.addParent(parentId: 2, childId: 3),
        throwsArgumentError,
      );
    });
  });
}
