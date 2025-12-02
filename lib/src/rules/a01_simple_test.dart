import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class SimpleIconButtonTestRule extends DartLintRule {
  const SimpleIconButtonTestRule() : super(code: _code);

  static const _code = LintCode(
    name: 'test_simple_iconbutton',
    problemMessage: 'Test: IconButton found',
    correctionMessage: 'This is just a test',
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final type = node.staticType;
      if (type == null) return;

      final typeName = type.getDisplayString();

      // Just report every IconButton
      if (typeName.contains('IconButton')) {
        reporter.atNode(node, _code);
      }
    });
  }
}
