import 'package:test/test.dart';
import 'package:flutter_a11y_lints/src/faql/parser.dart';
import 'package:flutter_a11y_lints/src/faql/ast.dart';

void main() {
  final parser = FaqlParser();

  test('meta block parsing', () {
    const input = '''
      rule "m" on any {
        meta { severity: "warning" id: "W01" }
        ensure: focusable
        report: "r"
      }
    ''';

    final rule = parser.parseRule(input);
    expect(rule.meta.containsKey('severity'), isTrue);
    expect(rule.meta['severity'], 'warning');
    expect(rule.meta['id'], 'W01');
  });

  test('when clause is parsed separately', () {
    const input = '''
      rule "w" on any {
        when: prop("enabled") == true
        ensure: prop("x") == 1
        report: "r"
      }
    ''';

    final rule = parser.parseRule(input);
    expect(rule.when, isA<BinaryExpression>());
    final when = rule.when as BinaryExpression;
    expect(when.left, isA<PropExpression>());
  });

  test('invalid rule missing ensure throws', () {
    const input = 'rule "bad" on any { report: "r" }';
    expect(() => parser.parseRule(input), throwsFormatException);
  });
}
