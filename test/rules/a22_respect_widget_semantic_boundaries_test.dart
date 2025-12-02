import 'package:flutter_a11y_lints/src/rules/a22_respect_widget_semantic_boundaries.dart';
import 'package:test/test.dart';

import 'test_semantic_utils.dart';

void main() {
  group('A22 - respect widget semantic boundaries', () {
    test('flags MergeSemantics wrapping ListTile', () async {
      final tree = await buildTestSemanticTree('''
        MergeSemantics(
          child: ListTile(
            title: const Text('Notifications'),
            onTap: () {},
          ),
        )
      ''');

      final violations = A22RespectWidgetSemanticBoundaries.checkTree(tree);
      expect(violations, hasLength(1));
    });

    test('flags MergeSemantics wrapping CheckboxListTile', () async {
      final tree = await buildTestSemanticTree('''
        MergeSemantics(
          child: CheckboxListTile(
            title: const Text('Enable reminders'),
            value: true,
            onChanged: (bool? value) {},
          ),
        )
      ''');

      final violations = A22RespectWidgetSemanticBoundaries.checkTree(tree);
      expect(violations, hasLength(1));
    });

    test('does not flag when ListTile is not direct child', () async {
      final tree = await buildTestSemanticTree('''
        MergeSemantics(
          child: Column(
            children: [
              ListTile(
                title: const Text('Account'),
                onTap: () {},
              ),
            ],
          ),
        )
      ''');

      final violations = A22RespectWidgetSemanticBoundaries.checkTree(tree);
      expect(violations, isEmpty);
    });
  });
}
