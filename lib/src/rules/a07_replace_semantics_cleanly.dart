import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils/ast_utils.dart';
import '../utils/flutter_imports.dart';
import '../utils/type_utils.dart';

class ReplaceSemanticsCleanly extends DartLintRule {
  const ReplaceSemanticsCleanly() : super(code: _code);

  static const _code = LintCode(
    name: 'flutter_a11y_clean_semantics_replacement',
    problemMessage:
        'When a parent Semantics widget provides a label, the children should be excluded from semantics.',
    correctionMessage:
        'Try wrapping the child with an ExcludeSemantics widget.',
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

      final label = getStringLiteralArg(node, 'label');
      if (label == null || label.isEmpty) return;

      final child = getNamedArg(node, 'child');
      if (child == null) return;

      final visitor = _ChildVisitor();
      child.accept(visitor);

      if (visitor.hasText || visitor.hasSemantics) {
        reporter.atNode(node, _code);
      }
    });
  }
}

class _ChildVisitor extends RecursiveAstVisitor<void> {
  bool hasText = false;
  bool hasSemantics = false;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final type = node.staticType;
    if (type != null) {
      if (isType(type, 'flutter', 'Text')) {
        hasText = true;
      } else if (isSemantics(type)) {
        hasSemantics = true;
      } else if (isType(type, 'flutter', 'ExcludeSemantics')) {
        // Stop traversing down this branch
        return;
      }
    }
    super.visitInstanceCreationExpression(node);
  }
}
