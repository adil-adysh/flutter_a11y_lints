import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';

import '../semantics/semantic_builder.dart';
import '../semantics/semantic_tree.dart';
import '../semantics/known_semantics.dart';
import '../widget_tree/widget_tree_builder.dart';

class SemanticIrBuilder {
  SemanticIrBuilder({
    required this.unit,
    required this.knownSemantics,
  });

  final ResolvedUnitResult unit;
  final KnownSemanticsRepository knownSemantics;

  SemanticTree? buildForExpression(Expression? expression) {
    final widgetNode = WidgetTreeBuilder(unit).fromExpression(expression);
    if (widgetNode == null) return null;
    final semanticNode = SemanticBuilder(
      unit: unit,
      knownSemantics: knownSemantics,
    ).build(widgetNode);
    if (semanticNode == null) return null;
    return SemanticTree.fromRoot(semanticNode);
  }
}
