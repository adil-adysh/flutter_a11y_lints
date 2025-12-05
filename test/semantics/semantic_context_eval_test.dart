import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_a11y_lints/src/semantics/known_semantics.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_context.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('evalString/evalBool/evalInt in resolved unit', () async {
    final tempDir = await Directory.systemTemp.createTemp('a11y_eval_');
    try {
      final filePath = p.join(tempDir.path, 'eval.dart');
      final content = '''
const s1 = 'hello';
const s2 = 'world';
const adj = 'a' 'b';
const ref = s1;
const i1 = 42;

bool bfn1() => true && false;
bool bfn2() => !true;
int ifn() => 7;
''';
      await File(filePath).writeAsString(content);

      final collection = AnalysisContextCollection(includedPaths: [filePath]);
      final context = collection.contextFor(filePath);
      final result = await context.currentSession.getResolvedUnit(filePath);
      if (result is! ResolvedUnitResult) fail('Failed to resolve unit');

      final global = GlobalSemanticContext(
        knownSemantics: KnownSemanticsRepository(),
        typeProvider: result.typeProvider,
        resolver: null,
      );

      // Find top-level variable initializers
      var s1Expr, adjExpr, refExpr, i1Expr;
      for (final d in result.unit.declarations) {
        if (d is TopLevelVariableDeclaration) {
          for (final v in d.variables.variables) {
            if (v.name.lexeme == 's1') s1Expr = v.initializer;
            if (v.name.lexeme == 'adj') adjExpr = v.initializer;
            if (v.name.lexeme == 'ref') refExpr = v.initializer;
            if (v.name.lexeme == 'i1') i1Expr = v.initializer;
          }
        }
      }

      expect(global.evalStringInUnit(s1Expr as Expression?, result),
          equals('hello'));
      expect(global.evalStringInUnit(adjExpr as Expression?, result),
          equals('ab'));
      expect(global.evalStringInUnit(refExpr as Expression?, result),
          equals('hello'));
      expect(global.evalIntInUnit(i1Expr as Expression?, result), equals(42));

      // Find functions and their returned expressions
      Expression? bfn1Expr;
      Expression? bfn2Expr;
      Expression? ifnExpr;
      for (final d in result.unit.declarations) {
        if (d is FunctionDeclaration) {
          if (d.name.lexeme == 'bfn1') {
            final body = d.functionExpression.body as ExpressionFunctionBody;
            bfn1Expr = body.expression;
          }
          if (d.name.lexeme == 'bfn2') {
            final body = d.functionExpression.body as ExpressionFunctionBody;
            bfn2Expr = body.expression;
          }
          if (d.name.lexeme == 'ifn') {
            final body = d.functionExpression.body as ExpressionFunctionBody;
            ifnExpr = body.expression;
          }
        }
      }

      expect(global.evalBoolInUnit(bfn1Expr, result), isFalse);
      expect(global.evalBoolInUnit(bfn2Expr, result), isFalse);
      expect(global.evalIntInUnit(ifnExpr, result), equals(7));
    } finally {
      await tempDir.delete(recursive: true);
    }
  });
}
