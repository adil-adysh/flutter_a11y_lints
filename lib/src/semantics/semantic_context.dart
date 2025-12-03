import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_provider.dart';

import 'known_semantics.dart';
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
/// This holds immutable/global resources used during semantic synthesis:
/// - `knownSemantics`: metadata for built-in widgets
/// - `typeProvider`: analyzer type helpers used to resolve class elements
///
/// It also implements a small memoization/cycle-guarding cache for
/// `SemanticSummary` instances computed for custom widgets. The summary cache
/// prevents re-analyzing the same widget class repeatedly and protects against
/// recursive widget references by degrading to `SemanticSummary.unknown` when
/// a cycle is detected.
class GlobalSemanticContext {
  GlobalSemanticContext({
    required this.knownSemantics,
    required this.typeProvider,
  });

  final KnownSemanticsRepository knownSemantics;
  final TypeProvider typeProvider;

  // Cache of computed summaries for custom widget classes. Keyed by class
  // name, not by full element identity; this is sufficient for the offline
  // analysis use-case and keeps the cache simple.
  final Map<String, SemanticSummary> _summaryCache = {};
  // Guard set used to detect recursive computation (e.g., WidgetA -> WidgetB -> WidgetA).
  final Set<String> _summaryInProgress = {};

  /// Return a cached `SemanticSummary` for the given `InterfaceType`, or
  /// compute it if missing. If a cycle is detected while computing a summary,
  /// we return `SemanticSummary.unknown` to avoid infinite recursion.
  ///
  /// NOTE: The body currently returns an `unknown` summary as a placeholder.
  /// Implementers should resolve `widgetType.element`, find its `build()`
  /// method, build a minimal `WidgetNode` tree and run the local semantic
  /// builder to derive a compact `SemanticSummary` (role, controlKind,
  /// label guarantees, merges/excludes behavior, isSemanticallyTransparent).
  SemanticSummary? getOrComputeSummary(InterfaceType? widgetType) {
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
      // First, if this widget is a known built-in widget, derive its summary
      // from the KnownSemantics table. This gives a high-fidelity summary for
      // Flutter framework widgets without needing to analyze source.
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
          // Consider pure containers semantically transparent.
          isSemanticallyTransparent: known.isPureContainer,
        );
        _summaryCache[name] = summary;
        return summary;
      }

      // Conservative heuristics for custom widgets: if the class extends
      // Flutter's StatelessWidget or StatefulWidget, treat it as a
      // semantically-transparent container by default (so rules may inspect
      // children). We detect this by examining the declared supertypes' names
      // — this is conservative but useful when source AST is not available.
      final supertypeNames = <String>{};
      for (final st in element.allSupertypes) {
        final en = st.element.name;
        if (en != null) supertypeNames.add(en);
      }

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
          // Assume custom widgets are semantically transparent until we
          // analyze their build() bodies.
          isSemanticallyTransparent: true,
        );
        _summaryCache[name] = summary;
        return summary;
      }

      // Fallback: unknown summary when we cannot infer behaviours cheaply.
      final summary = SemanticSummary.unknown(name);
      _summaryCache[name] = summary;
      return summary;
    } finally {
      _summaryInProgress.remove(name);
    }
  }

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
