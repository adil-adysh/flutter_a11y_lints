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
            query.ruleId: List.unmodifiable(
              queries.where((other) => other.ruleId == query.ruleId),
            ),
        }),
        byMode = Map.unmodifiable({
          for (final mode in FactMode.values)
            mode: List.unmodifiable(
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

    return LoadedRuleCatalog(collected);
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
