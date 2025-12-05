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
        .where((s) => s.code == 'a22_respect_widget_semantic_boundaries')
        .toList();
    runner = FaqlRuleRunner(rules: filtered);
  });

  group('A22 - respect widget semantic boundaries (FAQL)', () {
    test('flags MergeSemantics wrapping ListTile', () {
      final root = makeSemanticNode(
        widgetType: 'MergeSemantics',
        children: [
          makeSemanticNode(
            widgetType: 'ListTile',
          ),
        ],
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, hasLength(1));
    });

    test('flags MergeSemantics wrapping CheckboxListTile', () {
      final root = makeSemanticNode(
        widgetType: 'MergeSemantics',
        children: [
          makeSemanticNode(
            widgetType: 'CheckboxListTile',
          ),
        ],
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, hasLength(1));
    });

    test('does not flag when ListTile is not direct child', () {
      final root = makeSemanticNode(
        widgetType: 'MergeSemantics',
        children: [
          makeSemanticNode(
            widgetType: 'Column',
            children: [
              makeSemanticNode(
                widgetType: 'ListTile',
              ),
            ],
          ),
        ],
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, isEmpty);
    });

    test('flags MergeSemantics wrapping SwitchListTile', () {
      final root = makeSemanticNode(
        widgetType: 'MergeSemantics',
        children: [
          makeSemanticNode(
            widgetType: 'SwitchListTile',
          ),
        ],
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, hasLength(1));
    });

    test('flags MergeSemantics wrapping RadioListTile', () {
      final root = makeSemanticNode(
        widgetType: 'MergeSemantics',
        children: [
          makeSemanticNode(
            widgetType: 'RadioListTile',
          ),
        ],
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, hasLength(1));
    });
  });
}
