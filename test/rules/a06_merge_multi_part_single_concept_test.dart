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
        .where((s) => s.code == 'a06_merge_multi_part_single_concept')
        .toList();
    runner = FaqlRuleRunner(rules: filtered);
  });

  group('A06 - merge multi-part single concept (FAQL)', () {
    test('flags interactive node with two labeled children', () {
      final root = makeSemanticNode(
        widgetType: 'Row',
        isEnabled: true,
        hasTap: true,
        children: [
          makeSemanticNode(
              label: 'Add', labelGuarantee: LabelGuarantee.hasStaticLabel),
          makeSemanticNode(
              label: 'Item', labelGuarantee: LabelGuarantee.hasStaticLabel),
        ],
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, hasLength(1));
    });

    test('passes when mergesDescendants is true', () {
      final root = makeSemanticNode(
        widgetType: 'Row',
        isEnabled: true,
        hasTap: true,
        mergesDescendants: true,
        children: [
          makeSemanticNode(
              label: 'Add', labelGuarantee: LabelGuarantee.hasStaticLabel),
          makeSemanticNode(
              label: 'Item', labelGuarantee: LabelGuarantee.hasStaticLabel),
        ],
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, isEmpty);
    });

    test('passes when only one labeled child', () {
      final root = makeSemanticNode(
        widgetType: 'Row',
        isEnabled: true,
        hasTap: true,
        children: [
          makeSemanticNode(
              label: 'Add', labelGuarantee: LabelGuarantee.hasStaticLabel),
          makeSemanticNode(labelGuarantee: LabelGuarantee.none),
        ],
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, isEmpty);
    });

    test('passes when not interactive', () {
      final root = makeSemanticNode(
        widgetType: 'Row',
        isEnabled: true,
        hasTap: false,
        children: [
          makeSemanticNode(
              label: 'Add', labelGuarantee: LabelGuarantee.hasStaticLabel),
          makeSemanticNode(
              label: 'Item', labelGuarantee: LabelGuarantee.hasStaticLabel),
        ],
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, isEmpty);
    });
  });
}
