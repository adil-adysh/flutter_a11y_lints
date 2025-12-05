import 'package:test/test.dart';
import 'package:flutter_a11y_lints/src/faql/parser.dart';
import 'package:flutter_a11y_lints/src/faql/ast.dart';

void main() {
  test('string literal with escaped quote parses and unescapes', () {
    final parser = FaqlParser();
    // note: the Dart string below includes an escaped quote for the FAQL literal
    final input =
        'rule "t" on any { ensure: role == "Menu\\"Button" report: "ok" }';

    final rule = parser.parseRule(input);
    expect(rule, isA<FaqlRule>());
    final ensure = rule.ensure;
    expect(ensure, isA<BinaryExpression>());
    final bin = ensure as BinaryExpression;
    expect(bin.right, isA<LiteralExpression>());
    final lit = bin.right as LiteralExpression;
    expect(lit.value, equals('Menu"Button'));
  });
}
