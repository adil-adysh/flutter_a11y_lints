import 'package:test/test.dart';

import '../rules/test_semantic_utils.dart';

void main() {
  group('SemanticTree grouping heuristics', () {
    test('Row children receive same layoutGroupId', () async {
      final tree = await buildTestSemanticTree("Row(children: [Text('A'), Text('B'), Text('C')])");

      final children = tree.root.children;
      expect(children.length, equals(3));

      final ids = children.map((c) => c.layoutGroupId).toSet();
      expect(ids.length, equals(1), reason: 'All Row children should share a layoutGroupId');
      expect(children.first.layoutGroupId, isNotNull);
    });

    test('Contiguous ListTile children receive listItemGroupId and primary marker', () async {
      final tree = await buildTestSemanticTree(
        "Column(children: [ListTile(title: Text('One')), ListTile(title: Text('Two')), SizedBox()])",
      );

      final children = tree.root.children;
      // Expect three children; first two are ListTile-like and grouped
      expect(children.length, equals(3));

      final first = children[0];
      final second = children[1];
      final third = children[2];

      expect(first.listItemGroupId, isNotNull);
      expect(first.listItemGroupId, equals(second.listItemGroupId));
      expect(first.isPrimaryInGroup, isTrue);
      expect(second.isPrimaryInGroup, isFalse);
      expect(third.listItemGroupId, isNull, reason: 'Non-list item should not be grouped');
    });
  });
}
