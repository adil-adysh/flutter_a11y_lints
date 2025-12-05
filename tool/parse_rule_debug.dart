import 'package:flutter_a11y_lints/src/faql/parser.dart';
import 'package:flutter_a11y_lints/src/faql/ast.dart';
import 'package:flutter_a11y_lints/src/faql/grammar.dart';

void inspect(String ruleText) {
  final parser = FaqlParser();
  print('--- Parsing rule: ' + ruleText);
  final rule = parser.parseRule(ruleText);
  final ensure = rule.ensure;
  print('ensure node: $ensure');
  print('ensure runtimeType: ${ensure.runtimeType}');
  if (ensure is BinaryExpression) {
    final left = ensure.left;
    final right = ensure.right;
    print('LEFT AST: $left  (runtimeType: ${left.runtimeType})');
    print('RIGHT AST: $right (runtimeType: ${right.runtimeType})');
    if (left is PropExpression)
      print(
          'LEFT prop name: ${left.name} asType:${left.asType} isResolved:${left.isResolved}');
    if (right is LiteralExpression)
      print(
          'RIGHT literal value: ${right.value} (type: ${right.value.runtimeType})');
    if (right is Identifier) print('RIGHT Identifier name: ${right.name}');
  }
}

void main() {
  final rule =
      'rule "r" on any { ensure: (prop("f") as bool) == true report: "" }';
  inspect(rule);
  // Also parse via grammar.build() directly to inspect the raw parse value
  final grammar = FaqlGrammar();
  final built = grammar.build();
  final raw = built.parse(rule);
  print('raw parse for rule via grammar.build(): $raw');

  // Also inspect the exact string literal used in tests to ensure quoting not an issue
  final rule2 =
      'rule "r2" on any { ensure: (prop("f") as bool) == false report: "" }';
  inspect(rule2);

  // Inspect a minimal expression parsed by grammar to see boolean literal parsing
  final parser = FaqlParser();
  final r3 = parser.parseRule('rule "r3" on any { ensure: true report: "" }');
  print('simple true ensure: ${r3.ensure} (type ${r3.ensure.runtimeType})');
  final r4 = parser.parseRule('rule "r4" on any { ensure: false report: "" }');
  print('simple false ensure: ${r4.ensure} (type ${r4.ensure.runtimeType})');

  // Directly probe the grammar's booleanLiteral parser
  final pTrue = grammar.booleanLiteral().parse('true');
  final pFalse = grammar.booleanLiteral().parse('false');
  print('booleanLiteral.parse("true") -> ${pTrue}');
  print('booleanLiteral.parse("false") -> ${pFalse}');

  // Parse expression via grammar.expression to see what it produces for 'true'/'false'
  final litTrue = grammar.literal().parse('true');
  final litFalse = grammar.literal().parse('false');
  print('grammar.literal().parse("true") -> $litTrue');
  print('grammar.literal().parse("false") -> $litFalse');
}
