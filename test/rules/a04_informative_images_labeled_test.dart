import 'package:flutter_a11y_lints/src/rules/a04_informative_images_labeled.dart';
import 'package:test/test.dart';

import 'test_semantic_utils.dart';

void main() {
  group('A04 - informative images labeled', () {
    test('CircleAvatar with backgroundImage requires semanticsLabel', () async {
      final tree = await buildTestSemanticTree('''
        CircleAvatar(
          backgroundImage: NetworkImage('https://example.com/avatar.png'),
        )
      ''');

      final violations = A04InformativeImagesLabeled.checkTree(tree);
      expect(violations, hasLength(1));
    });

    test('CircleAvatar with semanticsLabel is allowed', () async {
      final tree = await buildTestSemanticTree('''
        CircleAvatar(
          backgroundImage: NetworkImage('https://example.com/avatar.png'),
          semanticsLabel: 'Profile photo of Casey',
        )
      ''');

      final violations = A04InformativeImagesLabeled.checkTree(tree);
      expect(violations, isEmpty);
    });

    test('Semantics wrapper with label satisfies CircleAvatar requirement',
        () async {
      final tree = await buildTestSemanticTree('''
        Semantics(
          label: 'Profile photo of Jamie',
          child: CircleAvatar(
            backgroundImage: NetworkImage('https://example.com/avatar.png'),
          ),
        )
      ''');

      final violations = A04InformativeImagesLabeled.checkTree(tree);
      expect(violations, isEmpty);
    });

    test('ListTile.leading Image.network without semanticLabel is flagged',
        () async {
      final tree = await buildTestSemanticTree('''
        ListTile(
          leading: Image.network('https://example.com/avatar.png'),
          title: const Text('Jamie Lee'),
        )
      ''');

      final violations = A04InformativeImagesLabeled.checkTree(tree);
      expect(violations, hasLength(1));
    });

    test('ListTile.leading Image.network with semanticLabel passes', () async {
      final tree = await buildTestSemanticTree('''
        ListTile(
          leading: Image.network(
            'https://example.com/avatar.png',
            semanticLabel: 'Jamie Lee profile photo',
          ),
          title: const Text('Jamie Lee'),
        )
      ''');

      final violations = A04InformativeImagesLabeled.checkTree(tree);
      expect(violations, isEmpty);
    });

    test('ListTile.leading Image inside Semantics label passes', () async {
      final tree = await buildTestSemanticTree('''
        ListTile(
          leading: Semantics(
            label: 'Jamie avatar',
            child: Image.network('https://example.com/avatar.png'),
          ),
          title: const Text('Jamie Lee'),
        )
      ''');

      final violations = A04InformativeImagesLabeled.checkTree(tree);
      expect(violations, isEmpty);
    });
  });
}
