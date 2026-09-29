import 'package:flutter_a11y_lints/src/semantics/semantic_neighborhood.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:flutter_a11y_lints/src/facts/fact_store.dart';
import 'package:test/test.dart';

import '../rules/test_semantic_utils.dart';

void main() {
  test('source neighbors and siblings behave as expected', () {
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

    // previous/next in deterministic source order for middle node
    final middle = tree.physicalNodes.firstWhere((n) => n.widgetType == 'B');
    expect(nb.previousInSourceOrder(middle)!.widgetType, equals('A'));
    expect(nb.nextInSourceOrder(middle)!.widgetType, equals('C'));

    // Focus-list absence is not proof of hidden semantics. Only an explicit
    // hidden exposure state supports that conclusion.
    final hiddenNode =
        makeSemanticNode(widgetType: 'Hidden', isFocusable: false)
            .copyWith(exposureState: SemanticExposureState.hidden);
    final hiddenRoot =
        makeSemanticNode(widgetType: 'R', children: [hiddenNode]);
    final hiddenTree = buildManualTree(hiddenRoot);
    final hiddenNb = SemanticNeighborhood(hiddenTree);
    final hn =
        hiddenTree.physicalNodes.firstWhere((n) => n.widgetType == 'Hidden');
    expect(hiddenNb.isHidden(hn), isTrue);

    final unknownNode =
        makeSemanticNode(widgetType: 'Unknown', isFocusable: false)
            .copyWith(exposureState: SemanticExposureState.unknown);
    final unknownTree = buildManualTree(
      makeSemanticNode(widgetType: 'UnknownRoot', children: [unknownNode]),
    );
    final unknownNb = SemanticNeighborhood(unknownTree);
    final un = unknownTree.physicalNodes
        .firstWhere((node) => node.widgetType == 'Unknown');
    expect(unknownNb.isHidden(un), isFalse);

    // neighborsInSourceOrder yields nodes within radius
    final neighbors = nb.neighborsInSourceOrder(middle, radius: 1).toList();
    expect(neighbors.map((n) => n.widgetType).toList(), ['A', 'C']);

    // siblingsBefore / siblingsAfter
    final before = nb.siblingsBefore(tree.root.children[2]).toList();
    final after = nb.siblingsAfter(tree.root.children[0]).toList();
    expect(before.map((s) => s.widgetType).toList(), ['A', 'B']);
    expect(after.map((s) => s.widgetType).toList(), ['B', 'C']);

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

  test('uses complete nested branch paths for exclusivity', () {
    final outerThen = makeSemanticNode(widgetType: 'OuterThen').copyWith(
      branchPath: BranchPath([const Branch(1, 0), const Branch(2, 0)]),
    );
    final outerElse = makeSemanticNode(widgetType: 'OuterElse').copyWith(
      branchPath: BranchPath([const Branch(1, 1), const Branch(3, 0)]),
    );
    final tree = buildManualTree(
      makeSemanticNode(children: [outerThen, outerElse]),
    );

    expect(
      SemanticNeighborhood(tree).areMutuallyExclusive(
        tree.root.children[0],
        tree.root.children[1],
      ),
      isTrue,
    );
  });
}
