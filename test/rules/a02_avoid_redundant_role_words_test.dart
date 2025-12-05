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
      'a02_avoid_redundant_role_words.faql',
    ));
    final ruleText = await File(rulePath).readAsString();
    final parser = FaqlParser();
    final rule = parser.parseRule(ruleText);
    final spec = FaqlRuleSpec.fromRule(rule, sourcePath: rulePath);
    runner = FaqlRuleRunner(rules: [spec]);
  });

  group('A02 - avoid redundant role words (FAQL)', () {
    test('flags tooltip text containing button keyword', () async {
      final tree = await buildTestSemanticTree('''
        IconButton(
          icon: const Icon('save'),
          tooltip: 'Save button',
          onPressed: () {},
        )
      ''');

      final violations = runner.run(tree);
      expect(violations, hasLength(1));
      expect(violations.single.spec.code, 'a02_avoid_redundant_role_words');
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

      final violations = runner.run(tree);
      expect(violations, hasLength(1));
      expect(violations.single.spec.code, 'a02_avoid_redundant_role_words');
    });

    test('ignores visible text children containing role words', () async {
      final tree = await buildTestSemanticTree('''
        TextButton(
          onPressed: () {},
          child: const Text('Submit button'),
        )
      ''');

      final violations = runner.run(tree);
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

      final violations = runner.run(tree);
      expect(violations, isEmpty);
    });
  });
}
