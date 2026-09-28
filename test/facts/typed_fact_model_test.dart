import 'package:flutter_a11y_lints/src/facts/model/evidence.dart';
import 'package:flutter_a11y_lints/src/facts/model/structure_facts.dart';
import 'package:flutter_a11y_lints/src/facts/model/role_action_facts.dart';
import 'package:flutter_a11y_lints/src/facts/model/exposure_facts.dart';
import 'package:flutter_a11y_lints/src/facts/model/composition_facts.dart';
import 'package:flutter_a11y_lints/src/facts/model/naming_facts.dart';
import 'package:flutter_a11y_lints/src/facts/model/state_facts.dart';
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
  });
}
