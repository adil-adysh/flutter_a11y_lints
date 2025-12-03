// Copyright: project-local (no added license header) —
// This file implements helpers used by the semantic IR pipeline. It is
// intentionally self-contained and focused on small, deterministic helpers
// used by `SemanticBuilder` and the rule checks. The primary responsibilities
// are:
//  - Provide a compact `SemanticSummary` for custom widget classes.
//    Summaries are used as a lightweight approximation of a widget's
//    accessibility behaviour (role, control kind, label guarantees, and
//    merges/excludes behaviour) when the full semantic tree for that widget
//    isn't available.
//  - Provide an optional resolver-based path that, given analyzer-resolved
//    units, will inspect a widget's `build()` method and synthesize a
//    precise `SemanticSummary` by building a temporary WidgetNode ->
//    SemanticNode tree.
//  - Expose small evaluators for constant expressions (`evalString`,
//    `evalBool`, `evalInt`) used throughout the pipeline to interpret
//    simple literal arguments.
//
// Rationale and design notes:
//  - Cache & cycle guard: computing a summary can require analyzing other
//    widgets (transitively). To avoid infinite recursion and repeated work
//    we keep a cache keyed by class name and a `_summaryInProgress` guard
//    set. On detecting recursion we conservatively return `unknown`.
//  - Conservative fallbacks: when we cannot resolve a widget's body we
//    apply simple heuristics (e.g. treat StatelessWidget/StatefulWidget
//    subclasses as semantically-transparent containers) to reduce false
//    positives in lint rules.
//  - Resolver is optional: callers can provide an async resolver capable
//    of returning a `ResolvedUnitResult` for a given `InterfaceType`. The
//    resolver is intentionally pluggable to allow both CLI tests (where
//    we can resolve temporary files) and lighter-weight modes where
//    resolver access is not available.

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
// The analyzer exposes constant evaluation machinery from an internal
// library. We use the internal import as a best-effort to get a
// `ConstantEvaluator` implementation across analyzer versions. If the
// import isn't available in the running analyzer version the evaluators
// below will catch and fall back to conservative heuristics.
// No direct constant engine import here; prefer resolved-unit based
// evaluation implemented below so we avoid hard analyzer-version
// dependencies.
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_provider.dart';

import '../widget_tree/widget_tree_builder.dart';
import 'known_semantics.dart';
import 'semantic_builder.dart';
import 'semantic_node.dart';

/// Summary of a custom widget's semantic behavior.
/// A compact, serializable summary describing the observable accessibility
/// behaviour of a custom widget class.
///
/// Purpose:
/// - Used as a lightweight approximation of what a widget exposes to
///   assistive technologies without needing to fully analyze or expand the
///   widget's implementation at every call site.
/// - The summary intentionally focuses on the aspects rules care about:
///   role, control kind, focusability, basic gestures, merge/exclude
///   semantics behaviour, and a simple label guarantee.
///
/// Notes on interpretation:
/// - `isSemanticallyTransparent` indicates the widget should normally be
///   treated as a pass-through container (i.e. inspect children) unless a
///   more specific summary exists.
/// - `labelGuarantee` and `primaryLabelSource` are coarse signals used by
///   heuristics to decide if a widget is considered labelled.
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
  /// Cache of computed summaries for widget classes, keyed by a stable
  /// element identifier (`libraryUri::className`) to avoid collisions when
  /// different libraries declare classes with the same short name.
  final Map<String, SemanticSummary> _summaryCache = {};

  /// Guard set used to detect recursive computation (WidgetA → WidgetB → WidgetA).
  final Set<String> _summaryInProgress = {};

  /// Return a cached `SemanticSummary` for the given `InterfaceType`, or
  /// compute it if missing. If a cycle is detected during computation,
  /// `SemanticSummary.unknown` is returned to avoid infinite recursion.
  /// How it works (high level):
  /// 1. If the widget's class name is present in `KnownSemantics`, return a
  ///    summary derived from that authoritative metadata.
  /// 2. If a `resolver` was provided, attempt to obtain the resolved unit
  ///    for the widget type and analyze its `build()` body (quick-path
  ///    or full synthesis) via `_computeSummaryFromResolvedUnit`.
  /// 3. If resolution is unavailable or fails, apply conservative heuristics
  ///    (e.g. treat Stateless/Stateful widgets as semantically-transparent
  ///    containers) to avoid spurious diagnostics.
  ///
  /// The returned `SemanticSummary` should be treated as a fast, best-effort
  /// approximation used by rules — callers should not rely on it for full
  /// semantic equivalence with a runtime widget.
  Future<SemanticSummary?> getOrComputeSummary(
      InterfaceType? widgetType) async {
    final element = widgetType?.element;
    if (element == null) return null;
    final name = element.name;
    if (name == null) return null;

    final key = _elementKey(element);

    final cached = _summaryCache[key];
    if (cached != null) return cached;

    if (_summaryInProgress.contains(key)) {
      // Recursive widget graphs: degrade to unknown summary to avoid cycles.
      return SemanticSummary.unknown(name);
    }

    _summaryInProgress.add(key);
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
        _summaryCache[key] = summary;
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
              _summaryCache[key] = summary;
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
        _summaryCache[key] = summary;
        return summary;
      }

      // 4. Final fallback: unknown summary when behaviour can't be inferred.
      final unknown = SemanticSummary.unknown(name);
      _summaryCache[key] = unknown;
      return unknown;
    } finally {
      _summaryInProgress.remove(key);
    }
  }

  // Unit-aware evaluators: when a `ResolvedUnitResult` is available we try
  // to use the analyzer-provided constant evaluation engine (ConstantEvaluator
  // or equivalent) to evaluate arbitrary expressions. If that engine is not
  // available in the current analyzer version we fall back to safe, local
  // strategies (literal inspection and element computeConstantValue calls).
  String? evalStringInUnit(Expression? expression, ResolvedUnitResult unit) {
    if (expression == null) return null;
    // Fast-path for simple literal forms (Adjacents / Interpolation)
    final lit = evalString(expression);
    if (lit != null) return lit;

    // Try to resolve compile-time constants from the provided resolved unit.
    final seen = <String>{};
    return _evalConstStringFromUnit(expression, unit, seen);
  }

  bool? evalBoolInUnit(Expression? expression, ResolvedUnitResult unit) {
    if (expression == null) return null;
    expression = expression.unParenthesized;

    // Fast-path for simple literals and composed binary ops.
    final simple = evalBool(expression);
    if (simple != null) return simple;

    final seen = <String>{};
    return _evalConstBoolFromUnit(expression, unit, seen);
  }

  int? evalIntInUnit(Expression? expression, ResolvedUnitResult unit) {
    if (expression == null) return null;
    expression = expression.unParenthesized;

    final simple = evalInt(expression);
    if (simple != null) return simple;

    final seen = <String>{};
    return _evalConstIntFromUnit(expression, unit, seen);
  }

  // -----------------------
  // Resolved-unit constant evaluators
  // -----------------------

  String? _evalConstStringFromUnit(
    Expression? expression,
    ResolvedUnitResult unit,
    Set<String> seen,
  ) {
    if (expression == null) return null;
    final unp = expression.unParenthesized;
    if (unp is SimpleStringLiteral) return unp.value;
    if (unp is AdjacentStrings) {
      final buf = StringBuffer();
      for (final s in unp.strings) {
        final v = _evalConstStringFromUnit(s, unit, seen);
        if (v == null) return null;
        buf.write(v);
      }
      return buf.toString();
    }
    if (unp is StringInterpolation) {
      final buf = StringBuffer();
      for (final e in unp.elements) {
        if (e is InterpolationString) {
          buf.write(e.value);
        } else {
          return null;
        }
      }
      return buf.toString();
    }

    // Identifiers: resolve to const variable initializers or static const
    // class fields in the same unit.
    if (unp is SimpleIdentifier) {
      final name = unp.name;
      if (!seen.add('#$name')) return null;
      // Top-level consts
      for (final decl in unit.unit.declarations) {
        if (decl is TopLevelVariableDeclaration) {
          final vars = decl.variables;
          for (final v in vars.variables) {
            if (v.name.lexeme == name && vars.isConst) {
              final init = v.initializer;
              return _evalConstStringFromUnit(init, unit, seen);
            }
          }
        }
        // static const fields on classes
        if (decl is ClassDeclaration) {
          for (final member in decl.members) {
            if (member is FieldDeclaration && member.isStatic) {
              final vars = member.fields;
              if (!vars.isConst) continue;
              for (final v in vars.variables) {
                if (v.name.lexeme == name) {
                  return _evalConstStringFromUnit(v.initializer, unit, seen);
                }
              }
            }
          }
        }
      }
    }

    // PrefixedIdentifier or PropertyAccess for static fields: e.g. ClassName.foo
    if (unp is PrefixedIdentifier) {
      final prefix = unp.prefix.name;
      final member = unp.identifier.name;
      for (final decl in unit.unit.declarations) {
        if (decl is ClassDeclaration && decl.name.lexeme == prefix) {
          for (final memberDecl in decl.members) {
            if (memberDecl is FieldDeclaration && memberDecl.isStatic) {
              final vars = memberDecl.fields;
              if (!vars.isConst) continue;
              for (final v in vars.variables) {
                if (v.name.lexeme == member) {
                  return _evalConstStringFromUnit(v.initializer, unit, seen);
                }
              }
            }
          }
        }
      }
    }

    return null;
  }

  bool? _evalConstBoolFromUnit(
    Expression? expression,
    ResolvedUnitResult unit,
    Set<String> seen,
  ) {
    if (expression == null) return null;
    final unp = expression.unParenthesized;
    if (unp is BooleanLiteral) return unp.value;
    if (unp is PrefixExpression && unp.operator.type.lexeme == '!') {
      final inner = _evalConstBoolFromUnit(unp.operand, unit, seen);
      return inner == null ? null : !inner;
    }
    if (unp is BinaryExpression) {
      final op = unp.operator.lexeme;
      if (op == '&&') {
        final l = _evalConstBoolFromUnit(unp.leftOperand, unit, seen);
        if (l == false) return false;
        final r = _evalConstBoolFromUnit(unp.rightOperand, unit, seen);
        if (l == true && r != null) return r;
        return null;
      }
      if (op == '||') {
        final l = _evalConstBoolFromUnit(unp.leftOperand, unit, seen);
        if (l == true) return true;
        final r = _evalConstBoolFromUnit(unp.rightOperand, unit, seen);
        if (l == false && r != null) return r;
        return null;
      }
      if (op == '==' || op == '!=') {
        final lv = _evalConstStringFromUnit(unp.leftOperand, unit, seen) ??
            (_evalConstBoolFromUnit(unp.leftOperand, unit, seen)?.toString()) ??
            (_evalConstIntFromUnit(unp.leftOperand, unit, seen)?.toString());
        final rv = _evalConstStringFromUnit(unp.rightOperand, unit, seen) ??
            (_evalConstBoolFromUnit(unp.rightOperand, unit, seen)
                ?.toString()) ??
            (_evalConstIntFromUnit(unp.rightOperand, unit, seen)?.toString());
        if (lv != null && rv != null) {
          final eq = lv == rv;
          return op == '==' ? eq : !eq;
        }
      }
    }

    if (unp is SimpleIdentifier) {
      final name = unp.name;
      if (!seen.add('#$name')) return null;
      for (final decl in unit.unit.declarations) {
        if (decl is TopLevelVariableDeclaration) {
          final vars = decl.variables;
          for (final v in vars.variables) {
            if (v.name.lexeme == name && vars.isConst) {
              return _evalConstBoolFromUnit(v.initializer, unit, seen);
            }
          }
        }
        if (decl is ClassDeclaration) {
          for (final member in decl.members) {
            if (member is FieldDeclaration && member.isStatic) {
              final vars = member.fields;
              if (!vars.isConst) continue;
              for (final v in vars.variables) {
                if (v.name.lexeme == name) {
                  return _evalConstBoolFromUnit(v.initializer, unit, seen);
                }
              }
            }
          }
        }
      }
    }

    if (unp is PrefixedIdentifier) {
      final prefix = unp.prefix.name;
      final member = unp.identifier.name;
      for (final decl in unit.unit.declarations) {
        if (decl is ClassDeclaration && decl.name.lexeme == prefix) {
          for (final memberDecl in decl.members) {
            if (memberDecl is FieldDeclaration && memberDecl.isStatic) {
              final vars = memberDecl.fields;
              if (!vars.isConst) continue;
              for (final v in vars.variables) {
                if (v.name.lexeme == member) {
                  return _evalConstBoolFromUnit(v.initializer, unit, seen);
                }
              }
            }
          }
        }
      }
    }

    return null;
  }

  int? _evalConstIntFromUnit(
    Expression? expression,
    ResolvedUnitResult unit,
    Set<String> seen,
  ) {
    if (expression == null) return null;
    final unp = expression.unParenthesized;
    if (unp is IntegerLiteral) return unp.value;

    if (unp is SimpleIdentifier) {
      final name = unp.name;
      if (!seen.add('#$name')) return null;
      for (final decl in unit.unit.declarations) {
        if (decl is TopLevelVariableDeclaration) {
          final vars = decl.variables;
          for (final v in vars.variables) {
            if (v.name.lexeme == name && vars.isConst) {
              return _evalConstIntFromUnit(v.initializer, unit, seen);
            }
          }
        }
        if (decl is ClassDeclaration) {
          for (final member in decl.members) {
            if (member is FieldDeclaration && member.isStatic) {
              final vars = member.fields;
              if (!vars.isConst) continue;
              for (final v in vars.variables) {
                if (v.name.lexeme == name) {
                  return _evalConstIntFromUnit(v.initializer, unit, seen);
                }
              }
            }
          }
        }
      }
    }

    if (unp is PrefixedIdentifier) {
      final prefix = unp.prefix.name;
      final member = unp.identifier.name;
      for (final decl in unit.unit.declarations) {
        if (decl is ClassDeclaration && decl.name.lexeme == prefix) {
          for (final memberDecl in decl.members) {
            if (memberDecl is FieldDeclaration && memberDecl.isStatic) {
              final vars = memberDecl.fields;
              if (!vars.isConst) continue;
              for (final v in vars.variables) {
                if (v.name.lexeme == member) {
                  return _evalConstIntFromUnit(v.initializer, unit, seen);
                }
              }
            }
          }
        }
      }
    }

    return null;
  }

  /// Build a stable key for the analyzer element used for cache and cycle
  /// detection. Prefer the library URI when available; fall back to the
  /// element source URI. The key format is `<libraryUri>::<elementName>`.
  String _elementKey(dynamic element) {
    try {
      final libUri = element.library?.source?.uri?.toString();
      if (libUri != null) return '$libUri::${element.name}';
    } catch (_) {
      // Some analyzer element implementations don't expose `source` directly;
      // fall through to a conservative fallback below.
    }

    // Conservative fallback: include the element name and its hashCode to
    // reduce collision risk when library URI isn't available.
    return 'unknown::${element.name}::${element.hashCode}';
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

    // First try build() on the widget class itself. We look for a `build`
    // method declaration and accept either expression-bodied functions
    // (`=>`) or block bodies (`{ return ...; }`). The goal is to extract
    // the returned expression for lightweight analysis.
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

    // Quick-path: when the build() body returns a single
    // `InstanceCreationExpression` (for example `IconButton(...)`) it's
    // common for custom widgets to simply wrap or return a framework
    // widget. In that case we can consult `KnownSemantics` for the created
    // widget and construct a faithful summary without doing a full
    // widget-tree build.
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
    final treeBuilder = WidgetTreeBuilder(
      unit,
      constEval: (expr) => evalBoolInUnit(expr, unit),
    );
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
    // Extracts the single expression returned by `build()` when possible.
    // Supports both `=>` expressions and classic block bodies with a
    // top-level `return` statement. If multiple returns or complex flow is
    // present this helper intentionally returns `null` so callers fall back
    // to conservative analysis.
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
    // Evaluate string-like AST nodes when they are statically known.
    // Returns `null` when the expression cannot be reduced to a plain
    // string (e.g. contains interpolated expressions or non-literal parts).
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
          // Contains a dynamic expression; bail out because we can't
          // compute a stable string at analysis time.
          return null;
        }
      }
      return buffer.toString();
    }
    return null;
  }

  bool? evalBool(Expression? expression) {
    if (expression == null) return null;
    expression = expression.unParenthesized;

    if (expression is BooleanLiteral) return expression.value;

    if (expression is PrefixExpression &&
        expression.operator.type.lexeme == '!') {
      final inner = evalBool(expression.operand);
      return inner == null ? null : !inner;
    }

    if (expression is BinaryExpression) {
      final op = expression.operator.lexeme;
      if (op == '&&') {
        final left = evalBool(expression.leftOperand);
        if (left == false) return false;
        final right = evalBool(expression.rightOperand);
        if (left == true && right != null) return right;
        return null;
      }
      if (op == '||') {
        final left = evalBool(expression.leftOperand);
        if (left == true) return true;
        final right = evalBool(expression.rightOperand);
        if (left == false && right != null) return right;
        return null;
      }
      if (op == '==' || op == '!=') {
        // Try to evaluate equality when both sides reduce to simple literals
        final l = expression.leftOperand;
        final r = expression.rightOperand;
        final lv =
            evalString(l) ?? evalBool(l)?.toString() ?? evalInt(l)?.toString();
        final rv =
            evalString(r) ?? evalBool(r)?.toString() ?? evalInt(r)?.toString();
        if (lv != null && rv != null) {
          final eq = lv == rv;
          return op == '==' ? eq : !eq;
        }
      }
    }

    // Identifiers or property accesses: try to read a constant value from
    // the resolved element when available. Use dynamic invocation to avoid
    // hard dependency on specific Element impls.
    try {
      final el = (expression as dynamic).staticElement;
      if (el != null) {
        // Some analyzer implementations expose `computeConstantValue()` that
        // returns a DartObject-like instance with `toBoolValue()`.
        final constVal = (el as dynamic).computeConstantValue?.call();
        if (constVal != null) {
          // Try common accessors
          final asBool = constVal.toBoolValue?.call();
          if (asBool is bool) return asBool;
        }
      }
    } catch (_) {
      // ignore and fall through
    }

    return null;
  }

  int? evalInt(Expression? expression) {
    if (expression == null) return null;
    expression = expression.unParenthesized;
    if (expression is IntegerLiteral) return expression.value;

    try {
      final el = (expression as dynamic).staticElement;
      if (el != null) {
        final constVal = (el as dynamic).computeConstantValue?.call();
        if (constVal != null) {
          final asInt = constVal.toIntValue?.call();
          if (asInt is int) return asInt;
        }
      }
    } catch (_) {
      // ignore
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
    required this.unit,
  });

  final ResolvedUnitResult unit;

  final GlobalSemanticContext global;
  final bool enableHeuristics;

  int excludeDepth = 0;
  int blockDepth = 0;

  bool get isWithinExcludedSubtree => excludeDepth > 0;
  bool get isWithinBlockedOverlay => blockDepth > 0;

  KnownSemanticsRepository get knownSemantics => global.knownSemantics;

  // Convenience delegations to the global evaluators.
  // These helpers keep the `SemanticBuilder` code concise and clarify that
  // these evaluations are build-scoped but ultimately rely on global
  // deterministic logic.
  String? evalString(Expression? expression) =>
      global.evalStringInUnit(expression, unit);
  bool? evalBool(Expression? expression) =>
      global.evalBoolInUnit(expression, unit);
  int? evalInt(Expression? expression) =>
      global.evalIntInUnit(expression, unit);
}
