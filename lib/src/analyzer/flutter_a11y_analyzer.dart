import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

import '../../rules/faql_rule_runner.dart';
import '../pipeline/semantic_ir_builder.dart';
import '../semantics/known_semantics.dart';
import '../utils/flutter_utils.dart';
import '../utils/method_utils.dart';

/// Reusable source-based Flutter accessibility analysis API.
class FlutterA11yAnalyzer {
  FlutterA11yAnalyzer({
    this.faqlRunner,
    this.verbose = false,
    this.excludes = const [],
  });

  final KnownSemanticsRepository _knownSemantics = KnownSemanticsRepository();
  final FaqlRuleRunner? faqlRunner;
  final bool verbose;
  final List<Glob> excludes;

  Future<List<A11yIssue>> analyze(String path) async {
    final targetFile = File(path);
    final targetDir = Directory(path);
    if (!targetFile.existsSync() && !targetDir.existsSync()) {
      throw ArgumentError.value(path, 'path', 'Path does not exist.');
    }
    final root = targetFile.existsSync()
        ? p.normalize(targetFile.parent.absolute.path)
        : p.normalize(targetDir.absolute.path);
    final collection = AnalysisContextCollection(
      includedPaths: [root],
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );
    final files = <String>[];
    if (targetFile.existsSync()) {
      files.add(p.normalize(targetFile.absolute.path));
    } else {
      await for (final entity in targetDir.list(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final absolute = p.normalize(entity.absolute.path);
        if (!excludes.any((glob) => glob.matches(p.relative(absolute, from: root)))) {
          files.add(absolute);
        }
      }
    }
    final issues = <A11yIssue>[];
    for (final file in files) {
      try {
        final result = await collection.contextFor(file).currentSession
            .getResolvedUnit(file);
        if (result is ResolvedUnitResult && fileUsesFlutter(result)) {
          issues.addAll(await _analyzeUnit(result));
        }
      } catch (error) {
        if (verbose) stderr.writeln('Failed to analyze $file: $error');
      }
    }
    return issues;
  }

  Future<List<A11yIssue>> _analyzeUnit(ResolvedUnitResult unit) async {
    final issues = <A11yIssue>[];
    final builder = SemanticIrBuilder(unit: unit, knownSemantics: _knownSemantics);
    for (final method in findBuildMethods(unit.unit)) {
      final expression = extractBuildBodyExpression(method);
      if (expression == null) continue;
      final tree = await builder.buildForExpressionAsync(expression);
      if (tree == null || faqlRunner == null) continue;
      for (final violation in faqlRunner!.run(tree)) {
        final location = unit.lineInfo.getLocation(violation.node.astNode.offset);
        issues.add(A11yIssue(
          file: unit.path,
          line: location.lineNumber,
          column: location.columnNumber,
          severity: violation.spec.severity,
          code: violation.spec.ruleId,
          message: violation.spec.message,
          correctionMessage: violation.spec.message,
        ));
      }
    }
    return issues;
  }
}

class A11yIssue {
  const A11yIssue({
    required this.file,
    required this.line,
    required this.column,
    required this.severity,
    required this.code,
    required this.message,
    required this.correctionMessage,
  });

  final String file;
  final int line;
  final int column;
  final String severity;
  final String code;
  final String message;
  final String correctionMessage;
}
