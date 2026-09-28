import 'package:flutter_a11y_lints/src/facts/fact_store.dart';
import 'package:flutter_a11y_lints/src/facts/semantic_fact_extractor.dart';
import 'package:flutter_a11y_lints/src/facts/model/composition_facts.dart';
import 'package:flutter_a11y_lints/src/facts/model/evidence.dart';
import 'package:flutter_a11y_lints/src/facts/model/typed_node_facts.dart';
import 'package:flutter_a11y_lints/src/facts/model/role_action_facts.dart';
import 'package:flutter_a11y_lints/src/query/faql4.dart';
import 'package:test/test.dart';

import '../rules/test_semantic_utils.dart';

const _mergeCount = '''
@id example/merge-count
@rule-id merge_count
@severity warning
@mode conservative
from MergeSemanticsNode merge
where count(InteractiveControl control |
  control = merge.getADescendant()) >= 2
select merge, "Multiple actions"
''';

const _compatibleSibling = '''
@id example/compatible-sibling
@rule-id compatible_sibling
@severity warning
@mode conservative
from InteractiveControl control
where exists(InteractiveControl other |
  other = control.getASibling())
select control, "Compatible sibling"
''';

const _leadingImage = '''
@id example/leading-image
@rule-id leading_image
@severity warning
@mode conservative
from ImageNode image
where exists(ListTileNode tile | image = tile.getSlot("leading"))
select image, "Leading image"
''';

const _semanticReplacement = '''
@id example/semantic-replacement
@rule-id semantic_replacement
@severity warning
@mode conservative
from SemanticsNode wrapper
where wrapper.createsSemanticContainer() and
  wrapper.requiresExplicitChildNodes() and
  wrapper.replacesDescendantSemantics() and
  wrapper.blocksSemanticUserActions()
select wrapper, "Explicit replacement"
''';

AccessibilityFactStore _store({required bool sameBranch}) {
  return AccessibilityFactStore.empty()
      .addNode(const FactNode(id: 1, widgetType: 'MergeSemantics'))
      .addNode(
          const FactNode(id: 2, widgetType: 'IconButton', branch: Branch(1, 0)))
      .addNode(FactNode(
          id: 3,
          widgetType: 'IconButton',
          branch: Branch(1, sameBranch ? 0 : 1)))
      .addTyped(2, _tappableFacts)
      .addTyped(3, _tappableFacts)
      .addParent(parentId: 1, childId: 2)
      .addParent(parentId: 1, childId: 3);
}

const _tappableFacts = TypedNodeFacts(
  actions: [
    SemanticActionFact(
      kind: ActionKind.tap,
      availability: ActionAvailability.present,
      evidence: FactEvidence(
        provenance: FactProvenance.exact,
        knowledge: KnowledgeState.known,
      ),
    ),
  ],
);

void main() {
  test('counts only compatible descendant alternatives', () {
    final query = Faql4Compiler().compile(_mergeCount);

    expect(Faql4Evaluator().evaluate(query, _store(sameBranch: true)),
        hasLength(1));
    expect(
        Faql4Evaluator().evaluate(query, _store(sameBranch: false)), isEmpty);
  });

  test('does not combine nested source conditional alternatives', () async {
    final tree = await buildTestSemanticTree(
      '''MergeSemantics(
          child: Column(children: [
            purchasePending
                ? (secondaryPending
                    ? IconButton(icon: Icon('cancel'), tooltip: 'Cancel')
                    : IconButton(icon: Icon('hold'), tooltip: 'Hold'))
                : IconButton(icon: Icon('buy'), tooltip: 'Buy'),
          ]),
        )''',
      extraDeclarations: 'bool secondaryPending = DateTime.now().isUtc;',
    );
    final facts = SemanticFactExtractor().extract(tree).store;
    final query = Faql4Compiler().compile(_mergeCount);
    final siblingQuery = Faql4Compiler().compile(_compatibleSibling);

    expect(tree.roots, hasLength(1));
    expect(
      facts.nodes
          .where((node) => node.widgetType == 'IconButton')
          .map((node) => node.effectiveBranchPath.constraints.length),
      [2, 2, 1],
    );
    expect(Faql4Evaluator().evaluate(query, facts), isEmpty);
    expect(Faql4Evaluator().evaluate(siblingQuery, facts), isEmpty);
  });

  test('matches a direct named slot without crossing branches', () {
    final store = AccessibilityFactStore.empty()
        .addNode(const FactNode(id: 1, widgetType: 'ListTile'))
        .addNode(
            const FactNode(id: 2, widgetType: 'Image', branch: Branch(1, 0)))
        .addNode(
            const FactNode(id: 3, widgetType: 'Image', branch: Branch(1, 1)))
        .addSlot(parentId: 1, name: 'leading', childId: 2);
    final query = Faql4Compiler().compile(_leadingImage);

    expect(
      Faql4Evaluator().evaluate(query, store).map((hit) => hit.nodeId),
      [2],
    );
  });

  test('keeps serialized composition facts available for diagnostics', () {
    final store = AccessibilityFactStore.empty()
        .addNode(const FactNode(id: 1, widgetType: 'Semantics'))
        .add(const SemanticFact(
          nodeId: 1,
          name: 'createsSemanticContainer',
          value: true,
          provenance: FactProvenance.derived,
        ))
        .add(const SemanticFact(
          nodeId: 1,
          name: 'requiresExplicitChildNodes',
          value: true,
          provenance: FactProvenance.derived,
        ))
        .add(const SemanticFact(
          nodeId: 1,
          name: 'replacesDescendantSemantics',
          value: true,
          provenance: FactProvenance.derived,
        ))
        .add(const SemanticFact(
          nodeId: 1,
          name: 'blocksSemanticUserActions',
          value: true,
          provenance: FactProvenance.derived,
        ));

    expect(store.conservative.factsFor(1), hasLength(4));
  });

  test('reads composition predicates from typed facts before string facts', () {
    const evidence = FactEvidence(
      provenance: FactProvenance.derived,
      knowledge: KnowledgeState.known,
    );
    final store = AccessibilityFactStore.empty()
        .addNode(const FactNode(id: 1, widgetType: 'Semantics'))
        .addTyped(
          1,
          const TypedNodeFacts(
            composition: CompositionFact(
              nodeCreation: NodeCreationState.createsNode,
              childContribution: ChildContributionState.mustRemainExplicit,
              descendantDisposition: DescendantDisposition.replaced,
              merge: MergeState.notMerged,
              blocksUserActions: KnownBooleanFact(
                state: KnownBooleanState.trueValue,
                origin: ArgumentEvidenceOrigin.literal,
              ),
              evidence: evidence,
            ),
          ),
        );

    final query = Faql4Compiler().compile(_semanticReplacement);
    expect(Faql4Evaluator().evaluate(query, store), hasLength(1));
  });
}
