import 'package:flutter_a11y_lints/src/rules/a02_avoid_redundant_role_words.dart';
import 'package:test/test.dart';

import 'test_semantic_utils.dart';

void main() {
  group('A02 - avoid redundant role words', () {
    test('flags tooltip text containing button keyword', () async {
      final tree = await buildTestSemanticTree('''
        IconButton(
          icon: const Icon('save'),
          tooltip: 'Save button',
          onPressed: () {},
        )
      ''');

      final violations = A02AvoidRedundantRoleWords.checkTree(tree);
      expect(violations, hasLength(1));
      expect(violations.single.redundantWords, contains('button'));
    });

    test('flags Semantics label with redundant role word', () async {
      final tree = await buildTestSemanticTree('''
        Semantics(
          label: 'Settings button',
          child: IconButton(
            icon: const Icon('settings'),
            onPressed: () {},
          ),
        )
      ''');

      final violations = A02AvoidRedundantRoleWords.checkTree(tree);
      expect(violations, hasLength(1));
      expect(violations.single.redundantWords, contains('button'));
    });

    test('ignores visible text children containing role words', () async {
      final tree = await buildTestSemanticTree('''
        TextButton(
          onPressed: () {},
          child: const Text('Submit button'),
        )
      ''');

      final violations = A02AvoidRedundantRoleWords.checkTree(tree);
      expect(violations, isEmpty);
    });

    test('does not flag tooltip without redundant words', () async {
      final tree = await buildTestSemanticTree('''
        IconButton(
          icon: const Icon('save'),
          tooltip: 'Save changes',
          onPressed: () {},
        )
      ''');

      final violations = A02AvoidRedundantRoleWords.checkTree(tree);
      expect(violations, isEmpty);
    });
  });
}
