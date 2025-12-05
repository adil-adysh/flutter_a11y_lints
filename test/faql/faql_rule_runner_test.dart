import 'package:flutter_a11y_lints/src/faql/parser.dart';
import 'package:flutter_a11y_lints/rules/faql_rule_runner.dart';
import 'package:test/test.dart';

import '../rules/test_semantic_utils.dart';

void main() {
  const ruleText = '''
rule "faql_label_required" on any {
  ensure: prop("label").is_resolved || prop("tooltip").is_resolved
  report: "Need label"
}
''';

  test('flags unlabeled focusable node', () {
    final parser = FaqlParser();
    final rule = parser.parseRule(ruleText);
    final spec = FaqlRuleSpec.fromRule(rule);
    final runner = FaqlRuleRunner(rules: [spec]);

    final node = makeSemanticNode(
      label: null,
      tooltip: null,
      isFocusable: true,
      isEnabled: true,
    );
    final tree = buildManualTree(node);

    final violations = runner.run(tree);
    expect(violations, hasLength(1));
    expect(violations.first.spec.code, spec.code);
  });

  test('passes when label present', () {
    final parser = FaqlParser();
    final rule = parser.parseRule(ruleText);
    final spec = FaqlRuleSpec.fromRule(rule);
    final runner = FaqlRuleRunner(rules: [spec]);

    final node = makeSemanticNode(
      label: 'ok',
      isFocusable: true,
      isEnabled: true,
    );
    final tree = buildManualTree(node);

    final violations = runner.run(tree);
    expect(violations, isEmpty);
  });
}
