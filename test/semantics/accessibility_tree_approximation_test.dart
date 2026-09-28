import 'package:flutter_a11y_lints/src/semantics/accessibility_tree_approximation.dart';
import 'package:test/test.dart';

import '../rules/test_semantic_utils.dart';

void main() {
  test('omits merged descendants from the independent accessibility projection',
      () async {
    final tree = await buildTestSemanticTree('''
MergeSemantics(
  child: Row(children: [
    IconButton(icon: Icon('add'), onPressed: () {}),
  ]),
)
''');

    final approximation = AccessibilityTreeApproximation.fromSemanticTree(tree);
    final button = tree.physicalNodes.singleWhere(
      (node) => node.widgetType == 'IconButton',
    );

    expect(approximation.forSemanticNode(button.id!), isNull);
  });
}
