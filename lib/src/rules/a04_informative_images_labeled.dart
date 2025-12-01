import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils/ast_utils.dart';
import '../utils/flutter_imports.dart';
import '../utils/type_utils.dart';

class InformativeImagesLabeled extends DartLintRule {
  const InformativeImagesLabeled() : super(code: _code);

  static const _code = LintCode(
    name: 'flutter_a11y_informative_images_labeled',
    problemMessage: 'Informative images must have a semantic label.',
    correctionMessage: 'Try adding a semanticLabel to the Image.',
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
      if (type == null || !isImage(type)) return;

      final parent = node.parent;
      final grandParent = parent?.parent;
      bool isTappable = false;
      if (grandParent is InstanceCreationExpression) {
        final parentType = grandParent.staticType;
        if (parentType != null) {
          isTappable = hasCallbackArg(grandParent, 'onTap') ||
              hasCallbackArg(grandParent, 'onPressed') ||
              hasCallbackArg(grandParent, 'onLongPress');
        }
      }

      if (!isTappable) return;

      final semanticLabel = getStringLiteralArg(node, 'semanticLabel');
      if (semanticLabel == null || semanticLabel.isEmpty) {
        // Check for a Semantics wrapper
        final greatGrandParent = grandParent?.parent;
        if (greatGrandParent is! InstanceCreationExpression ||
            !isSemantics(greatGrandParent.staticType)) {
          reporter.atNode(node, _code);
        }
      }
    });
  }
}






