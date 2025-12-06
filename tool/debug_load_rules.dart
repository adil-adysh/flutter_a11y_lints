import 'dart:io';

import 'package:flutter_a11y_lints/rules/faql_rule_catalog.dart';
import 'package:flutter_a11y_lints/src/faql/parser.dart';
import 'package:flutter_a11y_lints/src/faql/grammar.dart';
import 'package:petitparser/petitparser.dart';

void main(List<String> args) {
  final dir = args.isNotEmpty ? args.first : 'a11y_rules';
    final catalog = FaqlRuleCatalog(logger: (s) => stderr.writeln('[rules] $s'));
    final rules = catalog.load(customRulesDir: dir);
    // Print details, including keys of collected entries
    print('Collected rule codes: ${rules.keys.toList()}');
    print('Loaded ${rules.length} rule(s) from $dir');
    for (final r in rules.values) {
      print('- ${r.code} (${r.severity})');
    }
  
    // Debug: parse file directly with parser
    // Parser debug: use Grammar to inspect parser errors precisely
    final file = File('$dir/custom_label.faql');
    if (file.existsSync()) {
      final content = file.readAsStringSync();
      // print codepoints for debug
      print('File codepoints: ${content.runes.toList()}');
      final parser2 = FaqlGrammar().build();
      final result = parser2.parse(content);
      if (result is Failure) {
        print('Grammar FAILED: ${result.message} at ${result.position}');
      } else if (result is Success) {
        print('Grammar SUCCESS: ${result.value.runtimeType}');
      } else {
        print('Grammar unknown result type: ${result.runtimeType}');
      }
      // Try the FaqlParser adapter as well to get a higher-level error
      final p = FaqlParser();
      try {
        final rules = p.parseRules(content);
        print('FaqlParser parsed ${rules.length} rule(s)');
      } catch (e) {
        print('FaqlParser error: $e');
      }
      // Try simple minimal rule
      final minimal = 'rule "x" on any { ensure: true report: "ok" }';
      try {
        final r = p.parseRules(minimal);
        print('Minimal parsed ${r.length}');
      } catch (e) {
        print('Minimal parse error: $e');
      }
    }
}
