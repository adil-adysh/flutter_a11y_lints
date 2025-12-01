import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils/flutter_imports.dart';
import '../utils/type_utils.dart';

class MergeMultiPartSingleConcept extends DartLintRule {
  const MergeMultiPartSingleConcept() : super(code: _code);

  static const _code = LintCode(
    name: 'flutter_a11y_merge_composite_values',
    problemMessage:
        'A multi-part value that represents a single concept should be merged into a single semantic node.',
    correctionMessage: 'Try wrapping the widget with a MergeSemantics widget.',
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.addPostRunCallback(() async {
      final unit = await resolver.getResolvedUnitResult();
      if (!fileUsesFlutter(unit)) return;
    });

    context.registry.addInstanceCreationExpression((node) {      final type = node.staticType;
      if (type == null) return;

      if (!isType(type, 'flutter', 'Row') && !isType(type, 'flutter', 'Wrap')) {
        return;
      }

      final parent = node.parent;
      if (parent is InstanceCreationExpression) {
        final parentType = parent.staticType;
        if (parentType != null && isType(parentType, 'flutter', 'MergeSemantics')) {
          return;
        }
      }

      final children = node.argumentList.arguments
          .where((arg) => arg.staticType?.isDartCoreList ?? false)
          .expand<Expression>((arg) =>
              arg is ListLiteral ? arg.elements.cast<Expression>() : const <Expression>[])
          .toList();

      if (children.length > 1) {
        final hasIcon = children.any((child) =>
            child.staticType != null && isType(child.staticType, 'flutter', 'Icon'));
        final hasText = children.any((child) =>
            child.staticType != null && isType(child.staticType, 'flutter', 'Text'));
        if (hasIcon && hasText) {
          reporter.atNode(node, _code);
        }
      }
    });
  }
}






