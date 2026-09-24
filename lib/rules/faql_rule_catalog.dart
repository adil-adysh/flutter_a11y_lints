import 'dart:io';

import 'package:path/path.dart' as p;

import '../src/query/faql4.dart';
import 'builtin_faql_rules.g.dart' as builtin;
import 'faql_rule_runner.dart';

/// Optional logger used during rule collection to surface parse/validation issues.
typedef RuleLoadLogger = void Function(String message);

/// Loads FAQL rules from the embedded bundle and optional user directories.
class FaqlRuleCatalog {
  FaqlRuleCatalog({
    Faql4Compiler? compiler,
    this.logger,
  }) : _compiler = compiler ?? Faql4Compiler();

  final Faql4Compiler _compiler;
  final RuleLoadLogger? logger;

  List<FaqlRuleSpec> load({String? customRulesDir}) {
    final collected = <FaqlRuleSpec>[];

    for (final entry in builtin.builtinFaqlRules.entries) {
      _tryAddRule(
        content: entry.value,
        sourceDescriptor: entry.key,
        sourcePath: null,
        collection: collected,
      );
    }

    if (customRulesDir == null || customRulesDir.trim().isEmpty) {
      return List.unmodifiable(collected);
    }

    final normalizedDir = p.normalize(customRulesDir);
    final dir = Directory(normalizedDir);
    if (!dir.existsSync()) {
      _log('Rules directory "$normalizedDir" does not exist.');
      return List.unmodifiable(collected);
    }

    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      if (!entity.path.toLowerCase().endsWith('.faql')) continue;

      final content = entity.readAsStringSync();
      _tryAddRule(
        content: content,
        sourceDescriptor: p.basename(entity.path),
        sourcePath: entity.path,
        collection: collected,
      );
    }

    return List.unmodifiable(collected);
  }

  void _tryAddRule({
    required String content,
    required String sourceDescriptor,
    String? sourcePath,
    required List<FaqlRuleSpec> collection,
  }) {
    try {
      final spec = _compiler.compile(content);
      if (collection.any((existing) => existing.queryId == spec.queryId)) {
        throw Faql4ValidationError('Duplicate query id ${spec.queryId}.');
      }
      collection.add(spec);
    } catch (error) {
      _log('Failed to load rule "$sourceDescriptor": $error');
    }
  }

  void _log(String message) {
    if (logger != null) {
      logger!(message);
    }
  }
}
