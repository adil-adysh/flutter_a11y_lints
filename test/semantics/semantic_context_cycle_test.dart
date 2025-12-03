// Verify that recursive widget graphs degrade to `SemanticSummary.unknown`
// rather than causing infinite recursion.
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_a11y_lints/src/semantics/known_semantics.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_context.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _stubs = '''
typedef VoidCallback = void Function();

class Widget {}

class StatelessWidget extends Widget {}
class StatefulWidget extends Widget {}
class State<T> {}
class BuildContext {}
class Icon extends Widget { const Icon(String s); }
class IconButton extends Widget { const IconButton({required Widget icon, String? tooltip, VoidCallback? onPressed}); }
''';

void main() {
  test('cycle guard returns unknown for recursive widgets', () async {
    final tempDir = await Directory.systemTemp.createTemp('a11y_cycle_');
    try {
      final filePath = p.join(tempDir.path, 'widget.dart');
      final content = '''
$_stubs

class A {
  Widget build() => B();
}

class B {
  Widget build() => A();
}

Widget buildWidget(bool _) => A();
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
      // On recursion we expect an unknown summary whose widgetType equals
      // the requested class name (A).
      expect(summary!.widgetType, equals('A'));
      expect(summary.role, equals(SemanticRole.unknown));
    } finally {
      await tempDir.delete(recursive: true);
    }
  });
}
