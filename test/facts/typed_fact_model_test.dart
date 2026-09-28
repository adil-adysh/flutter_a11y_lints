import 'package:flutter_a11y_lints/src/facts/model/evidence.dart';
import 'package:flutter_a11y_lints/src/facts/model/structure_facts.dart';
import 'package:flutter_a11y_lints/src/facts/model/role_action_facts.dart';
import 'package:flutter_a11y_lints/src/facts/model/exposure_facts.dart';
import 'package:flutter_a11y_lints/src/facts/model/composition_facts.dart';
import 'package:flutter_a11y_lints/src/facts/model/naming_facts.dart';
import 'package:flutter_a11y_lints/src/facts/model/state_facts.dart';
import 'package:flutter_a11y_lints/src/facts/model/typed_node_facts.dart';
import 'package:flutter_a11y_lints/src/facts/fact_store.dart';
import 'package:test/test.dart';

void main() {
  test('derived evidence retains source spans and derivation inputs', () {
    const evidence = FactEvidence(
      provenance: FactProvenance.derived,
      knowledge: KnowledgeState.known,
      sources: [SourceSpan('file:///widget.dart', 12, 8)],
      inputs: [FactReference(nodeId: 7, kind: 'localLabel')],
    );

    expect(evidence.provenance, FactProvenance.derived);
    expect(evidence.knowledge, KnowledgeState.known);
    expect(evidence.sources.single.offset, 12);
    expect(evidence.inputs.single.nodeId, 7);
  });

  test('dynamic evidence cannot claim a known value', () {
    const evidence = FactEvidence.dynamic(
      sources: [SourceSpan('file:///widget.dart', 4, 3)],
    );

    expect(evidence.knowledge, KnowledgeState.dynamic);
    expect(evidence.provenance, FactProvenance.exact);
    expect(evidence.inputs, isEmpty);
  });

  test('source and accessibility edges remain distinct', () {
    const source = SourceWidgetNode(
      id: 1,
      widgetType: 'ListTile',
      evidence: FactEvidence(
        provenance: FactProvenance.exact,
        knowledge: KnowledgeState.known,
      ),
    );
    const slot = NamedSlotEdge(parentId: 1, name: 'leading', childId: 2);
    const accessibility = AccessibilityNode(
      id: 3,
      compositionNodeId: 1,
      evidence: FactEvidence(
        provenance: FactProvenance.derived,
        knowledge: KnowledgeState.known,
      ),
    );

    expect(source.widgetType, 'ListTile');
    expect(slot.childId, 2);
    expect(accessibility.compositionNodeId, 1);
  });

  test('typed graph keeps source, composition, and accessibility edges apart',
      () {
    const evidence = FactEvidence(
      provenance: FactProvenance.exact,
      knowledge: KnowledgeState.known,
    );
    const graph = AccessibilityFactGraph(
      sourceChildren: [SourceWidgetChildEdge(parentId: 1, childId: 2)],
      compositionNodes: [
        SemanticCompositionNode(id: 10, sourceWidgetId: 1, evidence: evidence),
        SemanticCompositionNode(id: 11, sourceWidgetId: 2, evidence: evidence),
      ],
      compositionChildren: [
        SemanticCompositionChildEdge(parentId: 10, childId: 11),
      ],
      accessibilityNodes: [
        AccessibilityNode(id: 20, compositionNodeId: 10, evidence: evidence),
        AccessibilityNode(id: 21, compositionNodeId: 11, evidence: evidence),
      ],
      accessibilityChildren: [
        AccessibilityChildEdge(parentId: 20, childId: 21),
      ],
    );

    expect(graph.sourceChildren.single.parentId, 1);
    expect(graph.compositionChildren.single.parentId, 10);
    expect(graph.accessibilityChildren.single.parentId, 20);
  });

  test('action availability and visual exposure are typed independently', () {
    const action = SemanticActionFact(
      kind: ActionKind.tap,
      availability: ActionAvailability.dynamic,
      evidence: FactEvidence.dynamic(),
    );
    const exposure = ExposureFact(
      visual: VisualVisibilityState.visuallyHidden,
      semantic: SemanticInclusionState.included,
      focus: AccessibilityFocusExposureState.exposed,
      evidence: FactEvidence(
        provenance: FactProvenance.derived,
        knowledge: KnowledgeState.known,
      ),
    );

    expect(action.availability, ActionAvailability.dynamic);
    expect(exposure.visual, VisualVisibilityState.visuallyHidden);
    expect(exposure.semantic, SemanticInclusionState.included);
  });

  test('composition, names, and control states retain unknown explicitly', () {
    const composition = CompositionFact(
      nodeCreation: NodeCreationState.createsNode,
      descendantDisposition: DescendantDisposition.replaced,
      evidence: FactEvidence(
        provenance: FactProvenance.exact,
        knowledge: KnowledgeState.known,
      ),
    );
    const name = NameFact.unknown();
    const state = ControlStateFact(enabled: EnabledState.unknown);

    expect(composition.descendantDisposition, DescendantDisposition.replaced);
    expect(name.state, NameState.unknown);
    expect(state.enabled, EnabledState.unknown);
    expect(state.evidence.knowledge, KnowledgeState.unknown);
  });

  test('raw semantic configuration records values and their evidence origin',
      () {
    const configuration = RawSemanticsConfigurationFact(
      container: KnownBooleanFact(
        state: KnownBooleanState.trueValue,
        origin: ArgumentEvidenceOrigin.literal,
      ),
      explicitChildNodes: KnownBooleanFact(
        state: KnownBooleanState.falseValue,
        origin: ArgumentEvidenceOrigin.defaultValue,
      ),
      excludeSemantics: KnownBooleanFact.unknown(),
      blockUserActions: KnownBooleanFact(
        state: KnownBooleanState.trueValue,
        origin: ArgumentEvidenceOrigin.resolved,
      ),
    );

    expect(configuration.container.state, KnownBooleanState.trueValue);
    expect(
      configuration.explicitChildNodes.origin,
      ArgumentEvidenceOrigin.defaultValue,
    );
    expect(configuration.excludeSemantics.state, KnownBooleanState.unknown);
  });

  test('typed node facts find an action without string fact names', () {
    const action = SemanticActionFact(
      kind: ActionKind.tap,
      availability: ActionAvailability.present,
      evidence: FactEvidence(
        provenance: FactProvenance.exact,
        knowledge: KnowledgeState.known,
      ),
    );
    const facts = TypedNodeFacts(actions: [action]);

    expect(facts.action(ActionKind.tap), same(action));
    expect(facts.action(ActionKind.dismiss), isNull);
  });

  test('fact-store views retain typed node facts independently of projection',
      () {
    const typed = TypedNodeFacts();
    final store = AccessibilityFactStore.empty().addTyped(19, typed);

    expect(store.conservative.typedFactsFor(19), same(typed));
    expect(store.expanded.typedFactsFor(19), same(typed));
  });

  test('legacy fact-store facts retain the complete typed evidence record', () {
    const evidence = FactEvidence(
      provenance: FactProvenance.derived,
      knowledge: KnowledgeState.known,
      sources: [SourceSpan('file:///widget.dart', 20, 6)],
      inputs: [FactReference(nodeId: 4, kind: 'semanticWrapper')],
    );
    const fact = SemanticFact(
      nodeId: 5,
      name: 'effectiveName',
      value: 'Save',
      evidence: evidence,
    );

    expect(fact.provenance, FactProvenance.derived);
    expect(fact.evidence, same(evidence));
    expect(fact.evidence.sources.single.offset, 20);
    expect(fact.evidence.inputs.single.kind, 'semanticWrapper');
  });

  test('store attaches a source node span to legacy-projected facts', () {
    final store = AccessibilityFactStore.empty()
        .addNode(
          const FactNode(
            id: 6,
            widgetType: 'TextButton',
            source: SourceSpan('file:///widget.dart', 31, 10),
          ),
        )
        .add(const SemanticFact(
          nodeId: 6,
          name: 'role',
          value: 'button',
          provenance: FactProvenance.exact,
        ));

    final fact = store.conservative.factsFor(6).single;
    expect(fact.evidence.sources.single.uri, 'file:///widget.dart');
    expect(fact.evidence.sources.single.offset, 31);
  });
}
