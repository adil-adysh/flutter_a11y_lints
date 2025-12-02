import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_a11y_lints/src/pipeline/semantic_ir_builder.dart';
import 'package:flutter_a11y_lints/src/semantics/known_semantics.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_tree.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Future<SemanticTree> buildTestSemanticTree(
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

SemanticTree buildManualTree(SemanticNode root) => SemanticTree.fromRoot(root);

SemanticNode makeSemanticNode({
  String widgetType = 'TestWidget',
  AstNode? astNode,
  Uri? fileUri,
  int offset = 0,
  int length = 0,
  SemanticRole role = SemanticRole.button,
  ControlKind controlKind = ControlKind.iconButton,
  bool isFocusable = true,
  bool isEnabled = true,
  bool hasTap = true,
  bool hasLongPress = false,
  bool hasIncrease = false,
  bool hasDecrease = false,
  bool isToggled = false,
  bool isChecked = false,
  bool mergesDescendants = false,
  bool excludesDescendants = false,
  bool blocksBehind = false,
  String? label,
  LabelGuarantee labelGuarantee = LabelGuarantee.none,
  LabelSource labelSource = LabelSource.none,
  String? explicitChildLabel,
  List<SemanticNode> children = const [],
  int? branchGroupId,
  int? branchValue,
}) {
  final nodeAst = astNode ?? _dummyAstNode;
  return SemanticNode(
    widgetType: widgetType,
    astNode: nodeAst,
    fileUri: fileUri ?? Uri.parse('file:///test.dart'),
    offset: offset,
    length: length,
    role: role,
    controlKind: controlKind,
    isFocusable: isFocusable,
    isEnabled: isEnabled,
    hasTap: hasTap,
    hasLongPress: hasLongPress,
    hasIncrease: hasIncrease,
    hasDecrease: hasDecrease,
    isToggled: isToggled,
    isChecked: isChecked,
    mergesDescendants: mergesDescendants,
    excludesDescendants: excludesDescendants,
    blocksBehind: blocksBehind,
    label: label,
    labelGuarantee: labelGuarantee,
    labelSource: labelSource,
    explicitChildLabel: explicitChildLabel,
    children: children,
    branchGroupId: branchGroupId,
    branchValue: branchValue,
  );
}

final AstNode _dummyAstNode = () {
  final unit = parseString(content: 'Widget build() => const SizedBox();').unit;
  final function = unit.declarations.whereType<FunctionDeclaration>().first;
  final body = function.functionExpression.body as ExpressionFunctionBody;
  return body.expression;
}();

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

class Row extends Widget {
  const Row({required List<Widget> children});
}

class Column extends Widget {
  const Column({required List<Widget> children});
}

class IconButton extends Widget {
  const IconButton({
    required Widget icon,
    String? tooltip,
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

class Semantics extends Widget {
  const Semantics({
    String? label,
    bool? button,
    required Widget child,
  });
}

class ExcludeSemantics extends Widget {
  const ExcludeSemantics({
    required Widget child,
  });
}

class MergeSemantics extends Widget {
  const MergeSemantics({
    required Widget child,
  });
}
''';
