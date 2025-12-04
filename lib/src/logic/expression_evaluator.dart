// Copyright: project-local (no added license header) —
// This file extracts standalone expression evaluation logic used across the
// semantic IR pipeline. The evaluators are stateless helpers that accept a
// ResolvedUnitResult and attempt to constant-evaluate simple expressions
// (strings, booleans, integers) from both immediate AST nodes and resolved
// compile-time constants from the analyzed unit.
//
// Purpose:
// - Decouple constant evaluation logic from WidgetTreeBuilder and
//   GlobalSemanticContext so it can be reused by DSL evaluators and other
//   analysis phases.
// - Provide a single, testable entry point for all expression evaluation
//   across the codebase.
// - Support both fast-path literal evaluation and slow-path resolved-unit
//   constant lookups.

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';

/// Standalone constant expression evaluator.
///
/// Provides methods to evaluate Dart expressions that appear in widget
/// constructors to simple literals (strings, booleans, integers). Supports
/// both fast-path literal matching and resolved-unit constant lookups.
class ExpressionEvaluator {
  /// Optional callback for custom boolean evaluation (used by WidgetTreeBuilder).
  /// When provided, this is tried first before falling back to standard evaluation.
  final bool? Function(Expression?)? customConstEval;

  /// Optional callback to evaluate boolean expressions in conditional contexts.
  /// When available, overrides the default _tryEvalBool behavior.
  final bool? Function(Expression?)? Function(ResolvedUnitResult)?
      makeConstEvalForUnit;

  const ExpressionEvaluator({
    this.customConstEval,
    this.makeConstEvalForUnit,
  });

  /// Try to evaluate a boolean expression in a conditional context.
  /// Used by WidgetTreeBuilder for constant-folding if/?: branches.
  /// Returns true, false, or null (when the expression cannot be resolved).
  bool? tryEvalBool(Expression condition) {
    condition = condition.unParenthesized;

    // Prefer custom evaluator if provided
    if (customConstEval != null) {
      try {
        return customConstEval!(condition);
      } catch (_) {
        // fall through to conservative checks
      }
    }

    if (condition is BooleanLiteral) {
      return condition.value;
    }

    return null;
  }

  /// Evaluate a string expression from a resolved unit.
  /// Handles literals, adjacent strings, and string interpolation (without
  /// interpolated expressions). Falls back to resolving constants from the
  /// analyzed unit (top-level consts, static const fields).
  String? evalStringInUnit(Expression? expression, ResolvedUnitResult unit) {
    if (expression == null) return null;

    // Fast-path for simple literal forms
    final lit = evalString(expression);
    if (lit != null) return lit;

    // Try to resolve compile-time constants from the provided unit
    final seen = <String>{};
    return _evalConstStringFromUnit(expression, unit, seen);
  }

  /// Evaluate a boolean expression from a resolved unit.
  /// Handles literals, binary operations (&&, ||), and prefix operations (!).
  /// Falls back to resolving constants from the analyzed unit.
  bool? evalBoolInUnit(Expression? expression, ResolvedUnitResult unit) {
    if (expression == null) return null;
    expression = expression.unParenthesized;

    // Fast-path for simple literals and composed binary ops
    final simple = evalBool(expression);
    if (simple != null) return simple;

    final seen = <String>{};
    return _evalConstBoolFromUnit(expression, unit, seen);
  }

  /// Evaluate an integer expression from a resolved unit.
  /// Handles literals and basic arithmetic. Falls back to resolving constants
  /// from the analyzed unit.
  int? evalIntInUnit(Expression? expression, ResolvedUnitResult unit) {
    if (expression == null) return null;
    expression = expression.unParenthesized;

    final simple = evalInt(expression);
    if (simple != null) return simple;

    final seen = <String>{};
    return _evalConstIntFromUnit(expression, unit, seen);
  }

  // -----------------------
  // Fast-path evaluators (no unit required)
  // -----------------------

  /// Evaluate string-like AST nodes when they are statically known.
  /// Returns null when the expression cannot be reduced to a plain string
  /// (e.g., contains interpolated expressions or non-literal parts).
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
          // Contains a dynamic expression; bail out
          return null;
        }
      }
      return buffer.toString();
    }
    return null;
  }

  /// Evaluate boolean expressions (literals, !, &&, ||, ==, !=).
  /// Returns null when the expression cannot be evaluated.
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

    // Try to read a constant value from the resolved element
    try {
      final el = (expression as dynamic).staticElement;
      if (el != null) {
        final constVal = (el as dynamic).computeConstantValue?.call();
        if (constVal != null) {
          final asBool = constVal.toBoolValue?.call();
          if (asBool is bool) return asBool;
        }
      }
    } catch (_) {
      // ignore and fall through
    }

    return null;
  }

  /// Evaluate integer expressions (literals, basic arithmetic).
  /// Returns null when the expression cannot be evaluated.
  int? evalInt(Expression? expression) {
    if (expression == null) return null;
    expression = expression.unParenthesized;

    if (expression is IntegerLiteral) return expression.value;

    if (expression is PrefixExpression &&
        expression.operator.type.lexeme == '-') {
      final inner = evalInt(expression.operand);
      return inner == null ? null : -inner;
    }

    if (expression is BinaryExpression) {
      final op = expression.operator.lexeme;
      final left = evalInt(expression.leftOperand);
      final right = evalInt(expression.rightOperand);
      if (left != null && right != null) {
        if (op == '+') return left + right;
        if (op == '-') return left - right;
        if (op == '*') return left * right;
        if (op == '~/') return left ~/ right;
        if (op == '%') return left % right;
      }
    }

    // Try to read a constant value from the resolved element
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
      // ignore and fall through
    }

    return null;
  }

  // -----------------------
  // Resolved-unit constant evaluators
  // -----------------------

  /// Resolve a string expression from a compile-time constant in the unit.
  /// Recursively follows variable initializers and static const fields.
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
    // class fields in the same unit
    if (unp is SimpleIdentifier) {
      final name = unp.name;
      if (!seen.add('#$name')) return null; // Cycle guard
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

    // PrefixedIdentifier for static fields: e.g. ClassName.foo
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

  /// Resolve a boolean expression from a compile-time constant in the unit.
  /// Handles literals, binary operations, and prefix operations.
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
            _evalConstBoolFromUnit(unp.leftOperand, unit, seen)?.toString() ??
            _evalConstIntFromUnit(unp.leftOperand, unit, seen)?.toString();
        final rv = _evalConstStringFromUnit(unp.rightOperand, unit, seen) ??
            _evalConstBoolFromUnit(unp.rightOperand, unit, seen)?.toString() ??
            _evalConstIntFromUnit(unp.rightOperand, unit, seen)?.toString();
        if (lv != null && rv != null) {
          final eq = lv == rv;
          return op == '==' ? eq : !eq;
        }
      }
    }

    // SimpleIdentifier: resolve const in this unit
    if (unp is SimpleIdentifier) {
      final name = unp.name;
      if (!seen.add('#$name')) return null; // Cycle guard
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

    // PrefixedIdentifier for static fields
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

  /// Resolve an integer expression from a compile-time constant in the unit.
  /// Handles literals, basic arithmetic, and constant lookups.
  int? _evalConstIntFromUnit(
    Expression? expression,
    ResolvedUnitResult unit,
    Set<String> seen,
  ) {
    if (expression == null) return null;
    final unp = expression.unParenthesized;

    if (unp is IntegerLiteral) return unp.value;

    if (unp is PrefixExpression && unp.operator.type.lexeme == '-') {
      final inner = _evalConstIntFromUnit(unp.operand, unit, seen);
      return inner == null ? null : -inner;
    }

    if (unp is BinaryExpression) {
      final op = unp.operator.lexeme;
      final left = _evalConstIntFromUnit(unp.leftOperand, unit, seen);
      final right = _evalConstIntFromUnit(unp.rightOperand, unit, seen);
      if (left != null && right != null) {
        if (op == '+') return left + right;
        if (op == '-') return left - right;
        if (op == '*') return left * right;
        if (op == '~/') return left ~/ right;
        if (op == '%') return left % right;
      }
    }

    // SimpleIdentifier: resolve const in this unit
    if (unp is SimpleIdentifier) {
      final name = unp.name;
      if (!seen.add('#$name')) return null; // Cycle guard
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

    // PrefixedIdentifier for static fields
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
}
