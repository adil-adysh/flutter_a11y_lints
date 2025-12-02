import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils/flutter_imports.dart';
import '../utils/type_utils.dart';

class UseIconButtonTooltipParameter extends DartLintRule {
  const UseIconButtonTooltipParameter() : super(code: _code);

  static const _code = LintCode(
    name: 'flutter_a11y_use_iconbutton_tooltip',
    problemMessage:
        'Use the tooltip parameter of IconButton instead of wrapping it with a Tooltip widget.',
    correctionMessage:
        'Try moving the tooltip message to the tooltip parameter of the IconButton.',
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
      if (type == null || !isType(type, 'flutter', 'Tooltip')) return;

      final childArg = node.argumentList.arguments
          .whereType<NamedExpression>()
          .where((arg) => arg.name.label.name == 'child')
          .firstOrNull;

      if (childArg?.expression case InstanceCreationExpression child) {
        final childType = child.staticType;
        if (childType != null && isIconButton(childType)) {
          reporter.atNode(node, _code);
        }
      }
    });
  }
}
