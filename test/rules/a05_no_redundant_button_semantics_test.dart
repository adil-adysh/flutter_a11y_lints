import 'package:flutter_a11y_lints/src/rules/a05_no_redundant_button_semantics.dart';
import 'package:test/test.dart';

import 'test_semantic_utils.dart';

void main() {
  group('A05 - no redundant button semantics', () {
    test('flags Semantics button:true wrapper', () async {
      final tree = await buildTestSemanticTree('''
        Semantics(
          button: true,
          child: IconButton(
            icon: const Icon('delete'),
            onPressed: () {},
          ),
        )
      ''');

      final violations = A05NoRedundantButtonSemantics.checkTree(tree);
      expect(violations, hasLength(1));
    });

    test('flags empty Semantics wrapper with IconButton child', () async {
      final tree = await buildTestSemanticTree('''
        Semantics(
          child: IconButton(
            icon: const Icon('settings'),
            tooltip: 'Settings',
            onPressed: () {},
          ),
        )
      ''');

      final violations = A05NoRedundantButtonSemantics.checkTree(tree);
      expect(violations, hasLength(1));
    });

    test('accepts Semantics wrapper that provides label', () async {
      final tree = await buildTestSemanticTree('''
        Semantics(
          label: 'Delete item',
          child: IconButton(
            icon: const Icon('delete'),
            onPressed: () {},
          ),
        )
      ''');

      final violations = A05NoRedundantButtonSemantics.checkTree(tree);
      expect(violations, isEmpty);
    });

    test('still flags when button:true is set even with label', () async {
      final tree = await buildTestSemanticTree('''
        Semantics(
          button: true,
          label: 'Delete',
          child: IconButton(
            icon: const Icon('delete'),
            onPressed: () {},
          ),
        )
      ''');

      final violations = A05NoRedundantButtonSemantics.checkTree(tree);
      expect(violations, hasLength(1));
    });

    test('does not flag Semantics around non-button widgets', () async {
      final tree = await buildTestSemanticTree('''
        Semantics(
          child: Text('Not a button'),
        )
      ''');

      final violations = A05NoRedundantButtonSemantics.checkTree(tree);
      expect(violations, isEmpty);
    });
  });
}
