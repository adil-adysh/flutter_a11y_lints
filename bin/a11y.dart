#!/usr/bin/env dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:glob/glob.dart'; // REQUIRED: Add to pubspec.yaml

// Generated file containing built-in rules map
import 'package:flutter_a11y_lints/rules/faql_rule_catalog.dart';
import 'package:flutter_a11y_lints/rules/faql_rule_runner.dart';
import 'package:flutter_a11y_lints/src/query/faql4.dart';
import 'package:flutter_a11y_lints/src/analyzer/flutter_a11y_analyzer.dart'
    as analyzer_api;
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
    // (Legacy Dart-rule engine removed; FAQL is the single rule engine.)
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
  final activeRules =
      catalog.load(customRulesDir: rulesDir).defaultQueries;

  if (argResults['list-rules'] as bool) {
    if (activeRules.isEmpty) {
      print('No active FAQL rules.');
      exit(0);
    }
    final sortedRules = [...activeRules]
      ..sort((a, b) => a.queryId.compareTo(b.queryId));
    print('Active FAQL Rules:');
    for (final rule in sortedRules) {
      print(' - ${rule.queryId} (${rule.severity}) • ${rule.message}');
    }
    exit(0);
  }

  if (argResults['show-rule'] != null) {
    final code = argResults['show-rule'] as String;
    final matches = activeRules.where((item) => item.queryId == code);
    final rule = matches.isEmpty ? null : matches.first;
    if (rule == null) {
      _printError('Rule "$code" not found.');
      exit(2);
    }
    print('${rule.queryId} (${rule.ruleId})');
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

  final analyzer = analyzer_api.FlutterA11yAnalyzer(
    faqlRunner:
        activeRules.isNotEmpty ? FaqlRuleRunner(rules: activeRules) : null,
    verbose: verbose,
    excludes: excludes, // Pass excludes to analyzer
  );

  List<analyzer_api.A11yIssue> issues;
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

Future<void> _validateFaqlFile(String path) async {
  final file = File(path);
  if (!file.existsSync()) {
    _printError('File not found: $path');
    exit(2);
  }
  try {
    final content = await file.readAsString();
    final rule = Faql4Compiler().compile(content);
    print('SUCCESS: "$path" is a valid FAQL rule.');
    print('Query ID: ${rule.queryId}');
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
@id custom/buttons-must-have-labels
@rule-id custom_buttons_must_have_labels
@severity error
@mode conservative
from InteractiveControl control
where control.isDefinitelyEnabled() and control.isDefinitelyUnlabeled()
select control, "All buttons must have a semantic label."
''');
  print('Created "a11y_rules/" with a sample rule.');
  print('Run with: a11y --rules-dir a11y_rules lib/');
}

void _reportIssues(List<analyzer_api.A11yIssue> issues, String format) {
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

