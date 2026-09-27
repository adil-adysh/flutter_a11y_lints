import 'package:flutter_a11y_lints/src/facts/semantic_fact_extractor.dart';
import 'package:flutter_a11y_lints/src/facts/fact_store.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_tree.dart';
import 'package:test/test.dart';

import '../rules/test_semantic_utils.dart';

void main() {
  group('SemanticFactExtractor', () {
    test('distinguishes proven absence from dynamic and unknown labels', () {
      final absent = makeSemanticNode(labelGuarantee: LabelGuarantee.none);
      final dynamic = makeSemanticNode(
        labelGuarantee: LabelGuarantee.hasLabelButDynamic,
      );
      final static = makeSemanticNode(
        label: 'Delete',
        labelGuarantee: LabelGuarantee.hasStaticLabel,
      );
      final tree = SemanticTree.fromRoot(
        makeSemanticNode(children: [absent, dynamic, static]),
      );

      final facts = SemanticFactExtractor().extract(tree);
      final childIds = tree.root.children.map((node) => node.id!).toList();
      expect(facts.labelStateFor(childIds[0]), LabelState.absent);
      expect(facts.labelStateFor(childIds[1]), LabelState.dynamic);
      expect(facts.labelStateFor(childIds[2]), LabelState.static);
    });

    test('keeps heuristic nodes with no label evidence unknown', () {
      final heuristic = makeSemanticNode().copyWith(isHeuristic: true);
      final tree = SemanticTree.fromRoot(heuristic);

      final facts = SemanticFactExtractor().extract(tree);

      expect(facts.labelStateFor(tree.root.id!), LabelState.unknown);
    });

    test('extracts named slots and literal primitive properties', () async {
      final tree = await buildTestSemanticTree('''
ListTile(
  leading: const Icon('avatar'),
  title: const Text('Account'),
  trailing: const IconButton(icon: Icon('delete'), tooltip: 'Delete'),
)
''');

      final facts = SemanticFactExtractor().extract(tree);
      final rootId = tree.root.id!;

      expect(facts.slotsFor(rootId).keys,
          containsAll(['leading', 'title', 'trailing']));
      expect(facts.propertyValueFor(rootId, 'title'), isNull);
      expect(facts.propertyValueFor(tree.root.children.last.id!, 'tooltip'),
          'Delete');
    });

    test('does not claim an explicitly excluded image is not excluded',
        () async {
      final tree = await buildTestSemanticTree('''
Image.network(
  'https://example.com/avatar.png',
  excludeFromSemantics: true,
)
''');

      final facts = SemanticFactExtractor().extract(tree);
      final image = tree.physicalNodes.singleWhere(
        (node) => node.widgetType == 'Image',
      );
      final imageFacts = facts.store.conservative.factsFor(image.id!);

      expect(
        imageFacts.any(
          (fact) =>
              fact.name == 'isDefinitelyNotExcludedFromSemantics' &&
              fact.value == true,
        ),
        isFalse,
      );
    });

    test('proves default and explicit-false image semantics are not excluded',
        () async {
      final defaultTree = await buildTestSemanticTree('''
Image.network('https://example.com/default.png')
''');
      final explicitFalseTree = await buildTestSemanticTree('''
Image.network(
  'https://example.com/explicit.png',
  excludeFromSemantics: false,
)
''');

      bool hasNotExcludedFact(SemanticTree tree) {
        final extracted = SemanticFactExtractor().extract(tree);
        final image = tree.physicalNodes.singleWhere(
          (node) => node.widgetType == 'Image',
        );
        return extracted.store.conservative.factsFor(image.id!).any(
              (fact) =>
                  fact.name == 'isDefinitelyNotExcludedFromSemantics' &&
                  fact.value == true,
            );
      }

      expect(hasNotExcludedFact(defaultTree), isTrue);
      expect(hasNotExcludedFact(explicitFalseTree), isTrue);
    });

    test('emits visibility only for explicit hiding widgets', () async {
      final tree = await buildTestSemanticTree('''
Offstage(offstage: true, child: const IconButton(icon: Icon('delete')))
''');

      final facts = SemanticFactExtractor().extract(tree);

      expect(
          facts.propertyValueFor(tree.root.id!, 'visibilityState'), 'hidden');
    });

    test('preserves every nested branch constraint in facts', () {
      final branchChild = makeSemanticNode().copyWith(
        branchPath: BranchPath([Branch(1, 0), Branch(2, 1)]),
      );
      final tree =
          SemanticTree.fromRoot(makeSemanticNode(children: [branchChild]));

      final facts = SemanticFactExtractor().extract(tree);
      final childId = tree.root.children.single.id!;
      expect(
        facts.store.nodeById(childId)!.effectiveBranchPath.constraints,
        hasLength(2),
      );
    });
  });
}
