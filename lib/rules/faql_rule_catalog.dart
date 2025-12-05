import 'dart:io';

import 'package:path/path.dart' as p;

import '../bridge/semantic_faql_adapter.dart';
import '../faql/parser.dart';
import '../faql/validator.dart';
import 'builtin_faql_rules.g.dart' as builtin;
import 'faql_rule_runner.dart';

/// Optional logger used during rule collection to surface parse/validation issues.
typedef RuleLoadLogger = void Function(String message);

/// Loads FAQL rules from the embedded bundle and optional user directories.
class FaqlRuleCatalog {
  FaqlRuleCatalog({
    FaqlParser? parser,
    FaqlSemanticValidator? validator,
    this.logger,
  })  : _parser = parser ?? FaqlParser(),
        _validator = validator ??
            FaqlSemanticValidator(faqlAllowedIdentifiers);

  final FaqlParser _parser;
  final FaqlSemanticValidator _validator;
  final RuleLoadLogger? logger;

  Map<String, FaqlRuleSpec> load({String? customRulesDir}) {
    final collected = <String, FaqlRuleSpec>{};

    for (final entry in builtin.builtinFaqlRules.entries) {
      _tryAddRule(
        content: entry.value,
        sourceDescriptor: entry.key,
        sourcePath: null,
        collection: collected,
      );
    }

    if (customRulesDir == null || customRulesDir.trim().isEmpty) {
      return collected;
    }

    final normalizedDir = p.normalize(customRulesDir);
    final dir = Directory(normalizedDir);
    if (!dir.existsSync()) {
      _log('Rules directory "$normalizedDir" does not exist.');
      return collected;
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

    return collected;
  }

  void _tryAddRule({
    required String content,
    required String sourceDescriptor,
    String? sourcePath,
    required Map<String, FaqlRuleSpec> collection,
  }) {
    try {
      final rule = _parser.parseRule(content);
      _validator.validate(rule);
      final spec = FaqlRuleSpec.fromRule(
        rule,
        sourcePath: sourcePath,
        source: content,
      );
      collection[spec.code] = spec;
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
