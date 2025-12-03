// Test how non-literal/interpolated tooltip labels are handled by the
// semantic summary generation (should not be considered a static label).
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:flutter_a11y_lints/src/semantics/known_semantics.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_context.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _stubs = '''
typedef VoidCallback = void Function();

class Widget {}
class Icon extends Widget { const Icon(String name); }
class IconButton extends Widget { const IconButton({required Widget icon, String? tooltip, VoidCallback? onPressed}); }
''';

void main() {
  test('non-literal tooltip does not produce static label', () async {
    final tempDir = await Directory.systemTemp.createTemp('a11y_dyn_');
    try {
      final filePath = p.join(tempDir.path, 'widget.dart');
      final content = '$_stubs\n\n' +
          r'''
class DynLabelWidget {
  final String suffix = 'X';
  Widget build() {
    return IconButton(icon: Icon('close'), tooltip: 'Close $suffix', onPressed: null);
  }
}

Widget buildWidget(bool _) => DynLabelWidget();
''';
      await File(filePath).writeAsString(content);

      final collection = AnalysisContextCollection(includedPaths: [filePath]);
      final context = collection.contextFor(filePath);
      final result = await context.currentSession.getResolvedUnit(filePath);
      if (result is! ResolvedUnitResult) fail('Failed to resolve test unit');

      final global = GlobalSemanticContext(
        knownSemantics: KnownSemanticsRepository(),
        typeProvider: result.typeProvider,
        resolver: (t) async {
          try {
            final path = (t?.element as dynamic)?.source?.fullName as String?;
            if (path == null) return null;
            final r = await result.session.getResolvedUnit(path);
            return r as ResolvedUnitResult;
          } catch (_) {
            return null;
          }
        },
      );

      final buildFn = result.unit.declarations
          .whereType<FunctionDeclaration>()
          .firstWhere((fn) => fn.name.lexeme == 'buildWidget');
      final body = buildFn.functionExpression.body as ExpressionFunctionBody;
      final instance = body.expression as InstanceCreationExpression;
      final widgetType = instance.staticType as InterfaceType?;
      expect(widgetType, isNotNull);

      final summary = await global.getOrComputeSummary(widgetType);
      expect(summary, isNotNull);
      if (summary!.role != SemanticRole.unknown) {
        // When fully analyzed, the computed labelGuarantee should not be
        // `hasStaticLabel` because the tooltip contains interpolation.
        expect(summary.labelGuarantee, isNot(LabelGuarantee.hasStaticLabel));
      } else {
        expect(summary.role, equals(SemanticRole.unknown));
      }
    } finally {
      await tempDir.delete(recursive: true);
    }
  });
}
