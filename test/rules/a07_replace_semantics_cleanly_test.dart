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
    final filtered =
        specs.where((s) => s.code == 'a07_replace_semantics_cleanly').toList();
    runner = FaqlRuleRunner(rules: filtered);
  });

  group('A07 - replace semantics cleanly (FAQL)', () {
    test('flags Semantics with custom label not excluding labeled children',
        () {
      final root = makeSemanticNode(
        widgetType: 'Semantics',
        label: 'Complete action',
        labelSource: LabelSource.semanticsWidget,
        labelGuarantee: LabelGuarantee.hasStaticLabel,
        excludesDescendants: false,
        children: [
          makeSemanticNode(
            label: 'Save',
            labelGuarantee: LabelGuarantee.hasStaticLabel,
          ),
        ],
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, hasLength(1));
    });

    test('passes when Semantics excludes descendants', () {
      final root = makeSemanticNode(
        widgetType: 'Semantics',
        label: 'Complete action',
        labelSource: LabelSource.semanticsWidget,
        labelGuarantee: LabelGuarantee.hasStaticLabel,
        excludesDescendants: true,
        children: [
          makeSemanticNode(
            label: 'Save',
            labelGuarantee: LabelGuarantee.hasStaticLabel,
          ),
        ],
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, isEmpty);
    });

    test('passes when children have no labels', () {
      final root = makeSemanticNode(
        widgetType: 'Semantics',
        label: 'Complete action',
        labelSource: LabelSource.semanticsWidget,
        labelGuarantee: LabelGuarantee.hasStaticLabel,
        excludesDescendants: false,
        children: [
          makeSemanticNode(
            labelGuarantee: LabelGuarantee.none,
          ),
        ],
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, isEmpty);
    });

    test('passes when labelSource is not semanticsWidget', () {
      final root = makeSemanticNode(
        widgetType: 'IconButton',
        label: 'Save',
        labelSource: LabelSource.tooltip,
        labelGuarantee: LabelGuarantee.hasStaticLabel,
        excludesDescendants: false,
        children: [
          makeSemanticNode(
            label: 'Icon',
            labelGuarantee: LabelGuarantee.hasStaticLabel,
          ),
        ],
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, isEmpty);
    });
  });
}
