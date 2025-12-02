import 'package:flutter_a11y_lints/src/rules/a18_avoid_hidden_focus_traps.dart';
import 'package:test/test.dart';

import 'test_semantic_utils.dart';

void main() {
  group('A18 - avoid hidden focus traps', () {
    test('flags Offstage(true) wrapping focusable button', () async {
      final tree = await buildTestSemanticTree('''
        Offstage(
          offstage: true,
          child: TextButton(
            onPressed: () {},
            child: const Text('Tap me'),
          ),
        )
      ''');

      final violations = A18AvoidHiddenFocusTraps.checkTree(tree);
      expect(violations, hasLength(1));
    });

    test('does not flag Offstage when offstage is false', () async {
      final tree = await buildTestSemanticTree('''
        Offstage(
          offstage: false,
          child: TextButton(
            onPressed: () {},
            child: const Text('Visible'),
          ),
        )
      ''');

      final violations = A18AvoidHiddenFocusTraps.checkTree(tree);
      expect(violations, isEmpty);
    });

    test('skips Offstage when offstage value is dynamic', () async {
      final tree = await buildTestSemanticTree(
        '''
        Offstage(
          offstage: shouldHide,
          child: TextButton(
            onPressed: () {},
            child: const Text('Maybe hidden'),
          ),
        )
        ''',
        extraDeclarations: 'const shouldHide = true;',
      );

      final violations = A18AvoidHiddenFocusTraps.checkTree(tree);
      expect(violations, isEmpty);
    });

    test('does not flag Offstage when child is not focusable', () async {
      final tree = await buildTestSemanticTree('''
        Offstage(
          offstage: true,
          child: const SizedBox(width: 10, height: 10),
        )
      ''');

      final violations = A18AvoidHiddenFocusTraps.checkTree(tree);
      expect(violations, isEmpty);
    });

    test('flags Visibility(visible: false) wrapping focusable child', () async {
      final tree = await buildTestSemanticTree('''
        Visibility(
          visible: false,
          child: IconButton(
            icon: const Icon('delete'),
            onPressed: () {},
            tooltip: 'Delete',
          ),
        )
      ''');

      final violations = A18AvoidHiddenFocusTraps.checkTree(tree);
      expect(violations, hasLength(1));
    });
  });
}
