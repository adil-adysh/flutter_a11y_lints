import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:test/test.dart';

import '../rules/test_semantic_utils.dart';

void main() {
  test('known Offstage and hidden Visibility map visual and semantic states separately',
      () async {
    final offstage = await buildTestSemanticTree(
      "Offstage(offstage: true, child: Text('Hidden'))",
    );
    final visibility = await buildTestSemanticTree(
      "Visibility(visible: false, child: Text('Hidden'))",
    );

    for (final tree in [offstage, visibility]) {
      expect(tree.root.exposureState, SemanticExposureState.hidden);
      expect(tree.root.inclusionState, SemanticInclusionState.excluded);
      expect(tree.accessibilityFocusNodes, isEmpty);
    }
  });

  test('dynamic visibility remains unknown rather than excluded', () async {
    final tree = await buildTestSemanticTree(
      "Visibility(visible: isVisible, child: Text('Maybe'))",
      extraDeclarations: 'bool isVisible = DateTime.now().isUtc;',
    );

    expect(tree.root.exposureState, SemanticExposureState.unknown);
    expect(tree.root.inclusionState, SemanticInclusionState.unknown);
  });
}
