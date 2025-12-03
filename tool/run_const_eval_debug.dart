import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

const _stubs = '''
class Widget {}
class Icon extends Widget { const Icon(String name); }
''';

Future<void> main() async {
  final tempDir = await Directory.systemTemp.createTemp('a11y_const_dbg_');
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
    if (result is! ResolvedUnitResult) {
      print('Failed to resolve');
      return;
    }

    final buildFn = result.unit.declarations
        .whereType<FunctionDeclaration>()
        .firstWhere((fn) => fn.name.lexeme == 'buildWidget');
    final body = buildFn.functionExpression.body as BlockFunctionBody;
    final ret = body.block.statements
        .whereType<ReturnStatement>()
        .firstWhere((r) => r.expression is ConditionalExpression);
    final cond = ret.expression as ConditionalExpression;

    print('Found conditional expression: ' + cond.toSource());

    // Try to evaluate condition via static element constant
    final condExpr = cond.condition;
    print('Condition source: ' + condExpr.toSource());
    try {
      final el = (condExpr as dynamic).staticElement;
      print('staticElement: ' + (el?.toString() ?? 'null'));
      final constVal = (el as dynamic).computeConstantValue?.call();
      print('constVal: ' + (constVal?.toString() ?? 'null'));
      final asBool = constVal?.toBoolValue?.call();
      print('asBool: ' + (asBool?.toString() ?? 'null'));
    } catch (e, st) {
      print('error reading constant: $e');
      print(st);
    }
    print('\nTop-level declarations:');
    for (final d in result.unit.declarations) {
      print('Decl: ' + d.runtimeType.toString() + ' -> ' + d.toSource());
      if (d is TopLevelVariableDeclaration) {
        for (final v in d.variables.variables) {
          print(' var ${v.name.lexeme} init=${v.initializer?.toSource()}');
        }
      }
    }
  } finally {
    await tempDir.delete(recursive: true);
  }
}
