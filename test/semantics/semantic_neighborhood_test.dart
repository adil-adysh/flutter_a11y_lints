import 'package:test/test.dart';

import '../rules/test_semantic_utils.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_neighborhood.dart';
// helpers available from test utilities

void main() {
  test('neighbors, siblings and focus navigation behave as expected', () {
    // Build a simple tree: root -> [a, b, c]
    final a = makeSemanticNode(widgetType: 'A', label: 'a', isFocusable: true);
    final b = makeSemanticNode(widgetType: 'B', label: 'b', isFocusable: true);
    final c = makeSemanticNode(widgetType: 'C', label: 'c', isFocusable: true);

    final root = makeSemanticNode(widgetType: 'Root', children: [a, b, c]);
    final tree = buildManualTree(root);

    final nb = SemanticNeighborhood(tree);

    // siblingsOf
    final siblings = nb.siblingsOf(tree.root.children[1]);
    expect(siblings.map((s) => s.widgetType).toList(), ['A', 'B', 'C']);

    // previous/next in reading order for middle node
    final middle = tree.physicalNodes.firstWhere((n) => n.widgetType == 'B');
    expect(nb.previousInReadingOrder(middle)!.widgetType, equals('A'));
    expect(nb.nextInReadingOrder(middle)!.widgetType, equals('C'));

    // focus navigation
    final focusNext = nb.nextFocusable(middle);
    final focusPrev = nb.previousFocusable(middle);
    expect(focusNext, isNotNull);
    expect(focusPrev, isNotNull);

    // hidden check: a node not in accessibilityFocusNodes is hidden
    final hiddenNode =
        makeSemanticNode(widgetType: 'Hidden', isFocusable: false);
    final hiddenRoot =
        makeSemanticNode(widgetType: 'R', children: [hiddenNode]);
    final hiddenTree = buildManualTree(hiddenRoot);
    final hiddenNb = SemanticNeighborhood(hiddenTree);
    final hn =
        hiddenTree.physicalNodes.firstWhere((n) => n.widgetType == 'Hidden');
    expect(hiddenNb.isHidden(hn), isTrue);

    // neighborsInReadingOrder yields nodes within radius
    final neighbors = nb.neighborsInReadingOrder(middle, radius: 1).toList();
    expect(neighbors.map((n) => n.widgetType).toList(), ['A', 'C']);

    // siblingsBefore / siblingsAfter
    final before = nb.siblingsBefore(tree.root.children[2]).toList();
    final after = nb.siblingsAfter(tree.root.children[0]).toList();
    expect(before.map((s) => s.widgetType).toList(), ['A', 'B']);
    expect(after.map((s) => s.widgetType).toList(), ['B', 'C']);

    // sameLayoutGroup / sameListItemGroup: set ids manually
    final g1 = makeSemanticNode(widgetType: 'X', layoutGroupId: 7);
    final g2 = makeSemanticNode(widgetType: 'Y', layoutGroupId: 7);
    final gRoot = makeSemanticNode(widgetType: 'Groot', children: [g1, g2]);
    final gTree = buildManualTree(gRoot);
    final gNb = SemanticNeighborhood(gTree);
    final gNode = gTree.physicalNodes.firstWhere((n) => n.widgetType == 'X');
    expect(gNb.sameLayoutGroup(gNode).map((n) => n.widgetType).toList(),
        ['X', 'Y']);

    // mutually exclusive
    final m1 =
        makeSemanticNode(widgetType: 'M1', branchGroupId: 3, branchValue: 0);
    final m2 =
        makeSemanticNode(widgetType: 'M2', branchGroupId: 3, branchValue: 1);
    final mRoot = makeSemanticNode(widgetType: 'Mroot', children: [m1, m2]);
    final mTree = buildManualTree(mRoot);
    final mNb = SemanticNeighborhood(mTree);
    final ma = mTree.physicalNodes.firstWhere((n) => n.widgetType == 'M1');
    final mb = mTree.physicalNodes.firstWhere((n) => n.widgetType == 'M2');
    expect(mNb.areMutuallyExclusive(ma, mb), isTrue);
  });
}
