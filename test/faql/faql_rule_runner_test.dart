import 'package:flutter_a11y_lints/rules/faql_rule_runner.dart';
import 'package:flutter_a11y_lints/src/query/faql4.dart';
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
where control.isDefinitelyEnabled() and control.isDefinitelyUnlabeled()
select control, "Interactive control must have an accessible label."
''';
    final tree = buildManualTree(makeSemanticNode());
    final runner = FaqlRuleRunner(rules: [Faql4Compiler().compile(source)]);

    expect(runner.run(tree), hasLength(1));
  });

  test('merge rule excludes disabled interactive descendants', () {
    final source = File('lib/rules/core/merge_multiple_actions.faql')
        .readAsStringSync();
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
    final source = File('lib/rules/core/merge_multiple_actions.faql')
        .readAsStringSync();

    expect(
      FaqlRuleRunner(rules: [Faql4Compiler().compile(source)]).run(tree),
      hasLength(1),
    );
  });

  test('reports an effectively unnamed ListTile leading image', () async {
    const source = '''
@id example/a04-leading
@rule-id a04
@severity warning
@mode conservative
from ImageNode image
where image.isNetworkOrFileImage() and image.isDefinitelyNotExcludedFromSemantics() and image.isDefinitelyEffectivelyUnlabeled() and exists(ListTileNode tile | image = tile.getSlot("leading"))
select image, "Image needs a label."
''';
    final tree = await buildTestSemanticTree(
      "ListTile(leading: Image.network('https://example.test/photo.png'))",
    );
    final runner = FaqlRuleRunner(rules: [Faql4Compiler().compile(source)]);

    expect(runner.run(tree), hasLength(1));
  });

  test('reports a ListTile directly wrapped by MergeSemantics', () async {
    const source = '''
@id example/a22
@rule-id a22
@severity warning
@mode conservative
from MergeSemanticsNode merge
where exists(ListTileNode tile | tile = merge.getAChild())
select merge, "ListTile already merges semantics."
''';
    final tree = await buildTestSemanticTree(
      "MergeSemantics(child: ListTile(title: Text('Account')))",
    );

    expect(
      FaqlRuleRunner(rules: [Faql4Compiler().compile(source)]).run(tree),
      hasLength(1),
    );
  });
}
