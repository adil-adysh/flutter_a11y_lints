import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../pipeline/semantic_ir_builder.dart';
import '../semantics/known_semantics.dart';
import '../semantics/semantic_node.dart';
import '../semantics/semantic_tree.dart';
import '../utils/flutter_utils.dart';
import '../utils/method_utils.dart';

class UnlabeledInteractiveControlsRule extends DartLintRule {
  const UnlabeledInteractiveControlsRule() : super(code: _code);

  static const _code = LintCode(
    name: 'semantic_ir_unlabeled_interactive',
    problemMessage: 'Interactive controls must expose an accessible label.',
    correctionMessage: 'Add a tooltip, Text child, or Semantics label.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Smoke test - report at file start to verify wiring
    context.registry.addCompilationUnit((node) {
      print('[A01] Smoke test: reporting at offset 0');
      reporter.reportErrorForOffset(
        _code,
        0,
        1,
      );
    });

    context.addPostRunCallback(() async {
      final unit = await resolver.getResolvedUnitResult();
      if (!fileUsesFlutter(unit)) return;
      
      final repo = KnownSemanticsRepository();
      final irBuilder = SemanticIrBuilder(unit: unit, knownSemantics: repo);
      
      // Find all build methods
      final buildMethods = <MethodDeclaration>[];
      unit.unit.visitChildren(_BuildMethodCollector(buildMethods));
      
      for (final method in buildMethods) {
        final expression = extractBuildBodyExpression(method);
        if (expression == null) continue;
        final tree = irBuilder.buildForExpression(expression);
        if (tree == null) continue;
        _runRule(tree, reporter);
      }
    });
  }

  void _runRule(SemanticTree tree, ErrorReporter reporter) {
    for (final node in tree.accessibilityFocusNodes) {
      if (!_isInteractive(node)) continue;
      if (!_isPrimaryControl(node)) continue;
      final hasLabel =
          node.effectiveLabel != null || node.labelGuarantee != LabelGuarantee.none;
      
      if (hasLabel) continue;

      print('[A01] REPORTING ERROR for ${node.controlKind} at ${node.astNode.offset}');
      reporter.reportErrorForOffset(
        _code,
        node.astNode.offset,
        node.astNode.length,
      );
    }
  }

  bool _isInteractive(SemanticNode node) =>
      (node.hasTap || node.hasIncrease || node.hasDecrease) && node.isEnabled;

  bool _isPrimaryControl(SemanticNode node) => _targetControls.contains(node.controlKind);
}

const _targetControls = {
  ControlKind.iconButton,
  ControlKind.elevatedButton,
  ControlKind.textButton,
  ControlKind.floatingActionButton,
};

class _BuildMethodCollector extends RecursiveAstVisitor<void> {
  _BuildMethodCollector(this.methods);
  
  final List<MethodDeclaration> methods;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme == 'build') {
      methods.add(node);
    }
    super.visitMethodDeclaration(node);
  }
}
