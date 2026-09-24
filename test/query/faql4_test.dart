import 'package:flutter_a11y_lints/src/facts/fact_store.dart';
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
where control.isDefinitelyEnabled() and control.isDefinitelyUnlabeled()
select control, "Interactive control must have an accessible label."
''';
      final query = Faql4Compiler().compile(source);
      final facts = AccessibilityFactStore.empty()
          .addNode(const FactNode(id: 1, widgetType: 'IconButton'))
          .add(const SemanticFact(nodeId: 1, name: 'tap', value: true, provenance: FactProvenance.exact))
          .add(const SemanticFact(nodeId: 1, name: 'enabled', value: true, provenance: FactProvenance.exact))
          .add(const SemanticFact(nodeId: 1, name: 'labelState', value: 'absent', provenance: FactProvenance.exact));

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

      expect(() => Faql4Compiler().compile(source), throwsA(isA<Faql4ValidationError>()));
    });
  });
}
