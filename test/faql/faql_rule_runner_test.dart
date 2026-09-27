import 'package:flutter_a11y_lints/rules/faql_rule_runner.dart';
import 'package:flutter_a11y_lints/src/query/faql4.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:test/test.dart';
import 'dart:io';

import '../rules/test_semantic_utils.dart';

void main() {
  test('reports a definitely unlabeled interactive semantic node', () {
    const source = '''
@id flutter-a11y/a01/unlabeled-interactive
@rule-id a01_unlabeled_interactive
@severity warning
@mode conservative
from InteractiveControl control
where control.isDefinitelyExposed() and control.isDefinitelyEnabled() and control.isDefinitelyUnlabeled()
select control, "Interactive control must have an accessible label."
''';
    final tree = buildManualTree(makeSemanticNode());
    final runner = FaqlRuleRunner(rules: [Faql4Compiler().compile(source)]);

    expect(runner.run(tree), hasLength(1));
  });

  test('A01 ignores disabled and dynamically labelled controls', () {
    const source = '''
@id example/a01
@rule-id a01
@severity warning
@mode conservative
from InteractiveControl control
where control.isDefinitelyExposed() and control.isDefinitelyEnabled() and control.isDefinitelyUnlabeled()
select control, "Control needs a label."
''';
    final disabled = buildManualTree(makeSemanticNode(isEnabled: false));
    final dynamic = buildManualTree(makeSemanticNode(
      labelGuarantee: LabelGuarantee.hasLabelButDynamic,
    ));
    final runner = FaqlRuleRunner(rules: [Faql4Compiler().compile(source)]);

    expect(runner.run(disabled), isEmpty);
    expect(runner.run(dynamic), isEmpty);
  });

  test('A01 ignores an interactable child under dynamic exclusion', () async {
    const source = '''
@id example/a01-dynamic-exclusion
@rule-id a01
@severity warning
@mode conservative
from InteractiveControl control
where control.isDefinitelyExposed() and control.isDefinitelyEnabled() and control.isDefinitelyUnlabeled()
select control, "Control needs a label."
''';
    final tree = await buildTestSemanticTree('''
ExcludeSemantics(
  excluding: purchasePending,
  child: IconButton(
    icon: const Icon('delete'),
    onPressed: () {},
  ),
)
''');

    final runner = FaqlRuleRunner(rules: [Faql4Compiler().compile(source)]);

    expect(runner.run(tree), isEmpty);
  });

  test('merge rule excludes disabled interactive descendants', () {
    final source =
        File('lib/rules/core/merge_multiple_actions.faql').readAsStringSync();
    final enabled = makeSemanticNode(widgetType: 'IconButton');
    final disabled = makeSemanticNode(
      widgetType: 'IconButton',
      isEnabled: false,
    );
    final tree = buildManualTree(makeSemanticNode(
      widgetType: 'MergeSemantics',
      children: [enabled, disabled],
    ));
    final runner = FaqlRuleRunner(rules: [Faql4Compiler().compile(source)]);

    expect(runner.run(tree), isEmpty);
  });

  test('reports two enabled independent actions under MergeSemantics',
      () async {
    final tree = await buildTestSemanticTree('''
MergeSemantics(child: Column(children: [
  IconButton(icon: Icon('edit'), tooltip: 'Edit'),
  IconButton(icon: Icon('delete'), tooltip: 'Delete'),
]))
''');
    final source =
        File('lib/rules/core/merge_multiple_actions.faql').readAsStringSync();

    expect(
      FaqlRuleRunner(rules: [Faql4Compiler().compile(source)]).run(tree),
      hasLength(1),
    );
  });

  test('reports an effectively unnamed ListTile leading image', () async {
    final tree = await buildTestSemanticTree(
      "ListTile(leading: Image.network('https://example.test/photo.png'))",
    );
    final source = File('lib/rules/core/a04_list_tile_image_labeled.faql')
        .readAsStringSync();
    final runner = FaqlRuleRunner(rules: [Faql4Compiler().compile(source)]);

    expect(runner.run(tree), hasLength(1));
  });

  test('A04 ignores excluded and non-leading images', () async {
    final excluded = await buildTestSemanticTree(
      "ListTile(leading: Image.network('https://x', excludeFromSemantics: true))",
    );
    final trailing = await buildTestSemanticTree(
      "ListTile(trailing: Image.network('https://x'))",
    );
    final source = File('lib/rules/core/a04_list_tile_image_labeled.faql')
        .readAsStringSync();
    final runner = FaqlRuleRunner(rules: [Faql4Compiler().compile(source)]);

    expect(runner.run(excluded), isEmpty);
    expect(runner.run(trailing), isEmpty);
  });

  test('A04 ignores a leading image under dynamic exclusion', () async {
    final tree = await buildTestSemanticTree('''
ExcludeSemantics(
  excluding: purchasePending,
  child: ListTile(leading: Image.network('https://example.test/photo.png')),
)
''');
    final source = File('lib/rules/core/a04_list_tile_image_labeled.faql')
        .readAsStringSync();
    final runner = FaqlRuleRunner(rules: [Faql4Compiler().compile(source)]);

    expect(runner.run(tree), isEmpty);
  });

  test('reports a ListTile directly wrapped by MergeSemantics', () async {
    final tree = await buildTestSemanticTree(
      "MergeSemantics(child: ListTile(title: Text('Account')))",
    );
    final source =
        File('lib/rules/core/a22_respect_widget_semantic_boundaries.faql')
            .readAsStringSync();

    expect(
      FaqlRuleRunner(rules: [Faql4Compiler().compile(source)]).run(tree),
      hasLength(1),
    );
  });

  test('A22 ignores nested and non-ListTile children', () async {
    final nested = await buildTestSemanticTree(
      "MergeSemantics(child: Column(children: [ListTile(title: Text('Account'))]))",
    );
    final nonTile = await buildTestSemanticTree(
      "MergeSemantics(child: Text('Account'))",
    );
    final source =
        File('lib/rules/core/a22_respect_widget_semantic_boundaries.faql')
            .readAsStringSync();
    final runner = FaqlRuleRunner(rules: [Faql4Compiler().compile(source)]);

    expect(runner.run(nested), isEmpty);
    expect(runner.run(nonTile), isEmpty);
  });
}
