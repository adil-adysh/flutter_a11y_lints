import 'package:flutter_a11y_lints/src/semantics/semantic_neighborhood.dart';
import 'package:flutter_a11y_lints/src/facts/fact_store.dart';
// Tests for `SemanticTree` annotation and conservative accessibility
// projection.
//
// `SemanticTree` contains both a `physicalNodes` view (full DFS walk of the
// semantic IR) and a `provenAccessibilityNodes` view (independently exposed
// nodes). These tests ensure the two views stay consistent without treating
// source order as assistive-technology traversal order.
//
// When adding tests, use explicit traversal relationships for any ordering
// claim. `provenAccessibilityNodes` proves exposure only.

import 'package:flutter_a11y_lints/src/semantics/semantic_tree.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:test/test.dart';

import '../rules/test_semantic_utils.dart';

void main() {
  test('projects legacy action inputs into typed action availability', () {
    final node = makeSemanticNode(hasTap: true, hasLongPress: false);

    expect(node.actionAvailability(SemanticActionKind.tap),
        SemanticActionAvailability.present);
    expect(node.actionAvailability(SemanticActionKind.longPress),
        SemanticActionAvailability.absent);
  });

  group('SemanticTree.fromRoots', () {
    test('retains every conditional root alternative', () {
      final firstAlternative = makeSemanticNode(
        widgetType: 'FirstAlternative',
      ).copyWith(
        branchPath: BranchPath([Branch(1, 0)]),
      );
      final secondAlternative = makeSemanticNode(
        widgetType: 'SecondAlternative',
      ).copyWith(
        branchPath: BranchPath([Branch(1, 1)]),
      );

      final tree = SemanticTree.fromRoots([
        firstAlternative,
        secondAlternative,
      ]);

      expect(tree.roots.map((node) => node.widgetType), [
        'FirstAlternative',
        'SecondAlternative',
      ]);
      expect(tree.physicalNodes.map((node) => node.widgetType), [
        'FirstAlternative',
        'SecondAlternative',
      ]);
      expect(tree.root.widgetType, 'FirstAlternative');
    });
  });

  group('SemanticTree.fromRoot', () {
    test('collects exposed controls without inventing traversal order', () {
      final first = makeSemanticNode(widgetType: 'First', isFocusable: true);
      final second = makeSemanticNode(widgetType: 'Second', isFocusable: true);

      final tree = SemanticTree.fromRoot(
        makeSemanticNode(widgetType: 'Root', children: [first, second]),
      );

      expect(
        tree.provenAccessibilityNodes.map((node) => node.widgetType),
        containsAll(['First', 'Second']),
      );
      expect(tree.explicitTraversalNodes, isEmpty);
    });

    test('annotates traversal metadata', () {
      final childA = makeSemanticNode(widgetType: 'A');
      final grandChild = makeSemanticNode(widgetType: 'C', isFocusable: true);
      final childB = makeSemanticNode(widgetType: 'B', children: [grandChild]);
      final root =
          makeSemanticNode(widgetType: 'Root', children: [childA, childB]);

      final tree = SemanticTree.fromRoot(root);

      expect(tree.physicalNodes, hasLength(4));
      final annotatedRoot = tree.root;
      expect(annotatedRoot.id, isNotNull);
      expect(annotatedRoot.preOrderIndex, 0);

      final annotatedChildA =
          tree.physicalNodes.firstWhere((node) => node.widgetType == 'A');
      final annotatedChildB =
          tree.physicalNodes.firstWhere((node) => node.widgetType == 'B');

      expect(annotatedChildA.parentId, annotatedRoot.id);
      expect(annotatedChildA.depth, 1);
      expect(annotatedChildA.siblingIndex, 0);
      expect(annotatedChildB.siblingIndex, 1);
      expect(annotatedChildB.children.single.parentId, annotatedChildB.id);

      final focusableLabels =
          tree.accessibilityFocusNodes.map((node) => node.widgetType).toList();
      expect(focusableLabels, contains('C'));
    });

    test('omits merged and excluded descendants from independent projection',
        () {
      final mergedChild = makeSemanticNode(
        widgetType: 'Merged',
        mergesDescendants: true,
        isSemanticBoundary: true,
        isFocusable: true,
      );
      final mergedParent = makeSemanticNode(
        widgetType: 'Parent',
        mergesDescendants: true,
        isFocusable: true,
        children: [
          mergedChild,
          makeSemanticNode(widgetType: 'HiddenFocus', isFocusable: true),
        ],
      );
      final root = makeSemanticNode(
        widgetType: 'Root',
        children: [mergedParent],
        isFocusable: true,
      );

      final tree = SemanticTree.fromRoot(root);
      final focusWidgets =
          tree.accessibilityFocusNodes.map((n) => n.widgetType).toList();

      expect(focusWidgets, containsAll(['Root', 'Parent']));
      expect(focusWidgets, isNot(contains('Merged')));
      expect(focusWidgets, isNot(contains('HiddenFocus')));
      expect(
        tree.explicitTraversalNodes,
        isEmpty,
        reason: 'Widget order does not prove accessibility traversal order.',
      );
    });
  });

  group('Semantic IR pipeline', () {
    test('retains both unresolved top-level conditional alternatives',
        () async {
      final tree = await buildTestSemanticTree(
        '''purchasePending
            ? IconButton(icon: Icon('cancel'), tooltip: 'Cancel')
            : IconButton(icon: Icon('buy'), tooltip: 'Buy')''',
      );

      expect(tree.roots, hasLength(2));
      expect(
        tree.roots.map((node) => node.branchPath.constraints.single.value),
        [0, 1],
      );
      expect(tree.physicalNodes, hasLength(4));
    });

    test('retains nested conditional root alternatives with full paths',
        () async {
      final tree = await buildTestSemanticTree(
        '''purchasePending
            ? (secondaryPending
                ? IconButton(icon: Icon('cancel'), tooltip: 'Cancel')
                : IconButton(icon: Icon('hold'), tooltip: 'Hold'))
            : IconButton(icon: Icon('buy'), tooltip: 'Buy')''',
        extraDeclarations: 'bool secondaryPending = DateTime.now().isUtc;',
      );

      expect(tree.roots, hasLength(3));
      expect(
        tree.roots
            .map((node) => node.branchPath.constraints
                .map((constraint) => '${constraint.group}:${constraint.value}')
                .join(','))
            .toList(),
        ['0:0,1:0', '0:0,1:1', '0:1'],
      );
    });
  });

  group('SemanticNeighborhood', () {
    test('provides sibling and neighbor helpers', () {
      final siblingLeft = makeSemanticNode(widgetType: 'Left');
      final siblingRight = makeSemanticNode(widgetType: 'Right');
      final root = makeSemanticNode(
        widgetType: 'Root',
        children: [siblingLeft, siblingRight],
      );

      final tree = SemanticTree.fromRoot(root);
      final neighborhood = SemanticNeighborhood(tree);
      final rightNode =
          tree.physicalNodes.firstWhere((node) => node.widgetType == 'Right');

      final siblingNames =
          neighborhood.siblingsOf(rightNode).map((node) => node.widgetType);
      expect(siblingNames, containsAll(['Left', 'Right']));

      final previous = neighborhood.previousInSourceOrder(rightNode);
      expect(previous?.widgetType, 'Left');

      final next = neighborhood.nextInSourceOrder(rightNode);
      expect(next, isNull);

      expect(
        neighborhood.areMutuallyExclusive(siblingLeft, siblingRight),
        isFalse,
      );
    });
  });
}
