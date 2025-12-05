import 'dart:io';

import 'package:path/path.dart' as p;

import '../src/bridge/semantic_faql_adapter.dart';
import '../src/faql/ast.dart';
import '../src/faql/interpreter.dart';
import '../src/faql/parser.dart';
import '../src/faql/validator.dart';
import '../src/semantics/semantic_node.dart';
import '../src/semantics/semantic_tree.dart';

class FaqlRuleSpec {
  FaqlRuleSpec({
    required this.rule,
    required this.code,
    required this.message,
    required this.correctionMessage,
    required this.severity,
    this.sourcePath,
    this.source,
  });

  final FaqlRule rule;
  final String code;
  final String message;
  final String correctionMessage;
  final String severity;
  final String? sourcePath;
  final String? source;

  static FaqlRuleSpec fromRule(FaqlRule rule,
      {String? sourcePath, String? source}) {
    final meta = rule.meta;
    final severity = meta['severity'] ?? 'warning';
    final code = meta['code'] ?? rule.name;
    final message = meta['message'] ?? rule.report;
    final correction = meta['correction'] ?? message;
    return FaqlRuleSpec(
      rule: rule,
      code: code,
      message: message,
      correctionMessage: correction,
      severity: severity,
      sourcePath: sourcePath,
      source: source,
    );
  }
}

class FaqlRuleViolation {
  FaqlRuleViolation({required this.node, required this.spec});

  final SemanticNode node;
  final FaqlRuleSpec spec;
}

class FaqlRuleRunner {
  FaqlRuleRunner(
      {required List<FaqlRuleSpec> rules, FaqlInterpreter? interpreter})
      : _rules = rules,
        _interpreter = interpreter ?? FaqlInterpreter();

  final List<FaqlRuleSpec> _rules;
  final FaqlInterpreter _interpreter;

  List<FaqlRuleViolation> run(SemanticTree tree) {
    final hits = <FaqlRuleViolation>[];
    for (final node in tree.physicalNodes) {
      final ctx = SemanticFaqlContext(node: node, tree: tree);
      for (final spec in _rules) {
        final passed = _interpreter.evaluate(spec.rule, ctx);
        if (passed != true) {
          hits.add(FaqlRuleViolation(node: node, spec: spec));
        }
      }
    }
    return hits;
  }

  static Future<List<FaqlRuleSpec>> loadFromDirectory(
    String directoryPath, {
    FaqlParser? parser,
    FaqlSemanticValidator? validator,
    Set<String>? allowedIdentifiers,
  }) async {
    final dir = Directory(directoryPath);
    if (!dir.existsSync()) return const [];

    final p2 = parser ?? FaqlParser();
    final specs = <FaqlRuleSpec>[];

    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      if (!entity.path.toLowerCase().endsWith('.faql')) continue;
      final content = await entity.readAsString();
      // Parser now supports multiple rules per file. Use parseRules to
      // obtain all rules defined in the file.
      final rules = p2.parseRules(content);
      for (final rule in rules) {
        if (validator != null) {
          validator.validate(rule);
        } else if (allowedIdentifiers != null &&
            allowedIdentifiers.isNotEmpty) {
          FaqlSemanticValidator(allowedIdentifiers).validate(rule);
        }
        specs.add(FaqlRuleSpec.fromRule(rule,
            sourcePath: entity.path, source: content));
      }
    }

    return specs;
  }

  static String defaultRulesDirFromScript(Uri scriptUri) {
    final scriptPath = p.fromUri(scriptUri);
    return p
        .normalize(p.join(p.dirname(scriptPath), '..', 'lib', 'src', 'rules'));
  }
}
