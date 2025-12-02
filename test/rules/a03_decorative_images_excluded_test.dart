import 'package:flutter_a11y_lints/src/rules/a03_decorative_images_excluded.dart';
import 'package:test/test.dart';

import 'test_semantic_utils.dart';

void main() {
  group('A03 - decorative images excluded', () {
    test('flags Image.asset with decorative keyword', () async {
      final tree = await buildTestSemanticTree('''
        const Image.asset('assets/background_pattern.png')
      ''');

      final violations = A03DecorativeImagesExcluded.checkTree(tree);
      expect(violations, hasLength(1));
      expect(violations.single.assetPath, contains('background_pattern'));
    });

    test('does not flag when excludeFromSemantics is true', () async {
      final tree = await buildTestSemanticTree('''
        const Image.asset(
          'assets/bg_texture.png',
          excludeFromSemantics: true,
        )
      ''');

      final violations = A03DecorativeImagesExcluded.checkTree(tree);
      expect(violations, isEmpty);
    });

    test('does not flag when semanticLabel provided', () async {
      final tree = await buildTestSemanticTree('''
        const Image.asset(
          'assets/wallpaper.png',
          semanticLabel: 'Aurora background',
        )
      ''');

      final violations = A03DecorativeImagesExcluded.checkTree(tree);
      expect(violations, isEmpty);
    });

    test('ignores non-decorative assets', () async {
      final tree = await buildTestSemanticTree('''
        const Image.asset('assets/logo.png')
      ''');

      final violations = A03DecorativeImagesExcluded.checkTree(tree);
      expect(violations, isEmpty);
    });

    test('skips dynamic asset names to avoid false positives', () async {
      final tree = await buildTestSemanticTree(
        'Image.asset(assetName)',
        extraDeclarations: "const assetName = 'assets/background_pattern.png';",
      );

      final violations = A03DecorativeImagesExcluded.checkTree(tree);
      expect(violations, isEmpty);
    });
  });
}
