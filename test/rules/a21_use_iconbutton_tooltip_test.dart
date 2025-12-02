import 'package:flutter_a11y_lints/src/rules/a21_use_iconbutton_tooltip.dart';
import 'package:test/test.dart';

import 'test_semantic_utils.dart';

void main() {
  group('A21 - IconButton tooltip parameter', () {
    test('flags Tooltip-wrapped IconButton without tooltip param', () async {
      final tree = await buildTestSemanticTree('''
        Tooltip(
          message: 'Delete item',
          child: IconButton(
            icon: const Icon('delete'),
            onPressed: () {},
          ),
        )
      ''');

      final violations = A21UseIconButtonTooltip.checkTree(tree);
      expect(violations, hasLength(1));
    });

    test('IconButton.tooltip prevents violation even inside Tooltip', () async {
      final tree = await buildTestSemanticTree('''
        Tooltip(
          message: 'Archive item',
          child: IconButton(
            icon: const Icon('archive'),
            tooltip: 'Archive item',
            onPressed: () {},
          ),
        )
      ''');

      final violations = A21UseIconButtonTooltip.checkTree(tree);
      expect(violations, isEmpty);
    });

    test('Tooltip wrapping non-icon child is ignored', () async {
      final tree = await buildTestSemanticTree('''
        Tooltip(
          message: 'Helpful text',
          child: TextButton(
            onPressed: () {},
            child: const Text('Help'),
          ),
        )
      ''');

      final violations = A21UseIconButtonTooltip.checkTree(tree);
      expect(violations, isEmpty);
    });
  });
}
