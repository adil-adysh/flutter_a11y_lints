import 'package:flutter_a11y_lints/src/query/faql4.dart';
import 'package:test/test.dart';

const _header = '''
@id example/query
@rule-id example
@severity warning
@mode conservative
''';

void main() {
  test('rejects unknown Core members before evaluation', () {
    expect(
      () => Faql4Compiler().compile('''
$_header
from SemanticNode node
where node.notAStandardPredicate()
select node, "x"
'''),
      throwsA(isA<Faql4ValidationError>()),
    );
  });

  test('rejects nested conservative negation of partial label evidence', () {
    expect(
      () => Faql4Compiler().compile('''
$_header
from SemanticNode node
where not (node.hasAccessibleLabel() or node.hasTapAction())
select node, "x"
'''),
      throwsA(isA<Faql4ValidationError>()),
    );
  });
}
