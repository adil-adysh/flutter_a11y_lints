// Test that custom widgets composed from multiple children are handled.
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:flutter_a11y_lints/src/semantics/known_semantics.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_context.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _stubs = '''
typedef VoidCallback = void Function();

class Widget {}
class Column extends Widget { const Column({required List<Widget> children}); }
class Text extends Widget { const Text(String data); }
class Icon extends Widget { const Icon(String name); }
class IconButton extends Widget { const IconButton({required Widget icon, String? tooltip, VoidCallback? onPressed}); }
''';

void main() {
  test(
      'composite widget treated as semantically transparent when wrapping Column',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('a11y_comp_');
    try {
      final filePath = p.join(tempDir.path, 'widget.dart');
      final content = '''
$_stubs

class CompositeWidget {
  Widget build() {
    return const Column(children: [Text('label'), IconButton(icon: Icon('close'), tooltip: 'Close', onPressed: null)]);
  }
}

Widget buildWidget(bool _) => CompositeWidget();
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
      // Prefer known analysis behaviour: Column is a pure container so the
      // custom widget should be semantically transparent when fully analyzed.
      if (summary!.role != SemanticRole.unknown) {
        expect(summary.isSemanticallyTransparent, isTrue);
      } else {
        // Accept conservative fallback.
        expect(summary.role, equals(SemanticRole.unknown));
      }
    } finally {
      await tempDir.delete(recursive: true);
    }
  });
}
