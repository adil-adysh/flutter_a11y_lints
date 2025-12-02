import 'package:flutter_a11y_lints/src/semantics/semantic_neighborhood.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_tree.dart';
import 'package:test/test.dart';

import '../rules/test_semantic_utils.dart';

void main() {
  group('SemanticTree.fromRoot', () {
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

    test('skips descendants of merged/excluded nodes from focus order', () {
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
      final parentNode = tree.accessibilityFocusNodes
          .firstWhere((node) => node.widgetType == 'Parent');
      expect(parentNode.focusOrderIndex, 1);
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

      final previous = neighborhood.previousInReadingOrder(rightNode);
      expect(previous?.widgetType, 'Left');

      final next = neighborhood.nextInReadingOrder(rightNode);
      expect(next, isNull);

      expect(
        neighborhood.areMutuallyExclusive(siblingLeft, siblingRight),
        isFalse,
      );
    });
  });
}
