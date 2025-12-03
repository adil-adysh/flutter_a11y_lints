// Verify that WidgetTreeBuilder can fold conditional expressions that
// reference a top-level `const` boolean when GlobalSemanticContext.evalBool
// can read resolved constant values.

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_a11y_lints/src/widget_tree/widget_tree_builder.dart';
import 'package:flutter_a11y_lints/src/widget_tree/widget_node.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

const _stubs = '''
class Widget {}
class Icon extends Widget { const Icon(String name); }
''';

void main() {
  test('conditional with top-level const folds to single branch', () async {
    final tempDir = await Directory.systemTemp.createTemp('a11y_const_');
    try {
      final filePath = p.join(tempDir.path, 'widget.dart');
      final content = '$_stubs\n\n' +
          r"""
const showFirst = true;

Widget buildWidget(bool _) {
  return showFirst ? Icon('a') : Icon('b');
}
""";
      await File(filePath).writeAsString(content);

      final collection = AnalysisContextCollection(includedPaths: [filePath]);
      final context = collection.contextFor(filePath);
      final result = await context.currentSession.getResolvedUnit(filePath);
      if (result is! ResolvedUnitResult) fail('Failed to resolve test unit');

      // Find the build function and its returned conditional expression.
      final buildFn = result.unit.declarations
          .whereType<FunctionDeclaration>()
          .firstWhere((fn) => fn.name.lexeme == 'buildWidget');
      final body = buildFn.functionExpression.body as BlockFunctionBody;
      // Find the return statement
      final ret = body.block.statements
          .whereType<ReturnStatement>()
          .firstWhere((r) => r.expression is ConditionalExpression);
      final cond = ret.expression as ConditionalExpression;

      // Use a WidgetTreeBuilder with a constEval that uses resolved constants.
      final treeBuilder = WidgetTreeBuilder(result, constEval: (expr) {
        // Attempt to resolve simple identifiers by scanning top-level
        // variable declarations in the same unit.
        try {
          final e = expr?.unParenthesized;
          if (e is SimpleIdentifier) {
            final name = e.name;
            for (final decl in result.unit.declarations) {
              if (decl is TopLevelVariableDeclaration) {
                for (final v in decl.variables.variables) {
                  if (v.name.lexeme == name) {
                    final init = v.initializer;
                    if (init is BooleanLiteral) return init.value;
                  }
                }
              }
            }
          }
        } catch (_) {}
        return null;
      });

      final node = treeBuilder.fromExpression(cond);
      expect(node, isNotNull);
      // If folding worked, the returned node should be the chosen branch (an InstanceCreationExpression -> widgetType 'Icon')
      expect(node!.nodeType, isNot(WidgetNodeType.conditionalBranch));
      expect(node.widgetType, equals('Icon'));
    } finally {
      await tempDir.delete(recursive: true);
    }
  });
}
