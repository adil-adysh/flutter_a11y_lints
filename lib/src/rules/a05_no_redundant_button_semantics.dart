import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils/ast_utils.dart';
import '../utils/flutter_imports.dart';
import '../utils/type_utils.dart';

class NoRedundantButtonSemantics extends DartLintRule {
  const NoRedundantButtonSemantics() : super(code: _code);

  static const _code = LintCode(
    name: 'flutter_a11y_no_button_semantics',
    problemMessage:
        'Avoid wrapping Material buttons with a Semantics widget that has the button property set to true.',
    correctionMessage:
        'Remove the button: true property from the Semantics widget, or remove the Semantics widget entirely.',
    errorSeverity: ErrorSeverity.WARNING,
  );

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

    context.registry.addInstanceCreationExpression((node) {
      final type = node.staticType;
      if (type == null || !isSemantics(type)) return;

      final isButton = getNamedArg(node, 'button');
      final onTap = getNamedArg(node, 'onTap');

      if ((isButton is BooleanLiteral && isButton.value) || onTap != null) {
        final child = getNamedArg(node, 'child');
        if (child is InstanceCreationExpression) {
          final childType = child.staticType;
          if (childType != null &&
              (isMaterialButton(childType) || isIconButton(childType))) {
            reporter.atNode(node, _code);
          }
        }
      }
    });
  }
}
