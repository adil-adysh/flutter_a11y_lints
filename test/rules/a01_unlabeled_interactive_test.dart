import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_a11y_lints/src/pipeline/semantic_ir_builder.dart';
import 'package:flutter_a11y_lints/src/rules/a01_unlabeled_interactive.dart';
import 'package:flutter_a11y_lints/src/semantics/known_semantics.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_tree.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('A01 - unlabeled interactive', () {
    test('FloatingActionButton.extended with label is accepted', () async {
      final tree = await _buildTree('''
        FloatingActionButton.extended(
          onPressed: () {},
          icon: const Icon('add'),
          label: const Text('Create Meditation'),
        )
      ''');

      expect(tree.root.labelGuarantee, isNot(LabelGuarantee.none));
      expect(
        A01UnlabeledInteractive.checkTree(tree),
        isEmpty,
      );
    });

    test('TextButton with Text child is labeled', () async {
      final tree = await _buildTree('''
        TextButton(
          onPressed: () {},
          child: const Text('Skip'),
        )
      ''');

      expect(tree.root.labelGuarantee, isNot(LabelGuarantee.none));
    });

    test('ElevatedButton.icon with label is labeled', () async {
      final tree = await _buildTree('''
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon('save'),
          label: const Text('Save entry'),
        )
      ''');

      expect(tree.root.labelGuarantee, isNot(LabelGuarantee.none));
    });

    test('Conditional child still counts as label source', () async {
      final tree = await _buildTree('''
        ElevatedButton(
          onPressed: purchasePending ? null : () {},
          child: purchasePending
              ? const SizedBox(width: 20, height: 20)
              : const Text('Test purchase'),
        )
      ''');

      expect(tree.root.labelGuarantee, isNot(LabelGuarantee.none));
    });

    test('Semantics parent supplies label to IconButton', () async {
      final tree = await _buildTree('''
        Semantics(
          label: 'More information',
          child: ExcludeSemantics(
            child: IconButton(
              icon: const Icon('info'),
              onPressed: () {},
            ),
          ),
        )
      ''');

      expect(A01UnlabeledInteractive.checkTree(tree), isEmpty);
    });

    test('IconButton without any label is still flagged', () async {
      final tree = await _buildTree('''
        IconButton(
          icon: const Icon('info'),
          onPressed: () {},
        )
      ''');

      final violations = A01UnlabeledInteractive.checkTree(tree);
      expect(violations, hasLength(1));
    });

    test('Icon semanticLabel counts as label', () async {
      final tree = await _buildTree('''
        FloatingActionButton(
          onPressed: () {},
          child: const Icon('add', semanticLabel: 'Create reminder'),
        )
      ''');

      expect(tree.root.labelGuarantee, isNot(LabelGuarantee.none));
    });

    test('Tooltip provided via identifier is treated as dynamic label',
        () async {
      final tree = await _buildTree(
        '''
        IconButton(
          icon: const Icon('info'),
          tooltip: infoTooltip,
          onPressed: () {},
        )
        ''',
        extraDeclarations: "const infoTooltip = 'About meditations';",
      );

      expect(tree.root.labelGuarantee, isNot(LabelGuarantee.none));
    });

    test('IconButton tooltip provided via function does not trigger A01',
        () async {
      final tree = await _buildTree(
        '''
        IconButton(
          icon: const Icon('info'),
          tooltip: buildTooltip('reminder'),
          onPressed: () {},
        )
        ''',
        extraDeclarations: '''
String buildTooltip(String entity) => 'Create ' + entity;
''',
      );

      expect(A01UnlabeledInteractive.checkTree(tree), isEmpty);
    });

    test('FilledButton.icon with localized label is accepted', () async {
      final tree = await _buildTree(
        '''
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon('add'),
          label: Text(buildLabel()),
        )
        ''',
        extraDeclarations: '''
String buildLabel() => 'Add reminder';
''',
      );

      expect(A01UnlabeledInteractive.checkTree(tree), isEmpty);
    });

    test(
        'Semantics wrappers that only add state inherit tooltip labels from children',
        () async {
      final tree = await _buildTree('''
        Semantics(
          toggled: true,
          child: IconButton(
            icon: const Icon('timeline'),
            tooltip: 'Timeline grouping',
            onPressed: () {},
          ),
        )
      ''');

      expect(A01UnlabeledInteractive.checkTree(tree), isEmpty);
    });
  });
}

Future<SemanticTree> _buildTree(
  String widgetSource, {
  String extraDeclarations = '',
}) async {
  final tempDir = await Directory.systemTemp.createTemp('a11y_semantics_');
  try {
    final filePath = p.join(tempDir.path, 'widget.dart');
    final content = '''
$_widgetStubs
$extraDeclarations

Widget buildWidget(bool purchasePending) {
  return $widgetSource;
}
''';

    await File(filePath).writeAsString(content);

    final collection = AnalysisContextCollection(includedPaths: [filePath]);
    final context = collection.contextFor(filePath);
    final result = await context.currentSession.getResolvedUnit(filePath);
    if (result is! ResolvedUnitResult) {
      fail('Unable to resolve temporary file for test.');
    }

    final builder = SemanticIrBuilder(
      unit: result,
      knownSemantics: KnownSemanticsRepository(),
    );

    final buildFunction = result.unit.declarations
        .whereType<FunctionDeclaration>()
        .firstWhere((fn) => fn.name.lexeme == 'buildWidget');
    final body = buildFunction.functionExpression.body as BlockFunctionBody;
    final returnStatement =
        body.block.statements.whereType<ReturnStatement>().first;
    final expression = returnStatement.expression;
    final tree = builder.buildForExpression(expression);
    if (tree == null) {
      fail('Failed to build semantic tree for: $widgetSource');
    }
    return tree;
  } finally {
    await tempDir.delete(recursive: true);
  }
}

const _widgetStubs = '''
typedef VoidCallback = void Function();

class Widget {}

class Icon extends Widget {
  const Icon(this.name, {String? semanticLabel});
  final String name;
}

class Text extends Widget {
  const Text(String data);
}

class SizedBox extends Widget {
  const SizedBox({double? width, double? height});
}

class IconButton extends Widget {
  const IconButton({
    required Widget icon,
    String? tooltip,
    VoidCallback? onPressed,
  });
}

class FloatingActionButton extends Widget {
  const FloatingActionButton({
    required Widget child,
    VoidCallback? onPressed,
    String? tooltip,
  });
  const FloatingActionButton.extended({
    required Widget icon,
    required Widget label,
    VoidCallback? onPressed,
  });
}

class ElevatedButton extends Widget {
  const ElevatedButton({
    required Widget child,
    VoidCallback? onPressed,
  });

  const ElevatedButton.icon({
    required Widget icon,
    required Widget label,
    VoidCallback? onPressed,
  });
}

class TextButton extends Widget {
  const TextButton({
    required Widget child,
    VoidCallback? onPressed,
  });
}

class FilledButton extends Widget {
  const FilledButton({
    required Widget child,
    VoidCallback? onPressed,
  });

  const FilledButton.icon({
    required Widget icon,
    required Widget label,
    VoidCallback? onPressed,
  });
}

class Semantics extends Widget {
  const Semantics({
    String? label,
    bool? toggled,
    bool? button,
    required Widget child,
  });
}

class ExcludeSemantics extends Widget {
  const ExcludeSemantics({
    required Widget child,
  });
}
''';
