import 'package:petitparser/petitparser.dart';
import 'grammar.dart';
import 'ast.dart';

/// Lightweight adapter around the Grammar parser that returns the FaqlRule
/// object produced by the grammar. This replaces the previous fragile
/// manual tree-scraping logic and relies on `FaqlGrammar` producing
/// AST nodes directly.
class FaqlParser {
  final Parser _parser;
  FaqlParser() : _parser = FaqlGrammar().build();

  /// Parse and return a single `FaqlRule`. If the input contains multiple
  /// rules this will return the first one and ignore the rest. Use
  /// [parseRules] to get all rules from the input.
  FaqlRule parseRule(String input) {
    final rules = parseRules(input);
    if (rules.isEmpty) throw FormatException('No rules found in input');
    return rules.first;
  }

  /// Parse and return all `FaqlRule`s found in the input.
  List<FaqlRule> parseRules(String input) {
    final result = _parser.parse(input);
    if (result is! Success) {
      throw FormatException(
          'Parse error: ${result.message} at ${result.position}');
    }
    final value = result.value;
    if (value is FaqlRule) return [value];
    if (value is List) return value.cast<FaqlRule>();
    throw FormatException('Parser did not return FaqlRule(s)');
  }
}
