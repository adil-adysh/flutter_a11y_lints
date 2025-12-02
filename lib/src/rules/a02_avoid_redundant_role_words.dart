import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils/flutter_imports.dart';
import '../utils/type_utils.dart';

class AvoidRedundantRoleWords extends DartLintRule {
  const AvoidRedundantRoleWords() : super(code: _code);

  static const _code = LintCode(
    name: 'flutter_a11y_avoid_redundant_role_words',
    problemMessage: 'Avoid using redundant role words in labels.',
    correctionMessage: 'The role is already announced by the widget.',
    errorSeverity: ErrorSeverity.WARNING,
  );

  static const redundantWords = [
    'button',
    'btn',
    'tab',
    'selected',
    'checkbox',
    'switch',
  ];

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.addPostRunCallback(() async {
      final unit = await resolver.getResolvedUnitResult();
      if (!fileUsesFlutter(unit)) return;
    });

    void checkLiteral(StringLiteral literal) {
      final text = literal.stringValue?.toLowerCase() ?? '';
      for (final word in redundantWords) {
        if (text.contains(word)) {
          reporter.atNode(literal, _code);
          return;
        }
      }
    }

    context.registry.addInstanceCreationExpression((node) {
      final type = node.staticType;
      if (type == null) return;

      if (isIconButton(type)) {
        final tooltipArg = node.argumentList.arguments
            .whereType<NamedExpression>()
            .where((arg) => arg.name.label.name == 'tooltip')
            .firstOrNull;
        if (tooltipArg?.expression case StringLiteral tooltip) {
          checkLiteral(tooltip);
        }
      } else if (isSemantics(type)) {
        final labelArg = node.argumentList.arguments
            .whereType<NamedExpression>()
            .where((arg) => arg.name.label.name == 'label')
            .firstOrNull;
        if (labelArg?.expression case StringLiteral label) {
          checkLiteral(label);
        }
      }
    });

    context.registry.addSimpleStringLiteral((node) {
      // Check for Text widgets inside buttons
      final parent = node.parent;
      if (parent is ArgumentList) {
        final grandParent = parent.parent;
        if (grandParent is InstanceCreationExpression) {
          final type = grandParent.staticType;
          if (type != null && isMaterialButton(type)) {
            checkLiteral(node);
          }
        }
      }
    });
  }
}
