import 'dart:io';

import 'package:path/path.dart' as p;

import '../src/facts/semantic_fact_extractor.dart';
import '../src/query/faql4.dart';
import '../src/semantics/semantic_node.dart';
import '../src/semantics/semantic_tree.dart';

typedef FaqlRuleSpec = CompiledQuery;

class FaqlRuleViolation {
  FaqlRuleViolation({required this.node, required this.spec});

  final SemanticNode node;
  final FaqlRuleSpec spec;
}

class FaqlRuleRunner {
  FaqlRuleRunner({required List<FaqlRuleSpec> rules}) : _rules = rules;

  final List<FaqlRuleSpec> _rules;

  List<FaqlRuleViolation> run(SemanticTree tree) {
    final extracted = SemanticFactExtractor().extract(tree);
    final evaluator = Faql4Evaluator();
    final hits = <FaqlRuleViolation>[];
    for (final spec in _rules) {
      for (final violation in evaluator.evaluate(spec, extracted.store)) {
        final node = tree.byId[violation.nodeId];
        if (node != null) hits.add(FaqlRuleViolation(node: node, spec: spec));
      }
    }
    return hits;
  }

  static Future<List<FaqlRuleSpec>> loadFromDirectory(
    String directoryPath, {
    Faql4Compiler? compiler,
  }) async {
    final dir = Directory(directoryPath);
    if (!dir.existsSync()) return const [];

    final p2 = compiler ?? Faql4Compiler();
    final specs = <FaqlRuleSpec>[];

    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      if (!entity.path.toLowerCase().endsWith('.faql')) continue;
      final content = await entity.readAsString();
      specs.add(p2.compile(content));
    }

    return specs;
  }

  static String defaultRulesDirFromScript(Uri scriptUri) {
    final scriptPath = p.fromUri(scriptUri);
    return p
        .normalize(p.join(p.dirname(scriptPath), '..', 'lib', 'rules'));
  }
}
