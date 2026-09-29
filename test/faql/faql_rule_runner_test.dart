import 'package:flutter_a11y_lints/rules/faql_rule_runner.dart';
import 'package:flutter_a11y_lints/src/query/faql4.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:test/test.dart';
import 'dart:io';

import '../rules/test_semantic_utils.dart';

void main() {
  test('reports a definitely unlabeled interactive semantic node', () async {
    const source = '''
@id flutter-a11y/a01/unlabeled-interactive
@rule-id a01_unlabeled_interactive
@severity warning
@mode conservative
from InteractiveControl control
where control.isDefinitelyExposed() and control.isDefinitelyEnabled() and control.isDefinitelyUnlabeled()
select control, "Interactive control must have an accessible label."
''';
    final tree = await buildTestSemanticTree(
      "IconButton(icon: Icon('delete'), onPressed: () {})",
    );
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
  IconButton(icon: Icon('edit'), tooltip: 'Edit', onPressed: () {}),
  IconButton(icon: Icon('delete'), tooltip: 'Delete', onPressed: () {}),
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

  test('A09 reports only statically proven bare numeric names', () async {
    final numeric = await buildTestSemanticTree(
      "Semantics(label: '72', child: SizedBox())",
    );
    final unit = await buildTestSemanticTree(
      "Semantics(label: '72 bpm', child: SizedBox())",
    );
    final dynamic = await buildTestSemanticTree(
      'Semantics(label: heartRateLabel, child: SizedBox())',
      extraDeclarations: "String heartRateLabel = '72';",
    );
    final source = File('lib/rules/core/a09_numeric_values_require_units.faql')
        .readAsStringSync();
    final runner = FaqlRuleRunner(rules: [Faql4Compiler().compile(source)]);

    expect(runner.run(numeric), hasLength(1));
    expect(runner.run(unit), isEmpty);
    expect(runner.run(dynamic), isEmpty);
  });

  test('A02 reports redundant role words only from static explicit names',
      () async {
    final redundant = await buildTestSemanticTree(
      "IconButton(icon: Icon('delete'), tooltip: 'Delete button', onPressed: () {})",
    );
    final textChild = await buildTestSemanticTree(
      "TextButton(child: Text('Delete button'), onPressed: () {})",
    );
    final dynamic = await buildTestSemanticTree(
      "IconButton(icon: Icon('delete'), tooltip: actionLabel, onPressed: () {})",
      extraDeclarations: "String actionLabel = 'Delete button';",
    );
    final source = File('lib/rules/core/a02_avoid_redundant_role_words.faql')
        .readAsStringSync();
    final runner = FaqlRuleRunner(rules: [Faql4Compiler().compile(source)]);

    expect(runner.run(redundant), hasLength(1));
    expect(runner.run(textChild), isEmpty);
    expect(runner.run(dynamic), isEmpty);
  });

  test('A15 reports only a proven unlabeled GestureDetector tap action',
      () async {
    final violation = await buildTestSemanticTree(
      'GestureDetector(onTap: () {}, child: SizedBox())',
    );
    final labeled = await buildTestSemanticTree(
      "GestureDetector(onTap: () {}, child: Text('Activate'))",
    );
    final excluded = await buildTestSemanticTree(
      'GestureDetector(onTap: () {}, excludeFromSemantics: true, child: SizedBox())',
    );
    final dynamic = await buildTestSemanticTree(
      'GestureDetector(onTap: handler, child: SizedBox())',
      extraDeclarations: 'void Function()? handler;',
    );
    final source = File('lib/rules/core/a15_map_custom_gestures_to_on_tap.faql')
        .readAsStringSync();
    final runner = FaqlRuleRunner(rules: [Faql4Compiler().compile(source)]);

    expect(runner.run(violation), hasLength(1));
    expect(runner.run(labeled), isEmpty);
    expect(runner.run(excluded), isEmpty);
    expect(runner.run(dynamic), isEmpty);
  });

  test('A03 reports only a static unexcluded decorative asset', () async {
    final violation = await buildTestSemanticTree(
      "Image.asset('assets/decorative_background.png')",
    );
    final labeled = await buildTestSemanticTree(
      "Image.asset('assets/decorative_background.png', semanticLabel: 'Sky')",
    );
    final excluded = await buildTestSemanticTree(
      "Image.asset('assets/decorative_background.png', excludeFromSemantics: true)",
    );
    final dynamic = await buildTestSemanticTree(
      'Image.asset(assetPath)',
      extraDeclarations:
          "String assetPath = 'assets/decorative_background.png';",
    );
    final source = File('lib/rules/core/a03_decorative_images_excluded.faql')
        .readAsStringSync();
    final runner = FaqlRuleRunner(rules: [Faql4Compiler().compile(source)]);

    expect(runner.run(violation), hasLength(1));
    expect(runner.run(labeled), isEmpty);
    expect(runner.run(excluded), isEmpty);
    expect(runner.run(dynamic), isEmpty);
  });

  test('A05 reports a role-only Semantics wrapper around a button', () async {
    final violation = await buildTestSemanticTree(
      "Semantics(button: true, child: IconButton(icon: Icon('save'), onPressed: () {}))",
    );
    final labeled = await buildTestSemanticTree(
      "Semantics(button: true, label: 'Save draft', child: IconButton(icon: Icon('save'), onPressed: () {}))",
    );
    final dynamic = await buildTestSemanticTree(
      'Semantics(button: true, label: semanticLabel, child: IconButton(icon: Icon("save"), onPressed: () {}))',
      extraDeclarations: "String semanticLabel = 'Save draft';",
    );
    final source = File('lib/rules/core/a05_no_redundant_button_semantics.faql')
        .readAsStringSync();
    final runner = FaqlRuleRunner(rules: [Faql4Compiler().compile(source)]);

    expect(runner.run(violation), hasLength(1));
    expect(runner.run(labeled), isEmpty);
    expect(runner.run(dynamic), isEmpty);
  });

  test('A06 reports a non-merging action with two static named descendants',
      () async {
    final violation = await buildTestSemanticTree('''
GestureDetector(
  onTap: () {},
  child: Column(children: [Text('Price'), Text('Discount')]),
)
''');
    final oneName = await buildTestSemanticTree(
      "GestureDetector(onTap: () {}, child: Text('Price'))",
    );
    final source =
        File('lib/rules/core/a06_merge_multi_part_single_concept.faql')
            .readAsStringSync();
    final runner = FaqlRuleRunner(rules: [Faql4Compiler().compile(source)]);

    expect(runner.run(violation), hasLength(1));
    expect(runner.run(oneName), isEmpty);
  });

  test('A07 reports a replacement that discards a child tap action', () async {
    final missingAction = await buildTestSemanticTree('''
Semantics(
  excludeSemantics: true,
  label: 'Delete item',
  child: IconButton(icon: Icon('delete'), onPressed: () {}),
)
''');
    final replacementAction = await buildTestSemanticTree('''
Semantics(
  excludeSemantics: true,
  label: 'Delete item',
  onTap: () {},
  child: IconButton(icon: Icon('delete'), onPressed: () {}),
)
''');
    final source = File('lib/rules/core/a07_replace_semantics_cleanly.faql')
        .readAsStringSync();
    final runner = FaqlRuleRunner(rules: [Faql4Compiler().compile(source)]);

    expect(runner.run(missingAction), hasLength(1));
    expect(runner.run(replacementAction), isEmpty);
  });
}
