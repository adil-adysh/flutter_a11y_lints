import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_a11y_lints/src/pipeline/semantic_ir_builder.dart';
import 'package:flutter_a11y_lints/src/facts/fact_store.dart';
import 'package:flutter_a11y_lints/src/facts/semantic_fact_extractor.dart';
import 'package:flutter_a11y_lints/src/semantics/known_semantics.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_tree.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('expands a resolved custom widget into its semantic IR', () async {
    final tree = await _buildTree('''
class DeleteControl extends Widget {
  Widget build() => Semantics(
    excludeSemantics: true,
    label: 'Delete item',
    child: IconButton(icon: Icon('delete'), onPressed: () {}),
  );
}

Widget buildWidget(bool purchasePending) => DeleteControl();
''');

    expect(tree.root.widgetType, 'Semantics');
    expect(
      tree.root.descendantReplacement,
      DescendantReplacementState.replaced,
    );
    expect(tree.root.children.single.widgetType, 'IconButton');
    expect(tree.root.children.single.focusOrderIndex, isNull);
  });

  test('marks facts from expanded custom-widget source as derived', () async {
    final tree = await _buildTree('''
class SaveControl extends Widget {
  Widget build() => IconButton(
    icon: Icon('save'),
    onPressed: () {},
  );
}

Widget buildWidget(bool purchasePending) => SaveControl();
''');

    final facts = SemanticFactExtractor().extract(tree).store;
    final control = tree.root;
    expect(
      facts.conservative
          .factsFor(control.id!)
          .firstWhere((fact) => fact.name == 'controlKind')
          .provenance,
      FactProvenance.derived,
    );
    expect(
      facts.conservative
          .factsFor(control.id!)
          .every((fact) => fact.provenance != FactProvenance.exact),
      isTrue,
    );
  });

  test('expands a resolved StatefulWidget through its State build method',
      () async {
    final tree = await _buildTree('''
class StatefulSaveControl extends StatefulWidget {}

class _StatefulSaveControlState extends State<StatefulSaveControl> {
  Widget build() => IconButton(
    icon: Icon('save'),
    onPressed: () {},
  );
}

Widget buildWidget(bool purchasePending) => StatefulSaveControl();
''');

    expect(tree.root.widgetType, 'IconButton');
    expect(tree.root.hasTap, isTrue);
  });

  test('preserves named slots from a resolved custom-widget implementation',
      () async {
    final tree = await _buildTree('''
class ProfileTile extends Widget {
  Widget build() => ListTile(
    leading: IconButton(icon: Icon('profile'), onPressed: () {}),
    title: Text('Profile'),
  );
}

Widget buildWidget(bool purchasePending) => ProfileTile();
''');

    final facts = SemanticFactExtractor().extract(tree).store;
    final leading = facts.slotOf(tree.root.id!, 'leading');
    expect(tree.root.widgetType, 'ListTile');
    expect(leading?.widgetType, 'IconButton');
  });

  test('preserves incompatible conditional branches from custom-widget source',
      () async {
    final tree = await _buildTree('''
class ConditionalActions extends Widget {
  ConditionalActions(this.primary);
  final bool primary;

  Widget build() => Column(children: [
    if (primary)
      IconButton(icon: Icon('primary'), onPressed: () {})
    else
      IconButton(icon: Icon('secondary'), onPressed: () {}),
  ]);
}

Widget buildWidget(bool purchasePending) => ConditionalActions(purchasePending);
''');

    final actions = tree.physicalNodes
        .where((node) => node.widgetType == 'IconButton')
        .toList();
    final facts = SemanticFactExtractor().extract(tree).store;
    expect(actions, hasLength(2));
    expect(actions.every((node) => node.branchPath.constraints.length == 1),
        isTrue);
    expect(facts.compatible(actions[0].id!, actions[1].id!), isFalse);
  });

  test('appends custom-widget branch paths to caller branch paths', () async {
    final tree = await _buildTree('''
class ConditionalActions extends Widget {
  ConditionalActions(this.primary);
  final bool primary;

  Widget build() => Column(children: [
    if (primary)
      IconButton(icon: Icon('primary'), onPressed: () {})
    else
      IconButton(icon: Icon('secondary'), onPressed: () {}),
  ]);
}

Widget buildWidget(bool purchasePending) => purchasePending
    ? ConditionalActions(true)
    : ConditionalActions(false);
''');

    final actions = tree.physicalNodes
        .where((node) => node.widgetType == 'IconButton')
        .toList();
    final facts = SemanticFactExtractor().extract(tree).store;
    expect(actions, hasLength(4));
    expect(actions.every((node) => node.branchPath.constraints.length == 2),
        isTrue);
    final outerZero = actions
        .where((node) => node.branchPath.constraints.first.value == 0)
        .toList();
    final outerOne = actions
        .where((node) => node.branchPath.constraints.first.value == 1)
        .toList();
    expect(outerZero, hasLength(2));
    expect(outerOne, hasLength(2));
    expect(facts.compatible(outerZero.first.id!, outerOne.first.id!), isFalse);
  });

  test('keeps a custom widget with multiple build returns unknown', () async {
    final tree = await _buildTree('''
class AmbiguousControl extends Widget {
  AmbiguousControl(this.primary);
  final bool primary;

  Widget build() {
    if (primary) return IconButton(icon: Icon('primary'), onPressed: () {});
    return Text('secondary');
  }
}

Widget buildWidget(bool purchasePending) => AmbiguousControl(purchasePending);
''');

    expect(tree.root.widgetType, 'AmbiguousControl');
    expect(tree.root.isHeuristic, isTrue);
    expect(tree.root.mergeState, SemanticMergeState.unknown);
    expect(tree.root.exposureState, SemanticExposureState.unknown);
  });

  test('keeps a custom widget with an unresolved structural child unknown',
      () async {
    final tree = await _buildTree('''
class Wrapper extends Widget {
  Wrapper(this.child);
  final Widget child;

  Widget build() => Semantics(label: 'wrapper', child: child);
}

Widget buildWidget(bool purchasePending) => Wrapper(Icon('child'));
''');

    expect(tree.root.widgetType, 'Wrapper');
    expect(tree.root.isHeuristic, isTrue);
    expect(tree.root.mergeState, SemanticMergeState.unknown);
  });

  test('keeps a custom widget with unresolved children collection unknown',
      () async {
    final tree = await _buildTree('''
class DynamicChildren extends Widget {
  DynamicChildren(this.children);
  final List<Widget> children;

  Widget build() => Column(children: children);
}

Widget buildWidget(bool purchasePending) => DynamicChildren([]);
''');

    expect(tree.root.widgetType, 'DynamicChildren');
    expect(tree.root.isHeuristic, isTrue);
  });

  test('stops recursive custom-widget expansion at an unknown boundary',
      () async {
    final tree = await _buildTree('''
class FirstControl extends Widget {
  Widget build() => SecondControl();
}

class SecondControl extends Widget {
  Widget build() => FirstControl();
}

Widget buildWidget(bool purchasePending) => FirstControl();
''');

    expect(tree.root.widgetType, 'FirstControl');
    expect(tree.root.isHeuristic, isTrue);
  });
}

Future<SemanticTree> _buildTree(String source) async {
  final directory = await Directory.systemTemp.createTemp('a11y_custom_ir_');
  try {
    final path = p.join(directory.path, 'widget.dart');
    await File(path).writeAsString('''
$_stubs
$source
''');
    final collection = AnalysisContextCollection(includedPaths: [path]);
    final context = collection.contextFor(path);
    final result = await context.currentSession.getResolvedUnit(path);
    if (result is! ResolvedUnitResult) fail('Unable to resolve fixture.');
    final function = result.unit.declarations
        .whereType<FunctionDeclaration>()
        .firstWhere((declaration) => declaration.name.lexeme == 'buildWidget');
    final body = function.functionExpression.body as ExpressionFunctionBody;
    final tree = await SemanticIrBuilder(
      unit: result,
      knownSemantics: KnownSemanticsRepository(),
    ).buildForExpressionAsync(body.expression);
    if (tree == null) fail('Unable to build semantic tree.');
    return tree;
  } finally {
    await directory.delete(recursive: true);
  }
}

const _stubs = '''
typedef VoidCallback = void Function();

class Widget {}

class StatefulWidget extends Widget {}

class State<T extends StatefulWidget> {}

class Icon extends Widget {
  const Icon(String name);
}

class IconButton extends Widget {
  const IconButton({required Widget icon, VoidCallback? onPressed});
}

class Text extends Widget {
  const Text(String data);
}

class ListTile extends Widget {
  const ListTile({Widget? leading, Widget? title});
}

class Column extends Widget {
  const Column({required List<Widget> children});
}

class Semantics extends Widget {
  const Semantics({
    required Widget child,
    bool excludeSemantics = false,
    String? label,
  });
}
''';
