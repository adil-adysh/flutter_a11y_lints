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
        .where((s) => s.code == 'a09_numeric_values_require_units')
        .toList();
    runner = FaqlRuleRunner(rules: filtered);
  });

  group('A09 - numeric values require units (FAQL)', () {
    test('flags numeric-only static label', () {
      final root = makeSemanticNode(
        label: '72',
        labelGuarantee: LabelGuarantee.hasStaticLabel,
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, hasLength(1));
    });

    test('flags decimal numeric label', () {
      final root = makeSemanticNode(
        label: '98.6',
        labelGuarantee: LabelGuarantee.hasStaticLabel,
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, hasLength(1));
    });

    test('flags numeric with whitespace', () {
      final root = makeSemanticNode(
        label: '  42  ',
        labelGuarantee: LabelGuarantee.hasStaticLabel,
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, hasLength(1));
    });

    test('passes when label includes units', () {
      final root = makeSemanticNode(
        label: '72 bpm',
        labelGuarantee: LabelGuarantee.hasStaticLabel,
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, isEmpty);
    });

    test('passes when label includes percent', () {
      final root = makeSemanticNode(
        label: '50%',
        labelGuarantee: LabelGuarantee.hasStaticLabel,
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, isEmpty);
    });

    test('passes when label is dynamic', () {
      final root = makeSemanticNode(
        label: '42',
        labelGuarantee: LabelGuarantee.hasLabelButDynamic,
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, isEmpty);
    });

    test('passes when no label', () {
      final root = makeSemanticNode(
        labelGuarantee: LabelGuarantee.none,
      );
      final tree = buildManualTree(root);

      final violations = runner.run(tree);
      expect(violations, isEmpty);
    });
  });
}
