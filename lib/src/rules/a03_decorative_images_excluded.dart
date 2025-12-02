import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils/ast_utils.dart';
import '../utils/flutter_imports.dart';
import '../utils/type_utils.dart';

class DecorativeImagesExcluded extends DartLintRule {
  const DecorativeImagesExcluded() : super(code: _code);

  static const _code = LintCode(
    name: 'flutter_a11y_decorative_images_excluded',
    problemMessage: 'Decorative images should be excluded from semantics.',
    correctionMessage: 'Try adding excludeFromSemantics: true to the Image.',
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
      if (type == null || !isImage(type)) return;

      final semanticLabel = getStringLiteralArg(node, 'semanticLabel');
      if (semanticLabel != null && semanticLabel.isNotEmpty) return;

      final excludeFromSemantics = getNamedArg(node, 'excludeFromSemantics');
      if (excludeFromSemantics != null) return;

      final parent = node.parent?.parent?.parent;
      if (parent is InstanceCreationExpression) {
        final parentType = parent.staticType;
        if (parentType != null && isType(parentType, 'flutter', 'ListTile')) {
          final leading = getNamedArg(parent, 'leading');
          if (leading == node) {
            reporter.atNode(node, _code);
          }
        }
      }
    });
  }
}
