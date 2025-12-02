import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils/ast_utils.dart';
import '../utils/flutter_imports.dart';
import '../utils/type_utils.dart';

class LabelNonTextControls extends DartLintRule {
  const LabelNonTextControls() : super(code: _code);

  static const _code = LintCode(
    name: 'flutter_a11y_label_non_text_controls',
    problemMessage:
        'Interactive controls that don’t have visible text must have an accessible label.',
    correctionMessage: 'Try adding a tooltip or a Semantics label.',
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
      if (type == null) return;

      final isInteractive = isIconButton(type) ||
          isMaterialButton(type) ||
          hasCallbackArg(node, 'onTap') ||
          hasCallbackArg(node, 'onPressed') ||
          hasCallbackArg(node, 'onLongPress');

      if (!isInteractive) return;

      if (hasTextChild(node)) return;

      if (isIconButton(type) ||
          isType(type, 'flutter', 'FloatingActionButton')) {
        final tooltip = getStringLiteralArg(node, 'tooltip');
        if (tooltip == null || tooltip.isEmpty) {
          reporter.atNode(node, _code);
        }
        return;
      }

      final parent = node.parent;
      if (parent is! InstanceCreationExpression ||
          !isSemantics(parent.staticType)) {
        reporter.atNode(node, _code);
      }
    });
  }
}
