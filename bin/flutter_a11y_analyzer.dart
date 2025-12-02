#!/usr/bin/env dart

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_a11y_lints/src/pipeline/semantic_ir_builder.dart';
import 'package:flutter_a11y_lints/src/semantics/known_semantics.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:flutter_a11y_lints/src/utils/flutter_utils.dart';
import 'package:flutter_a11y_lints/src/utils/method_utils.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: flutter_a11y_analyzer <path_to_analyze>');
    print(
        '  Analyzes Flutter files for accessibility issues using semantic IR.');
    print('');
    print('Examples:');
    print('  flutter_a11y_analyzer lib/');
    print('  flutter_a11y_analyzer lib/main.dart');
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

      // Run A01 rule: Check for unlabeled interactive controls
      for (final node in tree.accessibilityFocusNodes) {
        if (!_isInteractive(node)) continue;
        if (!_isPrimaryControl(node)) continue;

        final hasLabel = node.effectiveLabel != null ||
            node.labelGuarantee != LabelGuarantee.none;

        if (hasLabel) continue;

        // Found a violation!
        final location = unit.lineInfo.getLocation(node.astNode.offset);
        issues.add(A11yIssue(
          file: unit.path,
          line: location.lineNumber,
          column: location.columnNumber,
          severity: 'warning',
          code: 'a01_unlabeled_interactive',
          message:
              'Interactive ${node.controlKind.name} must have an accessible label',
          correctionMessage: 'Add a tooltip, Text child, or Semantics label',
        ));
      }
    }

    return issues;
  }

  bool _isInteractive(SemanticNode node) =>
      (node.hasTap || node.hasIncrease || node.hasDecrease) && node.isEnabled;

  bool _isPrimaryControl(SemanticNode node) {
    const targetControls = {
      ControlKind.iconButton,
      ControlKind.elevatedButton,
      ControlKind.textButton,
      ControlKind.floatingActionButton,
    };
    return targetControls.contains(node.controlKind);
  }
}
