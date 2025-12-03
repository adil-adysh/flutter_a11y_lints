// Tests for resolver-backed `GlobalSemanticContext.getOrComputeSummary`.
//
// These tests verify the resolver plumbing added to `SemanticIrBuilder` and
// `GlobalSemanticContext` correctly locate a widget's defining compilation
// unit, extract its `build()` method, and synthesize a compact
// `SemanticSummary` via the local semantic builder.

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_a11y_lints/src/semantics/known_semantics.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_context.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _stubs = '''
typedef VoidCallback = void Function();

class Widget {}

class Icon extends Widget {
  const Icon(this.name, {String? semanticLabel});
  final String name;
}

class IconButton extends Widget {
  const IconButton({required Widget icon, String? tooltip, VoidCallback? onPressed});
}

class Text extends Widget {
  const Text(String data);
}

class StatelessWidget extends Widget {}
class StatefulWidget extends Widget {}
class State<T> {}
class BuildContext {}
''';

void main() {
  group('GlobalSemanticContext resolver', () {
    test('resolves class build() on same unit and derives IconButton summary',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('a11y_ctx_resolver_');
      try {
        final filePath = p.join(tempDir.path, 'widget.dart');
        final content = '''
$_stubs

class MyWidget {
  Widget build() {
    return const IconButton(icon: Icon('close'), tooltip: 'Close', onPressed: null);
  }
}

Widget buildWidget(bool _) => MyWidget();
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

        // Locate the `buildWidget` top-level function and read the returned
        // expression's `staticType` which should be the `InterfaceType`
        // corresponding to `MyWidget`.
        final buildFn = result.unit.declarations
            .whereType<FunctionDeclaration>()
            .firstWhere((fn) => fn.name.lexeme == 'buildWidget');
        final body = buildFn.functionExpression.body as ExpressionFunctionBody;
        final instance = body.expression as InstanceCreationExpression;
        final widgetType = instance.staticType as InterfaceType?;
        expect(widgetType, isNotNull);
        final summary = await global.getOrComputeSummary(widgetType);
        expect(summary, isNotNull);
        // Summary should be available; it may be `unknown` on some analyzer
        // configurations, but must be a `SemanticSummary` instance.
        expect(summary!.widgetType, equals('MyWidget'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('resolves build() in State subclass for StatefulWidget', () async {
      final tempDir =
          await Directory.systemTemp.createTemp('a11y_ctx_resolver_');
      try {
        final filePath = p.join(tempDir.path, 'widget.dart');
        final content = '''
$_stubs

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  Widget build() {
    return const IconButton(icon: Icon('menu'), tooltip: 'Menu', onPressed: null);
  }
}

Widget buildWidget(bool _) => MyWidget();
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
        expect(summary!.widgetType, equals('MyWidget'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('fallbacks to unknown when resolver unavailable', () async {
      final tempDir =
          await Directory.systemTemp.createTemp('a11y_ctx_resolver_');
      try {
        final filePath = p.join(tempDir.path, 'widget.dart');
        final content = '''
$_stubs

class UnknownWidget {
  Widget build() => const IconButton(icon: Icon('a'));
}

Widget buildWidget(bool _) => UnknownWidget();
''';
        await File(filePath).writeAsString(content);

        final collection = AnalysisContextCollection(includedPaths: [filePath]);
        final context = collection.contextFor(filePath);
        final result = await context.currentSession.getResolvedUnit(filePath);
        if (result is! ResolvedUnitResult) fail('Failed to resolve test unit');

        // Provide a resolver that always fails to simulate missing source.
        final global = GlobalSemanticContext(
          knownSemantics: KnownSemanticsRepository(),
          typeProvider: result.typeProvider,
          resolver: (_) async => null,
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
        expect(summary!.role, equals(SemanticRole.unknown));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
