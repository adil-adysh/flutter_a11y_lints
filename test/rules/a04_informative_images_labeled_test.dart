import 'dart:io';

import 'package:flutter_a11y_lints/rules/faql_rule_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_semantic_utils.dart';

void main() {
  late FaqlRuleRunner runner;

  setUpAll(() async {
    final rulesDir = p.normalize(p.join(
      Directory.current.path,
      'lib',
      'src',
      'rules',
    ));

    final specs = await FaqlRuleRunner.loadFromDirectory(rulesDir);
    final filtered = specs
        .where((s) => s.code == 'a04_informative_images_labeled')
        .toList();
    runner = FaqlRuleRunner(rules: filtered);
  });

  group('A04 - informative images labeled (FAQL)', () {
    test('CircleAvatar with backgroundImage requires semanticsLabel', () async {
      final tree = await buildTestSemanticTree('''
        CircleAvatar(
          backgroundImage: NetworkImage('https://example.com/avatar.png'),
        )
      ''');

      final violations = runner.run(tree);
      expect(violations, hasLength(1));
    });

    test('CircleAvatar with semanticsLabel is allowed', () async {
      final tree = await buildTestSemanticTree('''
        CircleAvatar(
          backgroundImage: NetworkImage('https://example.com/avatar.png'),
          semanticsLabel: 'Profile photo of Casey',
        )
      ''');

      final violations = runner.run(tree);
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

      final violations = runner.run(tree);
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

      final violations = runner.run(tree);
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

      final violations = runner.run(tree);
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

      final violations = runner.run(tree);
      expect(violations, isEmpty);
    });
  });
}
