import 'package:flutter_a11y_lints/src/facts/semantic_fact_extractor.dart';
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
  });
}
