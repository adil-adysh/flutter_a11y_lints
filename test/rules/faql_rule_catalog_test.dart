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

    test('contains exactly the approved conservative query IDs', () {
      expect(
        builtin.builtinFaqlRules.map((query) => query.queryId).toSet(),
        {
          'flutter-a11y/a01/unlabeled-interactive',
          'flutter-a11y/a04/list-tile-image-labeled',
          'flutter-a11y/a22/respect-widget-semantic-boundaries',
          'flutter-a11y/merge/multiple-actions',
        },
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

    test('keeps expanded custom queries out of the default query set', () {
      final directory = Directory.systemTemp.createTempSync('faql-catalog-');
      addTearDown(() => directory.deleteSync(recursive: true));
      File('${directory.path}${Platform.pathSeparator}expanded.faql')
          .writeAsStringSync(_coreQuery('custom/expanded', mode: 'expanded'));

      final catalog = FaqlRuleCatalog().load(customRulesDir: directory.path);

      expect(
        catalog.defaultQueries.map((query) => query.queryId),
        isNot(contains('custom/expanded')),
      );
      expect(
        catalog.byMode[FactMode.expanded]?.map((query) => query.queryId),
        contains('custom/expanded'),
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

String _coreQuery(String id, {String mode = 'conservative'}) => '''
@id $id
@rule-id a01_custom
@mode $mode
@severity warning
from SemanticNode node
select node, "Test diagnostic."
''';
