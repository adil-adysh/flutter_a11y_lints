// Copyright: project-local (no added license header) —
// This file provides deterministic literal and constant evaluators shared by
// the Semantic IR pipeline. Custom widgets are expanded directly into
// Semantic IR by SemanticIrBuilder; unresolved implementations remain unknown
// rather than being approximated by a type-level summary.

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
import 'package:analyzer/dart/element/type_provider.dart';

import 'known_semantics.dart';

/// Global context shared across semantic builds.
///
/// Holds immutable/global resources used during semantic synthesis.
class GlobalSemanticContext {
  GlobalSemanticContext({
    required this.knownSemantics,
    required this.typeProvider,
  });

  final KnownSemanticsRepository knownSemantics;
  final TypeProvider typeProvider;

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
