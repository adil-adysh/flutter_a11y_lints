import 'dart:io';

import 'package:flutter_a11y_lints/src/rules/faql_rule_runner.dart';
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
        .where((s) => s.code == 'a05_no_redundant_button_semantics')
        .toList();
    runner = FaqlRuleRunner(rules: filtered);
  });

  group('A05 - no redundant button semantics (FAQL)', () {
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

      final violations = runner.run(tree);
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

      final violations = runner.run(tree);
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

      final violations = runner.run(tree);
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

      final violations = runner.run(tree);
      expect(violations, hasLength(1));
    });

    test('does not flag Semantics around non-button widgets', () async {
      final tree = await buildTestSemanticTree('''
        Semantics(
          child: Text('Not a button'),
        )
      ''');

      final violations = runner.run(tree);
      expect(violations, isEmpty);
    });
  });
}
