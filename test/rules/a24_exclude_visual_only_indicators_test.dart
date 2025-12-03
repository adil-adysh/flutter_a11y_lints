import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_a11y_lints/src/pipeline/semantic_ir_builder.dart';
import 'package:flutter_a11y_lints/src/semantics/known_semantics.dart';
import 'package:flutter_a11y_lints/src/rules/a24_exclude_visual_only_indicators.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _stubs = '''
typedef VoidCallback = void Function();
class Widget {}
class Icon extends Widget { const Icon(this.icon); }
class Icons { static const drag_handle = 1; static const drag_indicator = 2; }
''';

void main() {
  test('flags drag_handle icon not excluded', () async {
    final tempDir = await Directory.systemTemp.createTemp('a11y_a24_');
    try {
      final filePath = p.join(tempDir.path, 'widget.dart');
      final content = '''
$_stubs

Widget buildWidget(bool _) {
  return Icon(Icons.drag_handle);
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

      final violations = A24ExcludeVisualOnlyIndicators.checkTree(tree);
      expect(violations, isNotEmpty);
    } finally {
      await tempDir.delete(recursive: true);
    }
  });
}
