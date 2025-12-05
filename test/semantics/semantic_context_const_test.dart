import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_context.dart';
import 'package:flutter_a11y_lints/src/semantics/known_semantics.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('evalStringInUnit resolves top-level and static consts', () async {
    final tempDir = await Directory.systemTemp.createTemp('a11y_eval_');
    try {
      final filePath = p.join(tempDir.path, 'consts.dart');
      final content = r'''
const String TOP = 'top-value';
class C {
  static const String F = 'static-value';
}

const bool B_TRUE = true;
const bool B_FALSE = false;

const int N = 123;

String retTop() => TOP;
String retStatic() => C.F;
bool retBoolAnd() => B_TRUE && B_FALSE;
int retInt() => N;
''';
      await File(filePath).writeAsString(content);

      final collection = AnalysisContextCollection(includedPaths: [filePath]);
      final context = collection.contextFor(filePath);
      final result = await context.currentSession.getResolvedUnit(filePath);
      if (result is! ResolvedUnitResult) fail('Failed to resolve unit');

      final global = GlobalSemanticContext(
        knownSemantics: KnownSemanticsRepository(),
        typeProvider: result.typeProvider,
      );

      // locate functions and evaluate their return expressions
      final funcs = result.unit.declarations.whereType<FunctionDeclaration>();
      AstNode? exprOf(String name) {
        final fn = funcs.firstWhere((f) => f.name.lexeme == name);
        final body = fn.functionExpression.body;
        if (body is ExpressionFunctionBody) return body.expression;
        if (body is BlockFunctionBody) {
          final ret = body.block.statements.whereType<ReturnStatement>().first;
          return ret.expression;
        }
        return null;
      }

      final eTop = exprOf('retTop') as Expression?;
      final eStatic = exprOf('retStatic') as Expression?;
      final eBool = exprOf('retBoolAnd') as Expression?;
      final eInt = exprOf('retInt') as Expression?;

      expect(global.evalStringInUnit(eTop, result), equals('top-value'));
      expect(global.evalStringInUnit(eStatic, result), equals('static-value'));
      expect(global.evalBoolInUnit(eBool, result), equals(false));
      expect(global.evalIntInUnit(eInt, result), equals(123));
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test('evalStringInUnit handles adjacent and interpolated strings', () async {
    final tempDir = await Directory.systemTemp.createTemp('a11y_eval_');
    try {
      final filePath = p.join(tempDir.path, 'strings.dart');
      final content = r'''
const String A = 'a';
const String B = 'b';

String adj() => 'hello' ' ' 'world';
String interp() => 'fixed ${A}${B}';
''';
      await File(filePath).writeAsString(content);

      final collection = AnalysisContextCollection(includedPaths: [filePath]);
      final context = collection.contextFor(filePath);
      final result = await context.currentSession.getResolvedUnit(filePath);
      if (result is! ResolvedUnitResult) fail('Failed to resolve unit');

      final global = GlobalSemanticContext(
        knownSemantics: KnownSemanticsRepository(),
        typeProvider: result.typeProvider,
      );

      final funcs = result.unit.declarations.whereType<FunctionDeclaration>();
      Expression exprOf(String name) {
        final fn = funcs.firstWhere((f) => f.name.lexeme == name);
        final body = fn.functionExpression.body as ExpressionFunctionBody;
        return body.expression;
      }

      final eAdj = exprOf('adj');
      final eInterp = exprOf('interp');

      expect(global.evalStringInUnit(eAdj, result), equals('hello world'));
      // interpolation contains dynamic parts -> should return null
      expect(global.evalStringInUnit(eInterp, result), isNull);
    } finally {
      await tempDir.delete(recursive: true);
    }
  });
}
