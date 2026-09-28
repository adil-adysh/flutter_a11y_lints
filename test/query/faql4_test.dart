import 'package:flutter_a11y_lints/src/facts/fact_store.dart';
import 'package:flutter_a11y_lints/src/facts/model/evidence.dart';
import 'package:flutter_a11y_lints/src/facts/model/exposure_facts.dart';
import 'package:flutter_a11y_lints/src/facts/model/naming_facts.dart';
import 'package:flutter_a11y_lints/src/facts/model/role_action_facts.dart';
import 'package:flutter_a11y_lints/src/facts/model/state_facts.dart';
import 'package:flutter_a11y_lints/src/facts/model/typed_node_facts.dart';
import 'package:flutter_a11y_lints/src/query/faql4.dart';
import 'package:test/test.dart';

void main() {
  group('FAQL 4', () {
    test('parses and evaluates a conservative unlabeled-control query', () {
      const source = '''
@id flutter-a11y/a01/unlabeled-interactive
@rule-id a01_unlabeled_interactive
@severity warning
@mode conservative
from InteractiveControl control
where control.isDefinitelyExposed() and control.isDefinitelyEnabled() and control.isDefinitelyUnlabeled()
select control, "Interactive control must have an accessible label."
''';
      final query = Faql4Compiler().compile(source);
      final facts = AccessibilityFactStore.empty()
          .addNode(const FactNode(id: 1, widgetType: 'IconButton'))
          .addTyped(
            1,
            const TypedNodeFacts(
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
              controlState: ControlStateFact(
                enabled: EnabledState.enabled,
                evidence: FactEvidence(
                  provenance: FactProvenance.exact,
                  knowledge: KnowledgeState.known,
                ),
              ),
              exposure: ExposureFact(
                visual: VisualVisibilityState.visible,
                semantic: SemanticInclusionState.included,
                focus: AccessibilityFocusExposureState.exposed,
                evidence: FactEvidence(
                  provenance: FactProvenance.exact,
                  knowledge: KnowledgeState.known,
                ),
              ),
              name: NameFact(
                state: NameState.absent,
                evidence: FactEvidence(
                  provenance: FactProvenance.exact,
                  knowledge: KnowledgeState.known,
                ),
              ),
            ),
          );

      expect(Faql4Evaluator().evaluate(query, facts), hasLength(1));
    });

    test('rejects negation of a partial predicate in conservative mode', () {
      const source = '''
@id example/unsafe
@rule-id example
@severity warning
@mode conservative
from SemanticNode node
where not node.hasAccessibleLabel()
select node, "unsafe"
''';

      expect(() => Faql4Compiler().compile(source),
          throwsA(isA<Faql4ValidationError>()));
    });

    test('supports typed equality comparisons on standard-library accessors',
        () {
      const source = '''
@id example/icon-button
@rule-id example_icon_button
@severity warning
@mode conservative
from SemanticNode node
where node.getWidgetType() = "IconButton"
select node, "Icon button"
''';
      final query = Faql4Compiler().compile(source);
      final facts = AccessibilityFactStore.empty()
          .addNode(const FactNode(id: 1, widgetType: 'IconButton'));

      expect(Faql4Evaluator().evaluate(query, facts), hasLength(1));
    });
  });
}
