import 'dart:io';

import 'package:flutter_a11y_lints/rules/faql_rule_catalog.dart';
import 'package:flutter_a11y_lints/rules/builtin_faql_rules.g.dart' as builtin;
import 'package:flutter_a11y_lints/src/facts/fact_store.dart';
import 'package:flutter_a11y_lints/src/query/faql4.dart';
import 'package:test/test.dart';

void main() {
  group('FaqlRuleCatalog', () {
    test('includes the validated merge-actions query in the bundle', () {
      expect(
        builtin.builtinFaqlRules.map((query) => query.queryId),
        contains('flutter-a11y/merge/multiple-actions'),
      );
    });
    test('indexes a valid custom Core query', () {
      final directory = Directory.systemTemp.createTempSync('faql-catalog-');
      addTearDown(() => directory.deleteSync(recursive: true));
      File('${directory.path}${Platform.pathSeparator}custom.faql')
          .writeAsStringSync(_coreQuery('custom/a01'));

      final catalog = FaqlRuleCatalog().load(customRulesDir: directory.path);

      expect(catalog.byQueryId['custom/a01']?.ruleId, 'a01_custom');
      expect(
        catalog.byMode[FactMode.conservative]?.map((query) => query.queryId),
        contains('custom/a01'),
      );
    });

    test('rejects duplicate custom query IDs instead of silently skipping one',
        () {
      final directory = Directory.systemTemp.createTempSync('faql-catalog-');
      addTearDown(() => directory.deleteSync(recursive: true));
      File('${directory.path}${Platform.pathSeparator}first.faql')
          .writeAsStringSync(_coreQuery('custom/duplicate'));
      File('${directory.path}${Platform.pathSeparator}second.faql')
          .writeAsStringSync(_coreQuery('custom/duplicate'));

      expect(
        () => FaqlRuleCatalog().load(customRulesDir: directory.path),
        throwsA(isA<Faql4ValidationError>()),
      );
    });
  });
}

String _coreQuery(String id) => '''
@id $id
@rule-id a01_custom
@mode conservative
@severity warning
from SemanticNode node
select node, "Test diagnostic."
''';
