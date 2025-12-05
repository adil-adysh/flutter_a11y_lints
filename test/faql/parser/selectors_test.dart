import 'package:test/test.dart';
import 'package:flutter_a11y_lints/src/faql/parser.dart';
import 'package:flutter_a11y_lints/src/faql/ast.dart';

void main() {
  final parser = FaqlParser();

  test('selectors: role and kind combined', () {
    const input = '''
      rule "sel" on role(button) || kind(input) { ensure: focusable report: "r" }
    ''';

    final rule = parser.parseRule(input);
    expect(rule.selectors.length, 2);
    expect(rule.selectors[0], isA<RoleSelector>());
    expect((rule.selectors[0] as RoleSelector).role, 'button');
    expect(rule.selectors[1], isA<KindSelector>());
  });

  test('selector type and identifier underscores', () {
    const input =
        'rule "s" on type(My_Widget) { ensure: focusable report: "r" }';
    final rule = parser.parseRule(input);
    expect(rule.selectors.length, 1);
    expect(rule.selectors.first, isA<TypeSelector>());
    expect((rule.selectors.first as TypeSelector).type, 'My_Widget');
  });
}