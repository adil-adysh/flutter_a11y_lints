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
        .where((s) => s.code == 'a13_single_role_composite_control')
        .toList();
    runner = FaqlRuleRunner(rules: filtered);
  });

  group('A13 - single role composite control (FAQL)', () {
    test('flags semantics container with multiple focusable children', () {
      final root = makeSemanticNode(
        widgetType: 'Semantics',
        isSemanticBoundary: true,
        isFocusable: false,
        children: [
          makeSemanticNode(
            widgetType: 'IconButton',
            isFocusable: true,
            isEnabled: true,
          ),
          makeSemanticNode(
            widgetType: 'IconButton',
            isFocusable: true,
            isEnabled: true,
          ),
        ],
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, hasLength(1));
    });

    test('does not flag pure layout containers', () {
      final root = makeSemanticNode(
        widgetType: 'Row',
        isFocusable: false,
        children: [
          makeSemanticNode(
            widgetType: 'IconButton',
            isFocusable: true,
            isEnabled: true,
          ),
          makeSemanticNode(
            widgetType: 'IconButton',
            isFocusable: true,
            isEnabled: true,
          ),
        ],
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, isEmpty);
    });

    test('does not flag MergeSemantics', () {
      final root = makeSemanticNode(
        widgetType: 'MergeSemantics',
        isFocusable: false,
        children: [
          makeSemanticNode(
            widgetType: 'IconButton',
            isFocusable: true,
            isEnabled: true,
          ),
          makeSemanticNode(
            widgetType: 'IconButton',
            isFocusable: true,
            isEnabled: true,
          ),
        ],
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, isEmpty);
    });

    test('passes when only one focusable child', () {
      final root = makeSemanticNode(
        widgetType: 'Semantics',
        isSemanticBoundary: true,
        isFocusable: false,
        children: [
          makeSemanticNode(
            widgetType: 'IconButton',
            isFocusable: true,
            isEnabled: true,
          ),
        ],
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, isEmpty);
    });
  });
}
