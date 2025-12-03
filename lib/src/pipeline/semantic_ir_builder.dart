import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';

import '../semantics/semantic_builder.dart';
import '../semantics/semantic_context.dart';
import '../semantics/semantic_tree.dart';
import '../semantics/known_semantics.dart';
import '../widget_tree/widget_tree_builder.dart';

class SemanticIrBuilder {
  SemanticIrBuilder({
    required this.unit,
    required this.knownSemantics,
  }) : _globalContext = GlobalSemanticContext(
          knownSemantics: knownSemantics,
          typeProvider: unit.typeProvider,
        );

  // Note: `SemanticIrBuilder` is a thin orchestration layer used by the
  // CLI and tests. It composes the `WidgetTreeBuilder` (AST → WidgetNode)
  // with `SemanticBuilder` (WidgetNode → SemanticNode) and then annotates
  // the resulting tree via `SemanticTree.fromRoot`.
  //
  // Important behaviours to be aware of:
  // - A single `GlobalSemanticContext` is created per `SemanticIrBuilder`
  //   instance; it caches `SemanticSummary`s for custom widgets which
  //   prevents re-analysis and protects against recursive widget graphs.
  // - The builder assumes `unit` is a resolved `ResolvedUnitResult` and
  //   therefore relies on `unit.typeProvider` for type resolution.

  final ResolvedUnitResult unit;
  final KnownSemanticsRepository knownSemantics;
  final GlobalSemanticContext _globalContext;

  SemanticTree? buildForExpression(Expression? expression) {
    final widgetNode = WidgetTreeBuilder(unit).fromExpression(expression);
    if (widgetNode == null) return null;
    final semanticNode = SemanticBuilder(
      unit: unit,
      globalContext: _globalContext,
    ).build(widgetNode);
    if (semanticNode == null) return null;
    return SemanticTree.fromRoot(semanticNode);
  }
}
