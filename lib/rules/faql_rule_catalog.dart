import 'dart:io';

import 'package:path/path.dart' as p;

import '../src/facts/fact_store.dart';
import '../src/query/faql4.dart';
import 'builtin_faql_rules.g.dart' as builtin;
import 'faql_rule_runner.dart';

/// Optional logger used during rule collection to surface parse/validation issues.
typedef RuleLoadLogger = void Function(String message);

/// One coherent set of active queries and the indexes derived from it.
class LoadedRuleCatalog {
  LoadedRuleCatalog(List<CompiledQuery> queries)
      : queries = List.unmodifiable(queries),
        byQueryId = Map.unmodifiable({
          for (final query in queries) query.queryId: query,
        }),
        byRuleId = Map.unmodifiable({
          for (final query in queries)
            query.ruleId: List<CompiledQuery>.unmodifiable(
              queries.where((other) => other.ruleId == query.ruleId),
            ),
        }),
        byMode = Map.unmodifiable({
          for (final mode in FactMode.values)
            mode: List<CompiledQuery>.unmodifiable(
              queries.where((query) => query.mode == mode),
            ),
        });

  final List<CompiledQuery> queries;
  final Map<String, CompiledQuery> byQueryId;
  final Map<String, List<CompiledQuery>> byRuleId;
  final Map<FactMode, List<CompiledQuery>> byMode;
}

/// Loads FAQL rules from the embedded bundle and optional user directories.
class FaqlRuleCatalog {
  FaqlRuleCatalog({Faql4Compiler? compiler, this.logger})
      : _compiler = compiler ?? Faql4Compiler(),
        _builtin = builtin.builtinFaqlRules;

  final List<CompiledQuery> _builtin;
  final Faql4Compiler _compiler;
  final RuleLoadLogger? logger;

  LoadedRuleCatalog load({String? customRulesDir}) {
    final collected = <FaqlRuleSpec>[..._builtin];

    if (customRulesDir == null || customRulesDir.trim().isEmpty) {
      return LoadedRuleCatalog(collected);
    }

    final normalizedDir = p.normalize(customRulesDir);
    final dir = Directory(normalizedDir);
    if (!dir.existsSync()) {
      _log('Rules directory "$normalizedDir" does not exist.');
      return LoadedRuleCatalog(collected);
    }

    final files = dir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.faql'))
        .toList()
      ..sort((left, right) => left.path.compareTo(right.path));

    for (final entity in files) {
      final content = entity.readAsStringSync();
      _tryAddRule(
        content: content,
        sourceDescriptor: p.basename(entity.path),
        collection: collected,
      );
    }

    return LoadedRuleCatalog(collected);
  }

  void _tryAddRule({
    required String content,
    required String sourceDescriptor,
    required List<FaqlRuleSpec> collection,
  }) {
    late final CompiledQuery spec;
    try {
      spec = _compiler.compile(content);
    } catch (error) {
      _log('Failed to load rule "$sourceDescriptor": $error');
      return;
    }

    if (collection.any((existing) => existing.queryId == spec.queryId)) {
      final error = Faql4ValidationError('Duplicate query id ${spec.queryId}.');
      _log('Failed to load rule "$sourceDescriptor": $error');
      throw error;
    }

    collection.add(spec);
  }

  void _log(String message) {
    if (logger != null) {
      logger!(message);
    }
  }
}
