import 'package:test/test.dart';

import '../rules/test_semantic_utils.dart';

void main() {
  group('SemanticTree grouping edge cases', () {
    test('Nested containers preserve separate layout groups', () async {
      final tree = await buildTestSemanticTree(
        "Column(children: [Row(children: [Text('A'), Text('B')]), Row(children: [Text('C')])])",
      );

      // Root children are two Rows; each Row's children should share a
      // layoutGroupId distinct from the other Row.
      final rootChildren = tree.root.children;
      expect(rootChildren.length, equals(2));

      final firstRowChildren = rootChildren[0].children;
      final secondRowChildren = rootChildren[1].children;

      expect(firstRowChildren.map((c) => c.layoutGroupId).toSet().length, equals(1));
      expect(secondRowChildren.map((c) => c.layoutGroupId).toSet().length, equals(1));
      expect(firstRowChildren.first.layoutGroupId, isNot(secondRowChildren.first.layoutGroupId));
    });

    test('Mixed runs only group contiguous list-like children', () async {
      final tree = await buildTestSemanticTree(
        "Column(children: [ListTile(title: Text('One')), SizedBox(), ListTile(title: Text('Two')), ListTile(title: Text('Three'))])",
      );

      final children = tree.root.children;
      expect(children.length, equals(4));

      // first ListTile is a standalone group, second/third form a contiguous run
      final first = children[0];
      final second = children[2];
      final third = children[3];

      expect(first.listItemGroupId, isNotNull);
      expect(second.listItemGroupId, isNotNull);
      expect(third.listItemGroupId, isNotNull);
      expect(second.listItemGroupId, equals(third.listItemGroupId));
      expect(first.listItemGroupId, isNot(equals(second.listItemGroupId)));
    });

    test('IndexedSemantics children are treated as list items', () async {
      final tree = await buildTestSemanticTree(
        "Column(children: [IndexedSemantics(index: 5, child: ListTile(title: Text('Idx'))), ListTile(title: Text('Next'))])",
      );

      final children = tree.root.children;
      expect(children.length, equals(2));
      final first = children[0];
      final second = children[1];

      expect(first.semanticIndex, isNotNull);
      expect(first.listItemGroupId, isNotNull);
      expect(second.listItemGroupId, isNotNull);
      // both are contiguous list-like: should share group
      expect(first.listItemGroupId, equals(second.listItemGroupId));
    });

    test('ListView children are grouped by layout heuristics', () async {
      final tree = await buildTestSemanticTree(
        "ListView(children: [ListTile(title: Text('A')), ListTile(title: Text('B'))])",
      );

      final children = tree.root.children;
      expect(children.length, equals(2));
      expect(children[0].layoutGroupId, isNotNull);
      expect(children[0].layoutGroupId, equals(children[1].layoutGroupId));
    });
  });
}
