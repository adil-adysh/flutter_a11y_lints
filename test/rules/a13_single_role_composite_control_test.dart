import 'package:flutter_a11y_lints/src/rules/a13_single_role_composite_control.dart';
import 'package:flutter_a11y_lints/src/pipeline/semantic_ir_builder.dart';
import 'package:flutter_a11y_lints/src/semantics/known_semantics.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _stubs = '''
typedef VoidCallback = void Function();

class Widget {}
class Container extends Widget { const Container({Widget? child}); }
class Row extends Widget { const Row({required List<Widget> children}); }
class Icon extends Widget { const Icon(String name); }
class IconButton extends Widget { const IconButton({required Widget icon, VoidCallback? onPressed}); }
class Semantics extends Widget { const Semantics({bool? container, Widget? child}); }
''';

void main() {
  test('flags semantics container with multiple focusable children', () async {
    final tempDir = await Directory.systemTemp.createTemp('a11y_a13_');
    try {
      final filePath = p.join(tempDir.path, 'widget.dart');
      final content = '''
$_stubs

Widget buildWidget(bool _) {
  return Semantics(container: true, child: Row(children: [IconButton(icon: Icon('a'), onPressed: () {}), IconButton(icon: Icon('b'), onPressed: () {})]));
}
''';
      await File(filePath).writeAsString(content);

      final collection = AnalysisContextCollection(includedPaths: [filePath]);
      final context = collection.contextFor(filePath);
      final result = await context.currentSession.getResolvedUnit(filePath);
      if (result is! ResolvedUnitResult) fail('resolve failed');

      final builder = SemanticIrBuilder(
          unit: result, knownSemantics: KnownSemanticsRepository());
      final buildFn = result.unit.declarations
          .whereType<FunctionDeclaration>()
          .firstWhere((f) => f.name.lexeme == 'buildWidget');
      final body = buildFn.functionExpression.body as BlockFunctionBody;
      final ret = body.block.statements.whereType<ReturnStatement>().first;
      final tree = builder.buildForExpression(ret.expression);
      if (tree == null) fail('tree null');

      final violations = A13SingleRoleCompositeControl.checkTree(tree);
      expect(violations, isNotEmpty);
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test('does not flag pure layout containers', () async {
    final tempDir = await Directory.systemTemp.createTemp('a11y_a13_layout_');
    try {
      final filePath = p.join(tempDir.path, 'widget.dart');
      final content = '''
$_stubs

Widget buildWidget(bool _) {
  return Row(children: [IconButton(icon: Icon('a'), onPressed: () {}), IconButton(icon: Icon('b'), onPressed: () {})]);
}
''';
      await File(filePath).writeAsString(content);

      final collection = AnalysisContextCollection(includedPaths: [filePath]);
      final context = collection.contextFor(filePath);
      final result = await context.currentSession.getResolvedUnit(filePath);
      if (result is! ResolvedUnitResult) fail('resolve failed');

      final builder = SemanticIrBuilder(
          unit: result, knownSemantics: KnownSemanticsRepository());
      final buildFn = result.unit.declarations
          .whereType<FunctionDeclaration>()
          .firstWhere((f) => f.name.lexeme == 'buildWidget');
      final body = buildFn.functionExpression.body as BlockFunctionBody;
      final ret = body.block.statements.whereType<ReturnStatement>().first;
      final tree = builder.buildForExpression(ret.expression);
      if (tree == null) fail('tree null');

      final violations = A13SingleRoleCompositeControl.checkTree(tree);
      expect(violations, isEmpty);
    } finally {
      await tempDir.delete(recursive: true);
    }
  });
}
