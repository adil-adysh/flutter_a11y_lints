import 'dart:io';

import 'package:flutter_a11y_lints/rules/faql_rule_runner.dart';
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
        .where((s) => s.code == 'a15_map_custom_gestures_to_on_tap')
        .toList();
    runner = FaqlRuleRunner(rules: filtered);
  });

  group('A15 - map custom gestures to onTap (FAQL)', () {
    test('flags GestureDetector with onTap and no semantics', () {
      final root = makeSemanticNode(
        widgetType: 'GestureDetector',
        labelGuarantee: LabelGuarantee.none,
        children: [
          makeSemanticNode(
            widgetType: 'Icon',
          ),
        ],
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, hasLength(1));
    });

    test('passes when GestureDetector has label', () {
      final root = makeSemanticNode(
        widgetType: 'GestureDetector',
        label: 'Tap to select',
        labelGuarantee: LabelGuarantee.hasStaticLabel,
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, isEmpty);
    });

    test('passes when wrapped in Semantics', () {
      final root = makeSemanticNode(
        widgetType: 'Semantics',
        children: [
          makeSemanticNode(
            widgetType: 'GestureDetector',
            labelGuarantee: LabelGuarantee.none,
          ),
        ],
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, isEmpty);
    });
  });
}
