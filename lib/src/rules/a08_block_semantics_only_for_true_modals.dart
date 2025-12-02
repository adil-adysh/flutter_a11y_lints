import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils/flutter_imports.dart';
import '../utils/type_utils.dart';

class BlockSemanticsOnlyForTrueModals extends DartLintRule {
  const BlockSemanticsOnlyForTrueModals() : super(code: _code);

  static const _code = LintCode(
    name: 'flutter_a11y_block_semantics_only_for_modals',
    problemMessage:
        'BlockSemantics should only be used for blocking background content for modals/overlays.',
    correctionMessage:
        'Consider removing BlockSemantics if this is not a modal.',
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
      if (type == null || !isType(type, 'flutter', 'BlockSemantics')) return;

      var parent = node.parent;
      var isModal = false;
      while (parent != null) {
        if (parent is InstanceCreationExpression) {
          final parentType = parent.staticType;
          if (parentType != null) {
            if (isType(parentType, 'flutter', 'Dialog') ||
                isType(parentType, 'flutter', 'AlertDialog') ||
                isType(parentType, 'flutter', 'ModalBottomSheet') ||
                isType(parentType, 'flutter', 'Drawer')) {
              isModal = true;
              break;
            }
          }
        }
        parent = parent.parent;
      }

      if (!isModal) {
        reporter.atNode(node, _code);
      }
    });
  }
}
