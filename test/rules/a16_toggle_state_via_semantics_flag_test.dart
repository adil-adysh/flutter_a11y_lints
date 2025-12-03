import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_a11y_lints/src/pipeline/semantic_ir_builder.dart';
import 'package:flutter_a11y_lints/src/semantics/known_semantics.dart';
import 'package:flutter_a11y_lints/src/rules/a16_toggle_state_via_semantics_flag.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _stubs = '''
typedef VoidCallback = void Function();
class Widget {}
class Semantics extends Widget { const Semantics({String? label, bool? toggled, bool? checked, required Widget child}); }
class Checkbox extends Widget { const Checkbox({required bool value}); }
class Switch extends Widget { const Switch({required bool value}); }
''';

void main() {
  test('warns when semantics label contains state words for checkbox',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('a11y_a16_');
    try {
      final filePath = p.join(tempDir.path, 'widget.dart');
      final content = '''
$_stubs

Widget buildWidget(bool _) {
  return Semantics(label: 'Sync is on', child: Checkbox(value: true));
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

      final violations = A16ToggleStateViaSemanticsFlag.checkTree(tree);
      expect(violations, isNotEmpty);
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test('does not warn when semantics uses toggled flag', () async {
    final tempDir = await Directory.systemTemp.createTemp('a11y_a16_ok_');
    try {
      final filePath = p.join(tempDir.path, 'widget.dart');
      final content = '''
$_stubs

Widget buildWidget(bool _) {
  return Semantics(label: 'Wifi', toggled: true, child: Switch(value: true));
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

      final violations = A16ToggleStateViaSemanticsFlag.checkTree(tree);
      expect(violations, isEmpty);
    } finally {
      await tempDir.delete(recursive: true);
    }
  });
}
