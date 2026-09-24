import 'package:flutter_a11y_lints/src/facts/fact_store.dart';
import 'package:flutter_a11y_lints/src/query/faql4.dart';
import 'package:test/test.dart';

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

AccessibilityFactStore _store({required bool sameBranch}) {
  return AccessibilityFactStore.empty()
      .addNode(const FactNode(id: 1, widgetType: 'MergeSemantics'))
      .addNode(const FactNode(id: 2, widgetType: 'IconButton', branch: Branch(1, 0)))
      .addNode(FactNode(id: 3, widgetType: 'IconButton', branch: Branch(1, sameBranch ? 0 : 1)))
      .add(const SemanticFact(nodeId: 2, name: 'tap', value: true, provenance: FactProvenance.exact))
      .add(const SemanticFact(nodeId: 3, name: 'tap', value: true, provenance: FactProvenance.exact))
      .addParent(parentId: 1, childId: 2)
      .addParent(parentId: 1, childId: 3);
}

void main() {
  test('counts only compatible descendant alternatives', () {
    final query = Faql4Compiler().compile(_mergeCount);

    expect(Faql4Evaluator().evaluate(query, _store(sameBranch: true)), hasLength(1));
    expect(Faql4Evaluator().evaluate(query, _store(sameBranch: false)), isEmpty);
  });
}
