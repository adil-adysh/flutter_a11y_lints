import 'package:flutter_a11y_lints/rules/faql_rule_runner.dart';
import 'package:flutter_a11y_lints/src/query/faql4.dart';
import 'package:test/test.dart';

import '../rules/test_semantic_utils.dart';

void main() {
  test('reports a definitely unlabeled interactive semantic node', () {
    const source = '''
@id flutter-a11y/a01/unlabeled-interactive
@rule-id a01_unlabeled_interactive
@severity warning
@mode conservative
from InteractiveControl control
where control.isDefinitelyEnabled() and control.isDefinitelyUnlabeled()
select control, "Interactive control must have an accessible label."
''';
    final tree = buildManualTree(makeSemanticNode());
    final runner = FaqlRuleRunner(rules: [Faql4Compiler().compile(source)]);

    expect(runner.run(tree), hasLength(1));
  });
}
