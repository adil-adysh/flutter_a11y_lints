import 'package:flutter_a11y_lints/src/query/faql4.dart';
import 'package:test/test.dart';

void main() {
  test('parses Core metadata, quantifiers, and Boolean precedence', () {
    final query = parseFaql4('''
/** query docs */
@id example/merge
@rule-id example
@severity warning
@mode conservative
from MergeSemanticsNode merge
where not merge.excludesDescendants() and
  count(InteractiveControl control |
    control = merge.getADescendant()) >= 2 or
  exists(ImageNode image | image.hasStaticLabel())
select merge, "Multiple actions"
''');

    expect(query.where, isA<OrAst>());
    expect((query.where as OrAst).left, isA<AndAst>());
    expect(query.from.view, 'MergeSemanticsNode');
    expect(query.select.message, 'Multiple actions');
  });

  test('reports an offset for an invalid token', () {
    expect(
      () => parseFaql4(
          '@id x\nfrom SemanticNode node\nwhere #\nselect node, "x"'),
      throwsA(isA<Faql4ValidationError>().having(
        (error) => error.span?.start,
        'start',
        isNotNull,
      )),
    );
  });

  test('reports source locations for malformed comments and strings', () {
    for (final source in ['/* unterminated', '@id "unterminated']) {
      expect(
        () => Faql4Compiler().compile(source),
        throwsA(isA<Faql4ValidationError>()
            .having((error) => error.line, 'line', 1)
            .having((error) => error.column, 'column', 1)),
      );
    }
  });
}
