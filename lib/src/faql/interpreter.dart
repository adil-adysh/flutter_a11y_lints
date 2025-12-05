import 'ast.dart';

class FaqlRuntimeError implements Exception {
  final String message;
  FaqlRuntimeError(this.message);
  @override
  String toString() => 'FaqlRuntimeError: $message';
}

class FaqlCompilationError implements Exception {
  final String message;
  FaqlCompilationError(this.message);
  @override
  String toString() => 'FaqlCompilationError: $message';
}

/// The contract that your Flutter Linter must implement.
/// This bridges the gap between FAQL and the Analyzer.
abstract class FaqlContext {
  String get role; // 'button', 'text', etc.
  String get widgetType; // 'InkWell', 'Container'

  // State
  bool get isFocusable;
  bool get isEnabled;
  bool get isHidden;
  bool get mergesDescendants;
  bool get hasTap;
  bool get hasLongPress;

  // Graph
  Iterable<FaqlContext> get children;
  Iterable<FaqlContext> get ancestors;
  Iterable<FaqlContext> get siblings;

  // AST Properties
  Object? getProperty(String name);
  bool isPropertyResolved(String name);
}

class FaqlInterpreter {
  final Map<String, List<String>> _kindMap;

  /// Constructs an interpreter.
  ///
  /// The optional [kindMap] allows callers to define what widget roles
  /// belong to a logical "kind" (e.g. 'input', 'action'). If omitted,
  /// a conservative default map is used.
  FaqlInterpreter({Map<String, List<String>>? kindMap})
      : _kindMap = kindMap ??
            const {
              'input': ['textField', 'slider', 'switch'],
              'action': ['button', 'toggle'],
            };

  /// Entry point: Evaluates a rule against a node.
  /// Returns [true] if the rule passes (or is skipped), [false] if it fails.
  bool evaluate(FaqlRule rule, FaqlContext context) {
    // 1. Selection Phase
    if (!_matchesSelector(rule.selectors, context)) {
      return true; // Not applicable, so technically "passes" (skipped)
    }

    // 2. Filtering Phase (when:)
    if (rule.when != null) {
      final shouldRun = _evaluateExpression(rule.when!, context);
      if (shouldRun != true) return true; // Guard failed, skip rule
    }

    // 3. Assertion Phase (ensure:)
    final result = _evaluateExpression(rule.ensure, context);
    return result == true;
  }

  bool _matchesSelector(List<FaqlSelector> selectors, FaqlContext context) {
    for (final selector in selectors) {
      if (selector is AnySelector) return true;
      if (selector is RoleSelector && selector.role == context.role)
        return true;
      if (selector is TypeSelector && selector.type == context.widgetType)
        return true;
      if (selector is KindSelector) {
        // Use configured kind map; allows separation of policy from engine.
        if (_kindMap[selector.kind]?.contains(context.role) ?? false)
          return true;
      }
    }
    return false;
  }

  dynamic _evaluateExpression(FaqlExpression expr, FaqlContext context) {
    if (expr is Identifier) {
      final n = expr.name;
      switch (n) {
        case 'role':
          return context.role;
        case 'widgetType':
        case 'type':
          return context.widgetType;
        default:
          final p = context.getProperty(n);
          if (p != null) return p;
          // Unresolved identifier: return null to avoid surprising
          // string-equality semantics. Callers can treat `null` as missing.
          return null;
      }
    }

    if (expr is LiteralExpression) return expr.value;

    if (expr is BooleanStateExpression) {
      switch (expr.name) {
        case 'focusable':
          return context.isFocusable;
        case 'enabled':
          return context.isEnabled;
        case 'hidden':
          return context.isHidden;
        case 'merges_descendants':
          return context.mergesDescendants;
        case 'has_tap':
          return context.hasTap;
        case 'has_long_press':
          return context.hasLongPress;
        default:
          return false;
      }
    }

    if (expr is PropExpression) {
      if (expr.isResolved == true) {
        return context.isPropertyResolved(expr.name);
      }
      final raw = context.getProperty(expr.name);
      if (raw == null) return null; // Safe navigation

      // Basic casting logic
      if (expr.asType == 'int') {
        if (raw is num) {
          if (raw is double && (raw.isNaN || raw.isInfinite)) return null;
          return raw.toInt();
        }
        if (raw is String) {
          final parsed = num.tryParse(raw);
          if (parsed == null) return null;
          if (parsed is double && (parsed.isNaN || parsed.isInfinite))
            return null;
          return parsed.toInt();
        }
        if (raw is bool) return raw ? 1 : 0;
        return null;
      }
      if (expr.asType == 'string') return raw.toString();
      if (expr.asType == 'bool') {
        if (raw is bool) return raw;
        if (raw is String) {
          final v = raw.toLowerCase().trim();
          if (v == 'true') return true;
          if (v == 'false') return false;
          return null;
        }
        if (raw is num) return raw != 0;
        return null;
      }
      return raw;
    }

    if (expr is UnaryExpression) {
      final val = _evaluateExpression(expr.expr, context);
      if (expr.op == '!') return val != true; // logical NOT
      if (expr.op == '-') {
        if (val is num) return -val;
        throw FaqlRuntimeError('Unary - applied to non-number: $val');
      }
    }

    if (expr is BinaryExpression) {
      switch (expr.op) {
        case FaqlBinaryOp.and:
          final l = _evaluateExpression(expr.left, context);
          if (l != true) return false; // short-circuit
          final r = _evaluateExpression(expr.right, context);
          return r == true;
        case FaqlBinaryOp.or:
          final l = _evaluateExpression(expr.left, context);
          if (l == true) return true; // short-circuit
          final r = _evaluateExpression(expr.right, context);
          return r == true;
        case FaqlBinaryOp.equals:
          final l = _evaluateExpression(expr.left, context);
          final r = _evaluateExpression(expr.right, context);
          if (l == r) return true;
          final lb = _toBool(l);
          final rb = _toBool(r);
          if (lb != null && rb != null) return lb == rb;
          return false;
        case FaqlBinaryOp.notEquals:
          final l = _evaluateExpression(expr.left, context);
          final r = _evaluateExpression(expr.right, context);
          if (l == r) return false;
          final lb2 = _toBool(l);
          final rb2 = _toBool(r);
          if (lb2 != null && rb2 != null) return lb2 != rb2;
          return true;
        case FaqlBinaryOp.add:
          final l = _evaluateExpression(expr.left, context);
          final r = _evaluateExpression(expr.right, context);
          final ln = _toNumber(l);
          final rn = _toNumber(r);
          if (ln != null && rn != null) return ln + rn;
          throw FaqlRuntimeError('Operator + requires two numbers, got $l and $r');
        case FaqlBinaryOp.subtract:
          final l = _evaluateExpression(expr.left, context);
          final r = _evaluateExpression(expr.right, context);
          final ln = _toNumber(l);
          final rn = _toNumber(r);
          if (ln == null || rn == null) throw FaqlRuntimeError('Operator - requires two numbers, got $l and $r');
          return ln - rn;
        case FaqlBinaryOp.multiply:
          final l = _evaluateExpression(expr.left, context);
          final r = _evaluateExpression(expr.right, context);
          final ln = _toNumber(l);
          final rn = _toNumber(r);
          if (ln == null || rn == null) throw FaqlRuntimeError('Operator * requires two numbers, got $l and $r');
          return ln * rn;
        case FaqlBinaryOp.divide:
          final l = _evaluateExpression(expr.left, context);
          final r = _evaluateExpression(expr.right, context);
          final ln = _toNumber(l);
          final rn = _toNumber(r);
          if (ln == null || rn == null) throw FaqlRuntimeError('Operator / requires two numbers, got $l and $r');
          if (rn == 0) throw FaqlRuntimeError('Division by zero');
          return ln / rn;
        case FaqlBinaryOp.less:
          final l = _evaluateExpression(expr.left, context);
          final r = _evaluateExpression(expr.right, context);
          final ln = _toNumber(l);
          final rn = _toNumber(r);
          if (ln == null || rn == null) throw FaqlRuntimeError('< requires numbers');
          return ln < rn;
        case FaqlBinaryOp.greater:
          final l = _evaluateExpression(expr.left, context);
          final r = _evaluateExpression(expr.right, context);
          final ln = _toNumber(l);
          final rn = _toNumber(r);
          if (ln == null || rn == null) throw FaqlRuntimeError('> requires numbers');
          return ln > rn;
        case FaqlBinaryOp.lessEqual:
          final l = _evaluateExpression(expr.left, context);
          final r = _evaluateExpression(expr.right, context);
          final ln = _toNumber(l);
          final rn = _toNumber(r);
          if (ln == null || rn == null) throw FaqlRuntimeError('<= requires numbers');
          return ln <= rn;
        case FaqlBinaryOp.greaterEqual:
          final l = _evaluateExpression(expr.left, context);
          final r = _evaluateExpression(expr.right, context);
          final ln = _toNumber(l);
          final rn = _toNumber(r);
          if (ln == null || rn == null) throw FaqlRuntimeError('>= requires numbers');
          return ln >= rn;
        case FaqlBinaryOp.tildeEquals:
          final lv = _evaluateExpression(expr.left, context);
          final rv = _evaluateExpression(expr.right, context);
          return lv.toString().toLowerCase().trim() == rv.toString().toLowerCase().trim();
        case FaqlBinaryOp.contains:
          final l = _evaluateExpression(expr.left, context);
          final r = _evaluateExpression(expr.right, context);
          if (l == null) return false;
          return l.toString().contains(r.toString());
        case FaqlBinaryOp.matches:
          // If RHS is a RegexMatchExpression was produced by the parser it will
          // be represented as a RegexMatchExpression node instead of BinaryExpression.
          // But handle generic runtime where RHS may be a string pattern.
          final l = _evaluateExpression(expr.left, context);
          final r = _evaluateExpression(expr.right, context);
          if (l == null || r == null) return false;
          try {
            var pattern = r.toString();
            var caseSensitive = true;
            if (pattern.startsWith('(?i)')) {
              caseSensitive = false;
              pattern = pattern.substring(4);
            }
            return RegExp(pattern, caseSensitive: caseSensitive).hasMatch(l.toString());
          } catch (e) {
            throw FaqlRuntimeError('Invalid regex: $e');
          }
      }
    }

    if (expr is RegexMatchExpression) {
      final l = _evaluateExpression(expr.left, context);
      if (l == null) return false;
      return expr.pattern.hasMatch(l.toString());
    }

    if (expr is RelationLengthExpression) {
      final list = _getRelation(expr.relation, context);
      return list.length;
    }

    if (expr is AggregatorExpression) {
      final list = _getRelation(expr.relation, context);

      switch (expr.aggregator) {
        case FaqlAggregator.any:
          for (final child in list) {
            if (_evaluateExpression(expr.expr, child) == true) return true;
          }
          return false;
        case FaqlAggregator.all:
          for (final child in list) {
            if (_evaluateExpression(expr.expr, child) != true) return false;
          }
          return true;
        case FaqlAggregator.none:
          for (final child in list) {
            if (_evaluateExpression(expr.expr, child) == true) return false;
          }
          return true;
      }
    }

    return null;
  }

  Iterable<FaqlContext> _getRelation(FaqlRelation relation, FaqlContext context) {
    switch (relation) {
      case FaqlRelation.children:
        return context.children;
      case FaqlRelation.ancestors:
        return context.ancestors;
      case FaqlRelation.siblings:
        return context.siblings;
      case FaqlRelation.nextFocus:
      case FaqlRelation.prevFocus:
        // Not modeled in FaqlContext currently
        return [];
    }
  }

  num? _toNumber(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    if (v is String) {
      final parsed = num.tryParse(v);
      if (parsed == null) return null;
      if (parsed is double && (parsed.isNaN || parsed.isInfinite)) return null;
      return parsed;
    }
    return null;
  }

  bool? _toBool(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is String) {
      final s = v.toLowerCase().trim();
      if (s == 'true') return true;
      if (s == 'false') return false;
      return null;
    }
    if (v is num) return v != 0;
    return null;
  }
}
