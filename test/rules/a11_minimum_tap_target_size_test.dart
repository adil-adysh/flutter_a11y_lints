import 'package:flutter_a11y_lints/src/rules/a11_minimum_tap_target_size.dart';
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
class SizedBox extends Widget { const SizedBox({double? width, double? height, Widget? child}); }
class Icon extends Widget { const Icon(String name); }
class IconButton extends Widget { const IconButton({required Widget icon, VoidCallback? onPressed}); }
''';

void main() {
  test('flags literal sized box smaller than 44', () async {
    final tempDir = await Directory.systemTemp.createTemp('a11y_a11_');
    try {
      final filePath = p.join(tempDir.path, 'widget.dart');
      final content = '''
$_stubs

Widget buildWidget(bool _) {
  return SizedBox(width: 32, height: 32, child: IconButton(icon: Icon('x'), onPressed: () {}));
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

      final violations = A11MinimumTapTargetSize.checkTree(tree);
      expect(violations, isNotEmpty);
    } finally {
      await tempDir.delete(recursive: true);
    }
  });
}
