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

  FaqlRule parseRule(String input) {
    final result = _parser.parse(input);
    if (result is! Success) {
      throw FormatException(
          'Parse error: ${result.message} at ${result.position}');
    }
    final value = result.value;
    if (value is FaqlRule) return value;
    throw FormatException('Parser did not return a FaqlRule');
  }
}
