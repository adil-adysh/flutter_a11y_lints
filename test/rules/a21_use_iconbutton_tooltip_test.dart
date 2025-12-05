import 'dart:io';

import 'package:flutter_a11y_lints/src/rules/faql_rule_runner.dart';
import 'package:flutter_a11y_lints/src/semantics/known_semantics.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
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
        .where((s) => s.code == 'a21_use_iconbutton_tooltip')
        .toList();
    runner = FaqlRuleRunner(rules: filtered);
  });

  group('A21 - IconButton tooltip parameter (FAQL)', () {
    test('flags Tooltip-wrapped IconButton without tooltip param', () {
      final root = makeSemanticNode(
        widgetType: 'Tooltip',
        children: [
          makeSemanticNode(
            widgetType: 'IconButton',
            controlKind: ControlKind.iconButton,
            labelSource: LabelSource.none,
          ),
        ],
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, hasLength(1));
    });

    test('IconButton.tooltip prevents violation even inside Tooltip', () {
      final root = makeSemanticNode(
        widgetType: 'Tooltip',
        children: [
          makeSemanticNode(
            widgetType: 'IconButton',
            controlKind: ControlKind.iconButton,
            labelSource: LabelSource.tooltip,
          ),
        ],
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, isEmpty);
    });

    test('Tooltip wrapping non-icon child is ignored', () {
      final root = makeSemanticNode(
        widgetType: 'Tooltip',
        children: [
          makeSemanticNode(
            widgetType: 'TextButton',
            controlKind: ControlKind.textButton,
          ),
        ],
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, isEmpty);
    });
  });
}
