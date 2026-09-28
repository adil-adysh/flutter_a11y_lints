import 'package:flutter_a11y_lints/src/facts/model/evidence.dart';
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
}
