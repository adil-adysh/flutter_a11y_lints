#!/usr/bin/env dart

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_a11y_lints/src/pipeline/semantic_ir_builder.dart';
import 'package:flutter_a11y_lints/src/semantics/known_semantics.dart';
import 'package:flutter_a11y_lints/src/utils/flutter_utils.dart';
import 'package:flutter_a11y_lints/src/utils/method_utils.dart';
import 'package:flutter_a11y_lints/src/rules/a01_unlabeled_interactive.dart';
import 'package:flutter_a11y_lints/src/rules/a02_avoid_redundant_role_words.dart';
import 'package:flutter_a11y_lints/src/rules/a06_merge_multi_part_single_concept.dart';
import 'package:flutter_a11y_lints/src/rules/a07_replace_semantics_cleanly.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: a11y <path_to_analyze>');
    print(
        '  Analyzes Flutter files for accessibility issues using semantic IR.');
    print('');
    print('Examples:');
    print('  a11y lib/main.dart');
    print('  a11y lib/');
    exit(1);
  }

  final targetPath = args[0];
  final target = File(targetPath);
  final targetDir = Directory(targetPath);

  if (!target.existsSync() && !targetDir.existsSync()) {
    print('Error: Path "$targetPath" does not exist.');
    exit(1);
  }

  print('Flutter A11y Semantic Analyzer');
  print('==============================');
  print('Analyzing: $targetPath\n');

  final analyzer = FlutterA11yAnalyzer();
  final results = await analyzer.analyze(targetPath);

  if (results.isEmpty) {
    print('✓ No accessibility issues found!');
    exit(0);
  }

  print('Found ${results.length} accessibility issue(s):\n');

  for (final result in results) {
    print('${result.severity.toUpperCase()}: ${result.message}');
    print('  at ${result.file}:${result.line}:${result.column}');
    print('  ${result.correctionMessage}');
    print('');
  }

  exit(results.any((r) => r.severity == 'error') ? 1 : 0);
}

class A11yIssue {
  final String file;
  final int line;
  final int column;
  final String severity;
  final String code;
  final String message;
  final String correctionMessage;

  A11yIssue({
    required this.file,
    required this.line,
    required this.column,
    required this.severity,
    required this.code,
    required this.message,
    required this.correctionMessage,
  });

  @override
  String toString() => '$file:$line:$column - $message';
}

class FlutterA11yAnalyzer {
  final KnownSemanticsRepository _knownSemantics = KnownSemanticsRepository();

  Future<List<A11yIssue>> analyze(String path) async {
    final issues = <A11yIssue>[];
    final resourceProvider = PhysicalResourceProvider.INSTANCE;

    // Determine the root directory for analysis - must be absolute and normalized
    final targetFile = File(path);
    final targetDir = Directory(path);

    final analysisRoot = targetFile.existsSync()
        ? p.normalize(targetFile.parent.absolute.path)
        : p.normalize(targetDir.absolute.path);

    final collection = AnalysisContextCollection(
      includedPaths: [analysisRoot],
      resourceProvider: resourceProvider,
    );

    // Get all Dart files to analyze
    final files = <String>[];
    if (targetFile.existsSync()) {
      files.add(p.normalize(targetFile.absolute.path));
    } else {
      await for (final entity in targetDir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          files.add(p.normalize(entity.absolute.path));
        }
      }
    }

    for (final filePath in files) {
      final context = collection.contextFor(filePath);
      final unitResult = await context.currentSession.getResolvedUnit(filePath);

      if (unitResult is! ResolvedUnitResult) continue;

      // Skip non-Flutter files
      if (!fileUsesFlutter(unitResult)) continue;

      print('Analyzing: ${p.relative(filePath, from: analysisRoot)}');

      final fileIssues = _analyzeFile(unitResult);
      issues.addAll(fileIssues);
    }

    return issues;
  }

  List<A11yIssue> _analyzeFile(ResolvedUnitResult unit) {
    final issues = <A11yIssue>[];
    final irBuilder =
        SemanticIrBuilder(unit: unit, knownSemantics: _knownSemantics);

    // Find all build methods in the file
    final buildMethods = findBuildMethods(unit.unit);

    if (buildMethods.isEmpty) {
      // No build methods found
      return issues;
    }

    for (final method in buildMethods) {
      final expression = extractBuildBodyExpression(method);
      if (expression == null) continue;

      final tree = irBuilder.buildForExpression(expression);
      if (tree == null) continue;

      // Run all rules on the semantic tree
      final a01Violations = A01UnlabeledInteractive.checkTree(tree);
      final a02Violations = A02AvoidRedundantRoleWords.checkTree(tree);
      final a06Violations = A06MergeMultiPartSingleConcept.checkTree(tree);
      final a07Violations = A07ReplaceSemanticsCleanly.checkTree(tree);

      // Convert A01 violations to issues
      for (final violation in a01Violations) {
        final location = unit.lineInfo.getLocation(violation.node.astNode.offset);
        issues.add(A11yIssue(
          file: unit.path,
          line: location.lineNumber,
          column: location.columnNumber,
          severity: 'warning',
          code: A01UnlabeledInteractive.code,
          message: A01UnlabeledInteractive.message,
          correctionMessage: A01UnlabeledInteractive.correctionMessage,
        ));
      }

      // Convert A02 violations to issues
      for (final violation in a02Violations) {
        final location = unit.lineInfo.getLocation(violation.node.astNode.offset);
        issues.add(A11yIssue(
          file: unit.path,
          line: location.lineNumber,
          column: location.columnNumber,
          severity: 'warning',
          code: A02AvoidRedundantRoleWords.code,
          message: '${A02AvoidRedundantRoleWords.message}: ${violation.redundantWords.join(", ")}',
          correctionMessage: A02AvoidRedundantRoleWords.correctionMessage,
        ));
      }

      // Convert A06 violations to issues
      for (final violation in a06Violations) {
        final location = unit.lineInfo.getLocation(violation.node.astNode.offset);
        issues.add(A11yIssue(
          file: unit.path,
          line: location.lineNumber,
          column: location.columnNumber,
          severity: 'warning',
          code: A06MergeMultiPartSingleConcept.code,
          message: A06MergeMultiPartSingleConcept.message,
          correctionMessage: A06MergeMultiPartSingleConcept.correctionMessage,
        ));
      }

      // Convert A07 violations to issues
      for (final violation in a07Violations) {
        final location = unit.lineInfo.getLocation(violation.node.astNode.offset);
        issues.add(A11yIssue(
          file: unit.path,
          line: location.lineNumber,
          column: location.columnNumber,
          severity: 'warning',
          code: A07ReplaceSemanticsCleanly.code,
          message: A07ReplaceSemanticsCleanly.message,
          correctionMessage: A07ReplaceSemanticsCleanly.correctionMessage,
        ));
      }
    }

    return issues;
  }

}
