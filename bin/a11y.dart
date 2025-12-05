#!/usr/bin/env dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:glob/glob.dart'; // REQUIRED: Add to pubspec.yaml

// Generated file containing built-in rules map
import 'package:flutter_a11y_lints/src/pipeline/semantic_ir_builder.dart';
import 'package:flutter_a11y_lints/src/semantics/known_semantics.dart';
import 'package:flutter_a11y_lints/src/utils/flutter_utils.dart';
import 'package:flutter_a11y_lints/src/utils/method_utils.dart';
import 'package:flutter_a11y_lints/src/rules/a01_unlabeled_interactive.dart';
import 'package:flutter_a11y_lints/src/rules/faql_rule_catalog.dart';
import 'package:flutter_a11y_lints/src/rules/faql_rule_runner.dart';
import 'package:flutter_a11y_lints/src/faql/parser.dart';
import 'package:flutter_a11y_lints/src/faql/validator.dart';
import 'package:flutter_a11y_lints/src/bridge/semantic_faql_adapter.dart'
    show faqlAllowedIdentifiers;
import 'package:flutter_a11y_lints/src/version.g.dart' show kPackageVersion;

// Use generated package version that's derived from pubspec.yaml.
const String _version = kPackageVersion;

void main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Print this usage information.')
    ..addFlag('version', negatable: false, help: 'Print the package version.')
    ..addFlag('verbose',
        abbr: 'v', negatable: false, help: 'Show additional logging.')
    ..addFlag('fail-on-warnings',
        defaultsTo: false, help: 'Exit with code 1 if any issues are found.')

    // Analysis Scope
    ..addOption('exclude',
        help:
            'Comma-separated glob patterns to skip (relative to analysis root).',
        defaultsTo: '**/*.g.dart,**/*.freezed.dart')

    // Rule Selection
    ..addFlag('faql-only',
        defaultsTo: false,
        help: 'Run only FAQL rules (skip legacy Dart rules).')
    ..addFlag('dart-only',
        defaultsTo: false, help: 'Run only legacy Dart rules (skip FAQL).')
    ..addOption('rules-dir', help: 'Directory containing custom .faql rules.')

    // Reporting
    ..addOption('reporter',
        allowed: ['console', 'json', 'machine'],
        defaultsTo: 'console',
        help: 'The format of the output.')

    // Utilities
    ..addFlag('list-rules',
        negatable: false, help: 'List all active rules and exit.')
    ..addFlag('init',
        negatable: false, help: 'Generate a starter rules directory.')
    ..addOption('show-rule', help: 'Print the source code of a specific rule.')
    ..addOption('validate-faql',
        help: 'Validate the syntax of a specific .faql file.');

  late ArgResults argResults;
  try {
    argResults = parser.parse(args);
  } catch (e) {
    _printError(e.toString());
    print(parser.usage);
    exit(2);
  }

  if (argResults['help'] as bool) {
    _printUsage(parser);
    exit(0);
  }

  if (argResults['version'] as bool) {
    print('flutter_a11y_lints version $_version');
    exit(0);
  }

  // --- Utility Commands ---

  if (argResults['init'] as bool) {
    _scaffoldRulesDirectory();
    exit(0);
  }

  if (argResults['validate-faql'] != null) {
    await _validateFaqlFile(argResults['validate-faql'] as String);
    exit(0);
  }

  // --- Rule Loading ---

  final rulesDir = argResults['rules-dir'] as String?;
  final ruleLogger = (String msg) => stderr.writeln('[rules] $msg');
  final catalog = FaqlRuleCatalog(logger: ruleLogger);
  final activeRules = catalog.load(customRulesDir: rulesDir);

  if (argResults['list-rules'] as bool) {
    if (activeRules.isEmpty) {
      print('No active FAQL rules.');
      exit(0);
    }
    final sortedRules = activeRules.values.toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    print('Active FAQL Rules:');
    for (final rule in sortedRules) {
      final sourceLabel = rule.sourcePath != null ? 'custom' : 'builtin';
      print(
          ' - ${rule.code} (${rule.severity}) [$sourceLabel] • ${rule.message}');
    }
    exit(0);
  }

  if (argResults['show-rule'] != null) {
    final code = argResults['show-rule'] as String;
    final rule = activeRules[code];
    if (rule == null) {
      _printError('Rule "$code" not found.');
      exit(2);
    }
    if (rule.source != null) {
      print(rule.source);
      exit(0);
    }
    if (rule.sourcePath != null) {
      try {
        print(File(rule.sourcePath!).readAsStringSync());
        exit(0);
      } catch (_) {
        // ignore and fall through
      }
    }
    print('// Source not available');
    exit(0);
  }

  // --- Analysis Phase ---

  if (argResults.rest.isEmpty) {
    _printError('No target path provided.');
    _printUsage(parser);
    exit(1);
  }

  final targetPath = argResults.rest.first;
  final verbose = argResults['verbose'] as bool;

  // Parse Glob excludes
  final excludeRaw = argResults['exclude'] as String;
  final excludes = excludeRaw
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .map((e) => Glob(e))
      .toList();

  if (verbose) print('Analyzing: $targetPath');

  final analyzer = FlutterA11yAnalyzer(
    faqlRunner: activeRules.isNotEmpty
        ? FaqlRuleRunner(rules: activeRules.values.toList())
        : null,
    runDartRules: !(argResults['faql-only'] as bool),
    runFaqlRules: !(argResults['dart-only'] as bool),
    verbose: verbose,
    excludes: excludes, // Pass excludes to analyzer
  );

  List<A11yIssue> issues;
  try {
    issues = await analyzer.analyze(targetPath);
  } catch (e, st) {
    _printError('Analysis failed: $e');
    if (verbose) stderr.writeln(st);
    exit(3);
  }

  // --- Reporting ---

  final reporter = argResults['reporter'] as String;
  _reportIssues(issues, reporter);

  // --- Exit Code ---

  final failOnWarnings = argResults['fail-on-warnings'] as bool;

  if (issues.any((i) => i.severity == 'error')) exit(1);
  if (issues.isNotEmpty && failOnWarnings) exit(1);
  exit(0);
}

// ----------------------------------------------------------------------
// Core Analysis Engine
// ----------------------------------------------------------------------

class FlutterA11yAnalyzer {
  final KnownSemanticsRepository _knownSemantics = KnownSemanticsRepository();
  final FaqlRuleRunner? faqlRunner;
  final bool runDartRules;
  final bool runFaqlRules;
  final bool verbose;
  final List<Glob> excludes;

  FlutterA11yAnalyzer({
    this.faqlRunner,
    this.runDartRules = true,
    this.runFaqlRules = true,
    this.verbose = false,
    this.excludes = const [],
  });

  Future<List<A11yIssue>> analyze(String path) async {
    final issues = <A11yIssue>[];
    final resourceProvider = PhysicalResourceProvider.INSTANCE;

    final targetFile = File(path);
    final targetDir = Directory(path);

    if (!targetFile.existsSync() && !targetDir.existsSync()) {
      throw Exception('Path "$path" does not exist.');
    }

    final analysisRoot = targetFile.existsSync()
        ? p.normalize(targetFile.parent.absolute.path)
        : p.normalize(targetDir.absolute.path);

    final collection = AnalysisContextCollection(
      includedPaths: [analysisRoot],
      resourceProvider: resourceProvider,
    );

    final filesToAnalyze = <String>[];
    if (targetFile.existsSync()) {
      filesToAnalyze.add(p.normalize(targetFile.absolute.path));
    } else {
      if (verbose) print('Scanning directory for Dart files...');
      // Use BFS or recursive list to find files
      await for (final entity in targetDir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final absPath = p.normalize(entity.absolute.path);
          final relPath = p.relative(absPath, from: analysisRoot);

          // --- FIX: Apply Exclusions ---
          if (excludes.any((glob) => glob.matches(relPath))) {
            if (verbose) print('Skipping excluded file: $relPath');
            continue;
          }

          filesToAnalyze.add(absPath);
        }
      }
    }

    for (final filePath in filesToAnalyze) {
      // Safety check: ensure context exists
      try {
        final context = collection.contextFor(filePath);
        final unitResult =
            await context.currentSession.getResolvedUnit(filePath);

        if (unitResult is! ResolvedUnitResult) continue;
        if (!fileUsesFlutter(unitResult)) continue;

        if (verbose)
          print('Checking ${p.relative(filePath, from: analysisRoot)}...');
        issues.addAll(_analyzeFile(unitResult));
      } catch (e) {
        if (verbose) stderr.writeln('Failed to analyze $filePath: $e');
      }
    }

    return issues;
  }

  List<A11yIssue> _analyzeFile(ResolvedUnitResult unit) {
    final issues = <A11yIssue>[];
    final irBuilder =
        SemanticIrBuilder(unit: unit, knownSemantics: _knownSemantics);
    final buildMethods = findBuildMethods(unit.unit);

    for (final method in buildMethods) {
      final expression = extractBuildBodyExpression(method);
      if (expression == null) continue;

      final tree = irBuilder.buildForExpression(expression);
      if (tree == null) continue;

      // 1. Legacy Dart Rules
      if (runDartRules) {
        final violations = A01UnlabeledInteractive.checkTree(tree);
        for (final v in violations) {
          issues.add(_mapViolation(
              unit,
              v.node.astNode.offset,
              'warning',
              A01UnlabeledInteractive.code,
              A01UnlabeledInteractive.message,
              A01UnlabeledInteractive.correctionMessage));
        }
      }

      // 2. FAQL Rules
      if (runFaqlRules && faqlRunner != null) {
        final violations = faqlRunner!.run(tree);
        for (final v in violations) {
          issues.add(_mapViolation(unit, v.node.astNode.offset, v.spec.severity,
              v.spec.code, v.spec.message, v.spec.correctionMessage));
        }
      }
    }
    return issues;
  }

  A11yIssue _mapViolation(ResolvedUnitResult unit, int offset, String severity,
      String code, String msg, String correction) {
    final loc = unit.lineInfo.getLocation(offset);
    return A11yIssue(
      file: unit.path,
      line: loc.lineNumber,
      column: loc.columnNumber,
      severity: severity,
      code: code,
      message: msg,
      correctionMessage: correction,
    );
  }
}

Future<void> _validateFaqlFile(String path) async {
  final file = File(path);
  if (!file.existsSync()) {
    _printError('File not found: $path');
    exit(2);
  }
  try {
    final content = await file.readAsString();
    final parser = FaqlParser();
    final rule = parser.parseRule(content);
    final validator = FaqlSemanticValidator(faqlAllowedIdentifiers);
    validator.validate(rule);
    print('SUCCESS: "$path" is a valid FAQL rule.');
    print('Code: ${rule.name}');
    print('Structure: Valid');
  } catch (e) {
    _printError('VALIDATION FAILED:\n$e');
    exit(3);
  }
}

void _scaffoldRulesDirectory() {
  final dir = Directory('a11y_rules');
  if (dir.existsSync()) {
    print('Directory "a11y_rules" already exists.');
    return;
  }
  dir.createSync();
  final sampleFile = File(p.join(dir.path, 'custom_label.faql'));
  sampleFile.writeAsStringSync(r'''
rule "custom_buttons_must_have_labels" on role("button") {
  meta {
    severity: "error"
    author: "Your Name"
  }
  // Ensure all buttons have resolved text labels
  ensure: label.is_resolved
  report: "All buttons must have a semantic label."
}
''');
  print('Created "a11y_rules/" with a sample rule.');
  print('Run with: a11y --rules-dir a11y_rules lib/');
}

void _reportIssues(List<A11yIssue> issues, String format) {
  if (issues.isEmpty) {
    if (format == 'console') print('No issues found.');
    return;
  }

  if (format == 'json') {
    final jsonList = issues
        .map((i) => {
              'file': i.file,
              'line': i.line,
              'column': i.column,
              'severity': i.severity,
              'code': i.code,
              'message': i.message,
            })
        .toList();
    print(JsonEncoder.withIndent('  ').convert(jsonList));
  } else if (format == 'machine') {
    for (final i in issues) {
      // Machine format: SEVERITY|CODE|FILE|LINE|COL|MESSAGE
      print(
          '${i.severity}|${i.code}|${i.file}|${i.line}|${i.column}|${i.message}');
    }
  } else {
    // Console
    print('');
    for (final i in issues) {
      final color =
          i.severity == 'error' ? '\u001b[31m' : '\u001b[33m'; // Red/Yellow
      final reset = '\u001b[0m';
      print(
          '$color${i.severity.toUpperCase()}$reset • ${i.message} • ${i.code}');
      print('  ${i.file}:${i.line}:${i.column}');
      print('');
    }
    print('Total: ${issues.length} issue(s).');
  }
}

void _printUsage(ArgParser parser) {
  print('Flutter A11y Linter - Semantic Accessibility Analysis');
  print('Usage: a11y [options] <file_or_directory>');
  print('\nOptions:');
  print(parser.usage);
}

void _printError(String msg) {
  stderr.writeln('\u001b[31mERROR: $msg\u001b[0m');
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
}
