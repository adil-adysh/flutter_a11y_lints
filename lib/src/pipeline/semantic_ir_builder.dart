import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';

import '../facts/fact_store.dart';
import '../semantics/semantic_builder.dart';
import '../semantics/semantic_context.dart';
import '../semantics/semantic_tree.dart';
import '../semantics/known_semantics.dart';
import '../widget_tree/widget_tree_builder.dart';
import '../widget_tree/widget_node.dart';

class SemanticIrBuilder {
  SemanticIrBuilder({
    required this.unit,
    required this.knownSemantics,
  }) : _globalContext = GlobalSemanticContext(
          knownSemantics: knownSemantics,
          typeProvider: unit.typeProvider,
          // Provide a resolver that can map an `InterfaceType` back to the
          // `ResolvedUnitResult` that defines the type. This lets the
          // `GlobalSemanticContext` fetch and analyze the widget's
          // `build()` implementation when available.
          resolver: (InterfaceType? t) async {
            try {
              final path = _sourcePathFor(t);
              if (path == null) return null;
              final resolved = await unit.session.getResolvedUnit(path);
              return resolved as ResolvedUnitResult;
            } catch (_) {
              return null;
            }
          },
        );

  // Note: `SemanticIrBuilder` is a thin orchestration layer used by the
  // CLI and tests. It composes the `WidgetTreeBuilder` (AST → WidgetNode)
  // with `SemanticBuilder` (WidgetNode → SemanticNode) and then annotates
  // the resulting semantic forest via `SemanticTree.fromRoots`.
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
    final widgetNode = WidgetTreeBuilder(
      unit,
      constEval: (expr) => _globalContext.evalBoolInUnit(expr, unit),
    ).fromExpression(expression);
    if (widgetNode == null) return null;
    final semanticRoots = SemanticBuilder(
      unit: unit,
      globalContext: _globalContext,
    ).buildAll(widgetNode);
    if (semanticRoots.isEmpty) return null;
    return SemanticTree.fromRoots(semanticRoots);
  }

  /// Builds Semantic IR after expanding source-resolved custom widgets.
  ///
  /// Expansion is deliberately separate from [buildForExpression] to retain
  /// compatibility for synchronous callers. Callers that need conservative
  /// custom-widget facts must use this method.
  Future<SemanticTree?> buildForExpressionAsync(Expression? expression) async {
    final widgetNode = WidgetTreeBuilder(
      unit,
      constEval: (expr) => _globalContext.evalBoolInUnit(expr, unit),
    ).fromExpression(expression);
    if (widgetNode == null) return null;

    final allocator = _BranchGroupAllocator.fromTree(widgetNode);
    final expanded = await _CustomWidgetExpander(
      rootUnit: unit,
      knownSemantics: knownSemantics,
      globalContext: _globalContext,
      branchGroups: allocator,
    ).expand(widgetNode);
    final semanticRoots = SemanticBuilder(
      unit: unit,
      globalContext: _globalContext,
    ).buildAll(expanded);
    if (semanticRoots.isEmpty) return null;
    return SemanticTree.fromRoots(semanticRoots);
  }
}

class _CustomWidgetExpander {
  _CustomWidgetExpander({
    required this.rootUnit,
    required this.knownSemantics,
    required this.globalContext,
    required this.branchGroups,
  });

  final ResolvedUnitResult rootUnit;
  final KnownSemanticsRepository knownSemantics;
  final GlobalSemanticContext globalContext;
  final _BranchGroupAllocator branchGroups;
  final Set<String> _inProgress = <String>{};

  Future<WidgetNode> expand(WidgetNode node) async {
    final expandedSlots = <String, WidgetNode?>{};
    for (final entry in node.slots.entries) {
      expandedSlots[entry.key] =
          entry.value == null ? null : await expand(entry.value!);
    }
    final expandedChildren = <WidgetNode>[];
    for (final child in node.children) {
      expandedChildren.add(await expand(child));
    }
    final expandedBranches = <WidgetNode>[];
    for (final branch in node.branchChildren) {
      expandedBranches.add(await expand(branch));
    }
    final current = node.copyWith(
      slots: expandedSlots,
      children: expandedChildren,
      branchChildren: expandedBranches,
    );

    if (current.nodeType != WidgetNodeType.standard ||
        knownSemantics[current.widgetType] != null) {
      return current;
    }
    final creation = current.astNode;
    if (creation is! InstanceCreationExpression) return current;
    final type = creation.staticType;
    if (type is! InterfaceType) return current;
    final key = _typeKey(type);
    if (!_inProgress.add(key)) return current;
    try {
      final source = await _resolveSource(type);
      if (source == null) return current;
      final buildExpression =
          _findSingleBuildExpression(source, type.element.name);
      if (buildExpression == null) return current;
      final implementation = WidgetTreeBuilder(
        source,
        constEval: (expr) => globalContext.evalBoolInUnit(expr, source),
      ).fromExpression(buildExpression);
      if (implementation == null ||
          !_hasCompleteStructuralChildren(implementation)) {
        return current;
      }
      final rebased = _rebaseBranchPaths(implementation, current.branchPath);
      // Keep [key] in the recursion guard until the replacement subtree has
      // been completely expanded. A bare `return expand(...)` runs `finally`
      // before that Future completes and therefore permits indirect cycles.
      return await expand(rebased);
    } finally {
      _inProgress.remove(key);
    }
  }

  Future<ResolvedUnitResult?> _resolveSource(InterfaceType type) async {
    try {
      final path = _sourcePathFor(type);
      if (path == null) return null;
      final result = await rootUnit.session.getResolvedUnit(path);
      return result is ResolvedUnitResult ? result : null;
    } catch (_) {
      return null;
    }
  }

  Expression? _findSingleBuildExpression(
    ResolvedUnitResult source,
    String? className,
  ) {
    if (className == null) return null;
    final declarations =
        source.unit.declarations.whereType<ClassDeclaration>().toList();
    final directOwners = declarations.where(
      (declaration) => declaration.name.lexeme == className,
    );
    final owner = directOwners.any((declaration) =>
            declaration.members.whereType<MethodDeclaration>().any(
                  (method) => method.name.lexeme == 'build',
                ))
        ? directOwners
        : declarations.where(
            (declaration) => _isStateFor(declaration, className),
          );
    final methods = <MethodDeclaration>[
      for (final declaration in owner)
        ...declaration.members.whereType<MethodDeclaration>().where(
              (method) => method.name.lexeme == 'build',
            ),
    ];
    if (methods.length != 1) return null;
    final body = methods.single.body;
    if (body is ExpressionFunctionBody) return body.expression;
    if (body is! BlockFunctionBody) return null;
    final statements = body.block.statements;
    if (statements.length != 1 || statements.single is! ReturnStatement) {
      return null;
    }
    return (statements.single as ReturnStatement).expression;
  }

  /// Accept the common, directly declared `State<CustomWidget>` pattern only.
  /// Other state wiring is deliberately unresolved rather than guessed.
  bool _isStateFor(ClassDeclaration declaration, String widgetClassName) {
    final superclass = declaration.extendsClause?.superclass.toSource();
    return superclass == 'State<$widgetClassName>';
  }

  bool _hasCompleteStructuralChildren(WidgetNode node) {
    final children = node.props['children'];
    if (children != null && !_hasCompleteChildrenArgument(children)) {
      return false;
    }
    for (final entry in node.slots.entries) {
      final source = node.props[entry.key];
      if (entry.value == null && _mightEvaluateToWidget(source)) {
        return false;
      }
      if (entry.value != null &&
          !_hasCompleteStructuralChildren(entry.value!)) {
        return false;
      }
    }
    return node.children.every(_hasCompleteStructuralChildren) &&
        node.branchChildren.every(_hasCompleteStructuralChildren);
  }

  /// The widget-tree builder intentionally does not invent list entries from
  /// identifiers, spreads, or loops. Reject those forms during expansion so
  /// a custom implementation cannot appear complete after losing children.
  bool _hasCompleteChildrenArgument(Expression expression) {
    if (expression is! ListLiteral) return false;
    return expression.elements.every(_isCompleteChildElement);
  }

  bool _isCompleteChildElement(CollectionElement element) {
    if (element is Expression) {
      return element is InstanceCreationExpression ||
          (element is ConditionalExpression &&
              _isCompleteWidgetExpression(element.thenExpression) &&
              _isCompleteWidgetExpression(element.elseExpression));
    }
    if (element is IfElement) {
      return _isCompleteChildElement(element.thenElement) &&
          (element.elseElement == null ||
              _isCompleteChildElement(element.elseElement!));
    }
    // Spread and for elements introduce runtime cardinality/data flow that
    // this source-only expansion cannot prove.
    return false;
  }

  bool _isCompleteWidgetExpression(Expression expression) =>
      expression is InstanceCreationExpression ||
      (expression is ConditionalExpression &&
          _isCompleteWidgetExpression(expression.thenExpression) &&
          _isCompleteWidgetExpression(expression.elseExpression));

  /// A non-widget constructor argument such as `Semantics.label` can share a
  /// name with a structural slot. Only reject expansion when the source value
  /// might actually contribute an unresolved widget subtree.
  bool _mightEvaluateToWidget(Expression? expression) {
    if (expression == null || expression is NullLiteral) return false;
    final type = expression.staticType;
    if (type is! InterfaceType) return true;
    return type.element.name == 'Widget' ||
        type.allSupertypes
            .any((supertype) => supertype.element.name == 'Widget');
  }

  WidgetNode _rebaseBranchPaths(WidgetNode node, BranchPath outerPath) {
    final localGroups = <int>{};
    void collect(WidgetNode candidate) {
      for (final constraint in candidate.branchPath.constraints) {
        localGroups.add(constraint.group);
      }
      for (final child in candidate.children) {
        collect(child);
      }
      for (final child in candidate.slots.values.whereType<WidgetNode>()) {
        collect(child);
      }
      for (final branch in candidate.branchChildren) {
        collect(branch);
      }
    }

    collect(node);
    final remapped = <int, int>{
      for (final group in localGroups) group: branchGroups.allocate(),
    };

    WidgetNode rebase(WidgetNode candidate) {
      final path = BranchPath([
        ...outerPath.constraints,
        for (final constraint in candidate.branchPath.constraints)
          Branch(remapped[constraint.group]!, constraint.value),
      ]);
      final scalar = path.constraints.isEmpty ? null : path.constraints.last;
      return candidate.copyWith(
        branchGroupId: scalar?.group,
        branchValue: scalar?.value,
        branchPath: path,
        evidenceProvenance: FactProvenance.derived,
        slots: {
          for (final entry in candidate.slots.entries)
            entry.key: entry.value == null ? null : rebase(entry.value!),
        },
        children: [for (final child in candidate.children) rebase(child)],
        branchChildren: [
          for (final child in candidate.branchChildren) rebase(child),
        ],
      );
    }

    return rebase(node);
  }

  String _typeKey(InterfaceType type) =>
      '${type.element.library.uri}::${type.element.name}';
}

/// Analyzer 9 stores a declaration's source on its library fragment rather
/// than directly on the composed element. Keeping this lookup in one place
/// also preserves compatibility with older analyzer element models.
String? _sourcePathFor(InterfaceType? type) {
  final element = type?.element;
  if (element == null) return null;
  try {
    return element.firstFragment.libraryFragment.source.fullName;
  } catch (_) {
    // Older analyzer models expose `source` directly on the element.
  }

  try {
    return (element as dynamic).source?.fullName as String?;
  } catch (_) {
    return null;
  }
}

class _BranchGroupAllocator {
  _BranchGroupAllocator(this._next);

  factory _BranchGroupAllocator.fromTree(WidgetNode root) {
    var maximum = -1;
    void visit(WidgetNode node) {
      for (final constraint in node.branchPath.constraints) {
        if (constraint.group > maximum) maximum = constraint.group;
      }
      for (final child in node.children) {
        visit(child);
      }
      for (final child in node.slots.values.whereType<WidgetNode>()) {
        visit(child);
      }
      for (final child in node.branchChildren) {
        visit(child);
      }
    }

    visit(root);
    return _BranchGroupAllocator(maximum + 1);
  }

  int _next;
  int allocate() => _next++;
}
