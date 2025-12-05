import 'dart:io';

import 'package:path/path.dart' as p;

import '../bridge/semantic_faql_adapter.dart';
import '../faql/ast.dart';
import '../faql/interpreter.dart';
import '../faql/parser.dart';
import '../faql/validator.dart';
import '../semantics/semantic_node.dart';
import '../semantics/semantic_tree.dart';

class FaqlRuleSpec {
  FaqlRuleSpec({
    required this.rule,
    required this.code,
    required this.message,
    required this.correctionMessage,
    required this.severity,
    this.sourcePath,
  });

  final FaqlRule rule;
  final String code;
  final String message;
  final String correctionMessage;
  final String severity;
  final String? sourcePath;

  static FaqlRuleSpec fromRule(FaqlRule rule, {String? sourcePath}) {
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
    );
  }
}

class FaqlRuleViolation {
  FaqlRuleViolation({required this.node, required this.spec});

  final SemanticNode node;
  final FaqlRuleSpec spec;
}

class FaqlRuleRunner {
  FaqlRuleRunner({required List<FaqlRuleSpec> rules, FaqlInterpreter? interpreter})
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
      final rule = p2.parseRule(content);
      if (validator != null) {
        validator.validate(rule);
      } else if (allowedIdentifiers != null && allowedIdentifiers.isNotEmpty) {
        FaqlSemanticValidator(allowedIdentifiers).validate(rule);
      }
      specs.add(FaqlRuleSpec.fromRule(rule, sourcePath: entity.path));
    }

    return specs;
  }

  static String defaultRulesDirFromScript(Uri scriptUri) {
    final scriptPath = p.fromUri(scriptUri);
    return p.normalize(p.join(p.dirname(scriptPath), '..', 'lib', 'src', 'rules'));
  }
}
