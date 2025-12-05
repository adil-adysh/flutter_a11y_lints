import 'dart:io';

import 'package:flutter_a11y_lints/src/faql/parser.dart';
import 'package:flutter_a11y_lints/rules/faql_rule_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_semantic_utils.dart';

void main() {
  late FaqlRuleRunner runner;

  setUpAll(() async {
    final rulePath = p.normalize(p.join(
      Directory.current.path,
      'lib',
      'src',
      'rules',
      'a03_decorative_images_excluded.faql',
    ));
    final ruleText = await File(rulePath).readAsString();
    final parser = FaqlParser();
    final rule = parser.parseRule(ruleText);
    final spec = FaqlRuleSpec.fromRule(rule, sourcePath: rulePath);
    runner = FaqlRuleRunner(rules: [spec]);
  });

  group('A03 - decorative images excluded (FAQL)', () {
    test('flags Image.asset with decorative keyword', () async {
      final tree = await buildTestSemanticTree('''
        const Image.asset('assets/background_pattern.png')
      ''');

      final violations = runner.run(tree);
      expect(violations, hasLength(1));
      expect(violations.single.spec.code, 'a03_decorative_images_excluded');
    });

    test('does not flag when excludeFromSemantics is true', () async {
      final tree = await buildTestSemanticTree('''
        const Image.asset(
          'assets/bg_texture.png',
          excludeFromSemantics: true,
        )
      ''');

      final violations = runner.run(tree);
      expect(violations, isEmpty);
    });

    test('does not flag when wrapped in ExcludeSemantics ancestor', () async {
      final tree = await buildTestSemanticTree('''
        const ExcludeSemantics(
          child: Image.asset('assets/bg_overlay.png'),
        )
      ''');

      final violations = runner.run(tree);
      expect(violations, isEmpty);
    });

    test('does not flag when semanticLabel provided', () async {
      final tree = await buildTestSemanticTree('''
        const Image.asset(
          'assets/wallpaper.png',
          semanticLabel: 'Aurora background',
        )
      ''');

      final violations = runner.run(tree);
      expect(violations, isEmpty);
    });

    test('ignores non-decorative assets', () async {
      final tree = await buildTestSemanticTree('''
        const Image.asset('assets/logo.png')
      ''');

      final violations = runner.run(tree);
      expect(violations, isEmpty);
    });

    test('skips dynamic asset names to avoid false positives', () async {
      final tree = await buildTestSemanticTree(
        'Image.asset(assetName)',
        extraDeclarations: "const assetName = 'assets/background_pattern.png';",
      );

      final violations = runner.run(tree);
      expect(violations, isEmpty);
    });
  });
}
