import 'package:flutter_a11y_lints/src/semantics/known_semantics.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:test/test.dart';

import '../rules/test_semantic_utils.dart';

void main() {
  group('SemanticBuilder wrappers', () {
    test('Semantics widget overrides label and role', () async {
      final tree = await buildTestSemanticTree('''
Semantics(
  label: 'Approve purchase',
  button: true,
  child: IconButton(
    icon: const Icon('add'),
    tooltip: 'Add',
    onPressed: () {},
  ),
)
''');

      final root = tree.root;
      expect(root.widgetType, 'Semantics');
      expect(root.label, 'Approve purchase');
      expect(root.labelSource, LabelSource.semanticsWidget);
      expect(root.role, SemanticRole.button);
      expect(root.isSemanticBoundary, isTrue);
      expect(root.mergesDescendants, isTrue);
      expect(root.children, hasLength(1));
    });

    test('ExcludeSemantics suppresses descendant focus nodes', () async {
      final tree = await buildTestSemanticTree('''
ExcludeSemantics(
  child: IconButton(
    icon: const Icon('add'),
    tooltip: 'Add',
    onPressed: () {},
  ),
)
''');

      expect(tree.root.excludesDescendants, isTrue);
      expect(tree.accessibilityFocusNodes, isEmpty);
    });

    test('MergeSemantics aggregates child labels', () async {
      final tree = await buildTestSemanticTree('''
MergeSemantics(
  child: Row(
    children: [
      IconButton(
        icon: const Icon('delete'),
        tooltip: 'Delete',
        onPressed: () {},
      ),
      const Text('Item'),
    ],
  ),
)
''');

      expect(tree.root.mergesDescendants, isTrue);
      expect(tree.root.explicitChildLabel, contains('Item'));
      expect(tree.root.labelGuarantee, isNot(LabelGuarantee.none));
    });

    test('BlockSemantics marks overlays that block behind', () async {
      final tree = await buildTestSemanticTree('''
BlockSemantics(
  child: IconButton(
    icon: const Icon('close'),
    tooltip: 'Close',
    onPressed: () {},
  ),
)
''');

      expect(tree.root.blocksBehind, isTrue);
      expect(tree.root.children.single.widgetType, 'IconButton');
    });

    test('IndexedSemantics captures semantic index', () async {
      final tree = await buildTestSemanticTree('''
IndexedSemantics(
  index: 4,
  child: TextButton(
    child: const Text('Delete'),
    onPressed: () {},
  ),
)
''');

      expect(tree.root.semanticIndex, 4);
      expect(tree.root.children.single.controlKind, ControlKind.textButton);
    });
  });
}
