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
          .addNode(const FactNode(id: 2, widgetType: 'IconButton', branch: Branch(7, 0)))
          .addNode(const FactNode(id: 3, widgetType: 'Text', branch: Branch(7, 1)))
          .addParent(parentId: 1, childId: 2)
          .addParent(parentId: 1, childId: 3);

      expect(store.descendantsOf(2).map((node) => node.id), isEmpty);
      expect(store.descendantsOf(1).map((node) => node.id), [2, 3]);
      expect(store.compatible(2, 3), isFalse);
    });
  });
}
