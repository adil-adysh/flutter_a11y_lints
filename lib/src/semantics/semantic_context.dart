import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_provider.dart';

import '../widget_tree/widget_tree_builder.dart';
import 'known_semantics.dart';
import 'semantic_builder.dart';
import 'semantic_node.dart';

/// Summary of a custom widget's semantic behavior.
class SemanticSummary {
  const SemanticSummary({
    required this.widgetType,
    required this.role,
    required this.controlKind,
    required this.isCompositeControl,
    required this.isFocusable,
    required this.hasTap,
    required this.hasLongPress,
    required this.hasIncrease,
    required this.hasDecrease,
    required this.isToggled,
    required this.isChecked,
    required this.mergesDescendants,
    required this.excludesDescendants,
    required this.blocksBehind,
    required this.labelGuarantee,
    required this.primaryLabelSource,
    required this.isSemanticallyTransparent,
  });

  final String widgetType;
  final SemanticRole role;
  final ControlKind controlKind;

  final bool isCompositeControl;
  final bool isFocusable;
  final bool hasTap;
  final bool hasLongPress;
  final bool hasIncrease;
  final bool hasDecrease;
  final bool isToggled;
  final bool isChecked;

  final bool mergesDescendants;
  final bool excludesDescendants;
  final bool blocksBehind;

  final LabelGuarantee labelGuarantee;
  final LabelSource primaryLabelSource;

  /// If true, this widget is treated as a pass-through container unless
  /// a more precise summary indicates otherwise.
  final bool isSemanticallyTransparent;

  factory SemanticSummary.unknown(String widgetType) => SemanticSummary(
        widgetType: widgetType,
        role: SemanticRole.unknown,
        controlKind: ControlKind.none,
        isCompositeControl: false,
        isFocusable: false,
        hasTap: false,
        hasLongPress: false,
        hasIncrease: false,
        hasDecrease: false,
        isToggled: false,
        isChecked: false,
        mergesDescendants: false,
        excludesDescendants: false,
        blocksBehind: false,
        labelGuarantee: LabelGuarantee.none,
        primaryLabelSource: LabelSource.none,
        isSemanticallyTransparent: false,
      );
}

/// Global context shared across semantic builds.
///
/// Holds immutable/global resources used during semantic synthesis:
/// - `knownSemantics`: metadata for built-in widgets
/// - `typeProvider`: analyzer type helpers
///
/// Also caches `SemanticSummary` for widget classes and guards against
/// recursive graphs by degrading to `SemanticSummary.unknown` on cycles.
class GlobalSemanticContext {
  GlobalSemanticContext({
    required this.knownSemantics,
    required this.typeProvider,
    this.resolver,
  });

  final KnownSemanticsRepository knownSemantics;
  final TypeProvider typeProvider;

  /// Async resolver used to obtain a `ResolvedUnitResult` for a given
  /// widget type. Enables inspecting `build()` bodies when source is
  /// available.
  final Future<ResolvedUnitResult?> Function(InterfaceType? widgetType)?
      resolver;

  /// Cache of computed summaries for widget classes, keyed by class name.
  final Map<String, SemanticSummary> _summaryCache = {};

  /// Guard set used to detect recursive computation (WidgetA → WidgetB → WidgetA).
  final Set<String> _summaryInProgress = {};

  /// Return a cached `SemanticSummary` for the given `InterfaceType`, or
  /// compute it if missing. If a cycle is detected during computation,
  /// `SemanticSummary.unknown` is returned to avoid infinite recursion.
  Future<SemanticSummary?> getOrComputeSummary(
    InterfaceType? widgetType,
  ) async {
    final element = widgetType?.element;
    if (element == null) return null;
    final name = element.name;
    if (name == null) return null;

    final cached = _summaryCache[name];
    if (cached != null) return cached;

    if (_summaryInProgress.contains(name)) {
      // Recursive widget graphs: degrade to unknown summary to avoid cycles.
      return SemanticSummary.unknown(name);
    }

    _summaryInProgress.add(name);
    try {
      // 1. Known framework widget: derive summary directly from KnownSemantics.
      final known = knownSemantics[name];
      if (known != null) {
        final summary = SemanticSummary(
          widgetType: name,
          role: known.role,
          controlKind: known.controlKind,
          isCompositeControl: !known.isPureContainer,
          isFocusable: known.isFocusable,
          hasTap: known.hasTap,
          hasLongPress: known.hasLongPress,
          hasIncrease: known.hasIncrease,
          hasDecrease: known.hasDecrease,
          isToggled: known.isToggled,
          isChecked: known.isChecked,
          mergesDescendants: known.mergesDescendants,
          excludesDescendants: known.excludesDescendants,
          blocksBehind: known.blocksBehind,
          labelGuarantee: LabelGuarantee.none,
          primaryLabelSource: LabelSource.none,
          // Pure containers are semantically transparent.
          isSemanticallyTransparent: known.isPureContainer,
        );
        _summaryCache[name] = summary;
        return summary;
      }

      // Precompute supertype names for conservative fallback.
      final supertypeNames = <String>{};
      for (final st in element.allSupertypes) {
        final en = st.element.name;
        if (en != null) supertypeNames.add(en);
      }

      // 2. If a resolver is available, analyze build() to compute a precise summary.
      if (resolver != null) {
        try {
          final unit = await resolver!(widgetType);
          if (unit != null) {
            final summary = _computeSummaryFromResolvedUnit(
              unit: unit,
              className: name,
            );
            if (summary != null) {
              _summaryCache[name] = summary;
              return summary;
            }
          }
        } catch (_) {
          // Ignore resolver failures; fall back conservatively below.
        }
      }

      // 3. Conservative heuristic for custom Flutter widgets:
      // StatelessWidget / StatefulWidget are treated as semantically
      // transparent containers if we cannot inspect their build() bodies.
      if (supertypeNames.contains('StatelessWidget') ||
          supertypeNames.contains('StatefulWidget')) {
        final summary = SemanticSummary(
          widgetType: name,
          role: SemanticRole.unknown,
          controlKind: ControlKind.none,
          isCompositeControl: false,
          isFocusable: false,
          hasTap: false,
          hasLongPress: false,
          hasIncrease: false,
          hasDecrease: false,
          isToggled: false,
          isChecked: false,
          mergesDescendants: false,
          excludesDescendants: false,
          blocksBehind: false,
          labelGuarantee: LabelGuarantee.none,
          primaryLabelSource: LabelSource.none,
          // Assume custom widgets are pass-through until proven otherwise.
          isSemanticallyTransparent: true,
        );
        _summaryCache[name] = summary;
        return summary;
      }

      // 4. Final fallback: unknown summary when behaviour can't be inferred.
      final unknown = SemanticSummary.unknown(name);
      _summaryCache[name] = unknown;
      return unknown;
    } finally {
      _summaryInProgress.remove(name);
    }
  }

  /// Compute a summary from a resolved unit by inspecting the widget's build().
  SemanticSummary? _computeSummaryFromResolvedUnit({
    required ResolvedUnitResult unit,
    required String className,
  }) {
    final decls = unit.unit.declarations;

    // Locate the class declaration with matching name, if present.
    ClassDeclaration? classDecl;
    for (final d in decls) {
      if (d is ClassDeclaration && d.name.lexeme == className) {
        classDecl = d;
        break;
      }
    }

    // First try build() on the widget class itself.
    MethodDeclaration? buildMethod;
    if (classDecl != null) {
      for (final member in classDecl.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'build') {
          buildMethod = member;
          break;
        }
      }
    }

    // StatefulWidget pattern: build() might live on the State subclass.
    if (buildMethod == null) {
      for (final d in decls) {
        if (d is ClassDeclaration) {
          for (final member in d.members) {
            if (member is MethodDeclaration && member.name.lexeme == 'build') {
              buildMethod = member;
              break;
            }
          }
          if (buildMethod != null) break;
        }
      }
    }

    if (buildMethod == null) {
      return null;
    }

    final buildExpr = _findBuildExpression(buildMethod);
    if (buildExpr == null) {
      return null;
    }

    // Quick-path: build() => single InstanceCreationExpression (e.g. IconButton(...)).
    if (buildExpr is InstanceCreationExpression) {
      String? createdName;
      final createdType = buildExpr.staticType;
      if (createdType is InterfaceType) {
        createdName = createdType.element.name;
      }
      createdName ??= buildExpr.constructorName.type.toSource();

      final knownChild = knownSemantics[createdName];
      if (knownChild != null) {
        return SemanticSummary(
          widgetType: className,
          role: knownChild.role,
          controlKind: knownChild.controlKind,
          isCompositeControl: !knownChild.isPureContainer,
          isFocusable: knownChild.isFocusable,
          hasTap: knownChild.hasTap,
          hasLongPress: knownChild.hasLongPress,
          hasIncrease: knownChild.hasIncrease,
          hasDecrease: knownChild.hasDecrease,
          isToggled: knownChild.isToggled,
          isChecked: knownChild.isChecked,
          mergesDescendants: knownChild.mergesDescendants,
          excludesDescendants: knownChild.excludesDescendants,
          blocksBehind: knownChild.blocksBehind,
          labelGuarantee: LabelGuarantee.none,
          primaryLabelSource: LabelSource.none,
          isSemanticallyTransparent: knownChild.isPureContainer,
        );
      }
    }

    // Full path: WidgetNode → SemanticNode using existing builders.
    final treeBuilder = WidgetTreeBuilder(unit);
    final widgetNode = treeBuilder.fromExpression(buildExpr);
    if (widgetNode == null) {
      return null;
    }

    final semanticBuilder = SemanticBuilder(
      unit: unit,
      globalContext: this,
    );
    final semanticRoot =
        semanticBuilder.build(widgetNode, enableHeuristics: true);
    if (semanticRoot == null) {
      return null;
    }

    return SemanticSummary(
      widgetType: className,
      role: semanticRoot.role,
      controlKind: semanticRoot.controlKind,
      isCompositeControl: semanticRoot.isCompositeControl,
      isFocusable: semanticRoot.isFocusable,
      hasTap: semanticRoot.hasTap,
      hasLongPress: semanticRoot.hasLongPress,
      hasIncrease: semanticRoot.hasIncrease,
      hasDecrease: semanticRoot.hasDecrease,
      isToggled: semanticRoot.isToggled,
      isChecked: semanticRoot.isChecked,
      mergesDescendants: semanticRoot.mergesDescendants,
      excludesDescendants: semanticRoot.excludesDescendants,
      blocksBehind: semanticRoot.blocksBehind,
      labelGuarantee: semanticRoot.labelGuarantee,
      primaryLabelSource: semanticRoot.labelSource,
      isSemanticallyTransparent: semanticRoot.isPureContainer,
    );
  }

  /// Find the expression returned by a `build()` method declaration.
  Expression? _findBuildExpression(MethodDeclaration method) {
    final body = method.body;
    if (body is ExpressionFunctionBody) return body.expression;
    if (body is BlockFunctionBody) {
      for (final stmt in body.block.statements) {
        if (stmt is ReturnStatement) return stmt.expression;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Small constant evaluators reused across the pipeline
  // ---------------------------------------------------------------------------

  String? evalString(Expression? expression) {
    if (expression == null) return null;
    if (expression is SimpleStringLiteral) {
      return expression.value;
    }
    if (expression is AdjacentStrings) {
      final buffer = StringBuffer();
      for (final string in expression.strings) {
        final value = evalString(string);
        if (value == null) return null;
        buffer.write(value);
      }
      return buffer.toString();
    }
    if (expression is StringInterpolation) {
      final buffer = StringBuffer();
      for (final element in expression.elements) {
        if (element is InterpolationString) {
          buffer.write(element.value);
        } else {
          // Contains a dynamic expression; bail out.
          return null;
        }
      }
      return buffer.toString();
    }
    return null;
  }

  bool? evalBool(Expression? expression) {
    if (expression is BooleanLiteral) {
      return expression.value;
    }
    return null;
  }

  int? evalInt(Expression? expression) {
    if (expression is IntegerLiteral) {
      return expression.value;
    }
    return null;
  }
}

/// Build-scoped context that tracks transient semantic state.
///
/// Used by `SemanticBuilder` while walking a single widget tree. Shares
/// immutable global data and tracks ExcludeSemantics / BlockSemantics depth.
class BuildSemanticContext {
  BuildSemanticContext({
    required this.global,
    required this.enableHeuristics,
  });

  final GlobalSemanticContext global;
  final bool enableHeuristics;

  int excludeDepth = 0;
  int blockDepth = 0;

  bool get isWithinExcludedSubtree => excludeDepth > 0;
  bool get isWithinBlockedOverlay => blockDepth > 0;

  KnownSemanticsRepository get knownSemantics => global.knownSemantics;

  String? evalString(Expression? expression) => global.evalString(expression);
  bool? evalBool(Expression? expression) => global.evalBool(expression);
  int? evalInt(Expression? expression) => global.evalInt(expression);
}
