// Copyright: project-local (no added license header) —
// This file defines the object model for DSL rules, including A11yRule,
// TargetSelector, and Condition abstractions.
//
// Purpose:
// - Provide intermediate data structures that textual DSL rules parse into.
// - Decouple the DSL parser/interpreter from concrete rule evaluation logic.
// - Allow rules to be composed, inspected, and evaluated without tight coupling
//   to the semantic tree structures or rule engine.
//
// Design:
// - Abstract base classes (TargetSelector, Condition) allow extensibility for
//   new selector and condition types without modifying the rule model.
// - Conditions are composable using boolean operators (AND, OR, NOT).
// - A11yRule aggregates a target selector and a list of conditions; when all
//   conditions match, a violation is recorded.

import 'package:analyzer/dart/ast/ast.dart' show Expression;

import '../semantics/known_semantics.dart';
import '../semantics/semantic_node.dart';

/// Severity level of a rule violation.
enum ViolationSeverity { error, warning, info }

/// A single accessibility rule in the DSL.
///
/// A rule defines:
/// - A target selector (which semantic nodes to consider)
/// - Expectations (conditions all must hold)
/// - User-facing messages
///
/// Rules are evaluated by checking each node against the selector, then running
/// all conditions. If all conditions pass, the node is accessible (no violation).
/// If any condition fails, a violation is reported.
class A11yRule {
  /// Unique identifier for this rule (e.g., 'a01_label_non_text_controls').
  final String id;

  /// Severity level (error, warning, info).
  final ViolationSeverity severity;

  /// Semantic nodes matching this selector will be checked.
  final TargetSelector target;

  /// Conditions that must all be true for a node to pass the rule.
  /// If any condition fails, a violation is reported.
  final List<Condition> expectations;

  /// User-facing message describing the violation.
  final String message;

  /// Optional message offering corrective action.
  final String? correctionMessage;

  const A11yRule({
    required this.id,
    required this.severity,
    required this.target,
    required this.expectations,
    required this.message,
    this.correctionMessage,
  });

  /// Evaluate this rule against a semantic node.
  /// Returns true if all conditions pass (node is accessible), false otherwise.
  bool checkNode(SemanticNode node) {
    if (!target.matches(node)) return true;

    // All expectations must be true for the node to pass
    for (final condition in expectations) {
      if (!condition.evaluate(node)) {
        return false;
      }
    }

    return true;
  }

  @override
  String toString() =>
      'A11yRule($id, severity: $severity, conditions: ${expectations.length})';
}

/// Abstract base class for selectors that target specific nodes.
///
/// Selectors filter nodes to those that should be checked by a rule.
/// When a selector returns false, the rule's expectations are skipped.
abstract class TargetSelector {
  /// Returns true if this node should be checked by a rule.
  bool matches(SemanticNode node);
}

/// Matches nodes with a specific semantic role.
class RoleSelector extends TargetSelector {
  final SemanticRole role;

  RoleSelector(this.role);

  @override
  bool matches(SemanticNode node) => node.role == role;

  @override
  String toString() => 'RoleSelector(role: ${role.name})';
}

/// Matches nodes with a specific widget type (class name).
class TypeSelector extends TargetSelector {
  final String widgetType;

  TypeSelector(this.widgetType);

  @override
  bool matches(SemanticNode node) => node.widgetType == widgetType;

  @override
  String toString() => 'TypeSelector(widgetType: $widgetType)';
}

/// Matches nodes with a specific control kind.
class ControlKindSelector extends TargetSelector {
  final ControlKind controlKind;

  ControlKindSelector(this.controlKind);

  @override
  bool matches(SemanticNode node) => node.controlKind == controlKind;

  @override
  String toString() => 'ControlKindSelector(controlKind: ${controlKind.name})';
}

/// Matches any semantic node.
class AnySelector extends TargetSelector {
  @override
  bool matches(SemanticNode node) => true;

  @override
  String toString() => 'AnySelector()';
}

/// Abstract base class for conditions that check semantic node properties.
///
/// A condition evaluates a semantic node and returns true if the property
/// satisfies the condition, false otherwise.
abstract class Condition {
  /// Evaluate this condition for the given node.
  /// Returns true if the condition passes (property satisfies expectations).
  bool evaluate(SemanticNode node);
}

/// Checks a boolean semantic property (e.g., isFocusable, isEnabled).
class PropertyCondition extends Condition {
  final String propertyName;
  final PropertyOperator operator;
  final bool expectedValue;

  PropertyCondition({
    required this.propertyName,
    required this.operator,
    required this.expectedValue,
  });

  @override
  bool evaluate(SemanticNode node) {
    final actual = _getProperty(node);
    if (actual == null) return false; // Property not found

    return switch (operator) {
      PropertyOperator.eq => actual == expectedValue,
      PropertyOperator.notEq => actual != expectedValue,
    };
  }

  bool? _getProperty(SemanticNode node) => switch (propertyName) {
        'isFocusable' => node.isFocusable,
        'isEnabled' => node.isEnabled,
        'hasTap' => node.hasTap,
        'hasLongPress' => node.hasLongPress,
        'hasIncrease' => node.hasIncrease,
        'hasDecrease' => node.hasDecrease,
        'isToggled' => node.isToggled,
        'isChecked' => node.isChecked,
        'mergesDescendants' => node.mergesDescendants,
        'excludesDescendants' => node.excludesDescendants,
        'blocksBehind' => node.blocksBehind,
        'isSemanticBoundary' => node.isSemanticBoundary,
        'isCompositeControl' => node.isCompositeControl,
        'isPureContainer' => node.isPureContainer,
        'isInMutuallyExclusiveGroup' => node.isInMutuallyExclusiveGroup,
        'hasScroll' => node.hasScroll,
        'hasDismiss' => node.hasDismiss,
        'isHeuristic' => node.isHeuristic,
        _ => null,
      };

  @override
  String toString() =>
      'PropertyCondition($propertyName $operator $expectedValue)';
}

/// Checks a string semantic property (e.g., label, tooltip).
class StringPropertyCondition extends Condition {
  final String propertyName;
  final StringOperator operator;
  final String? value;

  StringPropertyCondition({
    required this.propertyName,
    required this.operator,
    this.value,
  });

  @override
  bool evaluate(SemanticNode node) {
    final actual = _getProperty(node);

    return switch (operator) {
      StringOperator.isEmpty => actual == null || actual.isEmpty,
      StringOperator.isNotEmpty => actual != null && actual.isNotEmpty,
      StringOperator.eq => actual == value,
      StringOperator.contains =>
        actual != null && value != null && actual.contains(value as Pattern),
      StringOperator.matches =>
        actual != null && value != null && RegExp(value!).hasMatch(actual),
      StringOperator.notMatches =>
        actual != null && value != null && !RegExp(value!).hasMatch(actual),
    };
  }

  String? _getProperty(SemanticNode node) => switch (propertyName) {
        'label' => node.label,
        'tooltip' => node.tooltip,
        'value' => node.value,
        'effectiveLabel' => node.effectiveLabel,
        'explicitChildLabel' => node.explicitChildLabel,
        _ => null,
      };

  @override
  String toString() =>
      'StringPropertyCondition($propertyName $operator "$value")';
}

/// Checks a label guarantee (strictness level).
class GuaranteeCondition extends Condition {
  final LabelGuarantee minGuarantee;

  GuaranteeCondition(this.minGuarantee);

  @override
  bool evaluate(SemanticNode node) =>
      _guaranteeLevel(node.labelGuarantee) >= _guaranteeLevel(minGuarantee);

  int _guaranteeLevel(LabelGuarantee g) => switch (g) {
        LabelGuarantee.none => 0,
        LabelGuarantee.hasLabelButDynamic => 1,
        LabelGuarantee.hasStaticLabel => 2,
      };

  @override
  String toString() => 'GuaranteeCondition(minGuarantee: $minGuarantee)';
}

/// Checks a label source (provenance).
class LabelSourceCondition extends Condition {
  final LabelSource expectedSource;

  LabelSourceCondition(this.expectedSource);

  @override
  bool evaluate(SemanticNode node) => node.labelSource == expectedSource;

  @override
  String toString() => 'LabelSourceCondition(source: $expectedSource)';
}

/// Checks raw widget attributes (non-semantic properties).
///
/// This allows DSL rules to query properties like 'elevation', 'overflow' etc.
/// The raw AST expression is evaluated using an external evaluator context.
class RawAttributeCondition extends Condition {
  final String attributeName;
  final RawAttributeOperator operator;
  final dynamic expectedValue;

  /// Optional external evaluator context (used by DSL runtime).
  /// When provided, raw expressions are evaluated through this context.
  final dynamic Function(Expression)? evaluator;

  RawAttributeCondition({
    required this.attributeName,
    required this.operator,
    this.expectedValue,
    this.evaluator,
  });

  @override
  bool evaluate(SemanticNode node) {
    final expr = node.getAttribute(attributeName);
    if (expr == null) return false; // Attribute not found

    if (evaluator == null) return false; // Cannot evaluate without context

    try {
      final actual = evaluator!(expr);
      return switch (operator) {
        RawAttributeOperator.eq => actual == expectedValue,
        RawAttributeOperator.notEq => actual != expectedValue,
        RawAttributeOperator.lt => actual != null &&
            expectedValue != null &&
            (actual as Comparable).compareTo(expectedValue) < 0,
        RawAttributeOperator.lte => actual != null &&
            expectedValue != null &&
            (actual as Comparable).compareTo(expectedValue) <= 0,
        RawAttributeOperator.gt => actual != null &&
            expectedValue != null &&
            (actual as Comparable).compareTo(expectedValue) > 0,
        RawAttributeOperator.gte => actual != null &&
            expectedValue != null &&
            (actual as Comparable).compareTo(expectedValue) >= 0,
      };
    } catch (_) {
      return false; // Evaluation failed
    }
  }

  @override
  String toString() =>
      'RawAttributeCondition($attributeName $operator $expectedValue)';
}

/// Logical AND of multiple conditions (all must be true).
class AndCondition extends Condition {
  final List<Condition> conditions;

  AndCondition(this.conditions);

  @override
  bool evaluate(SemanticNode node) =>
      conditions.every((cond) => cond.evaluate(node));

  @override
  String toString() =>
      'AndCondition(${conditions.map((c) => c.toString()).join(', ')})';
}

/// Logical OR of multiple conditions (at least one must be true).
class OrCondition extends Condition {
  final List<Condition> conditions;

  OrCondition(this.conditions);

  @override
  bool evaluate(SemanticNode node) =>
      conditions.any((cond) => cond.evaluate(node));

  @override
  String toString() =>
      'OrCondition(${conditions.map((c) => c.toString()).join(', ')})';
}

/// Logical NOT of a single condition.
class NotCondition extends Condition {
  final Condition condition;

  NotCondition(this.condition);

  @override
  bool evaluate(SemanticNode node) => !condition.evaluate(node);

  @override
  String toString() => 'NotCondition($condition)';
}

/// Operator for boolean property comparisons.
enum PropertyOperator {
  eq,
  notEq;

  @override
  String toString() => switch (this) {
        eq => '==',
        notEq => '!=',
      };
}

/// Operator for string property comparisons.
enum StringOperator {
  isEmpty,
  isNotEmpty,
  eq,
  contains,
  matches,
  notMatches;

  @override
  String toString() => switch (this) {
        isEmpty => '.isEmpty',
        isNotEmpty => '.isNotEmpty',
        eq => '==',
        contains => 'contains',
        matches => 'matches',
        notMatches => 'notMatches',
      };
}

/// Operator for raw attribute comparisons.
enum RawAttributeOperator {
  eq,
  notEq,
  lt,
  lte,
  gt,
  gte;

  @override
  String toString() => switch (this) {
        eq => '==',
        notEq => '!=',
        lt => '<',
        lte => '<=',
        gt => '>',
        gte => '>=',
      };
}

/// Factory helper for creating common condition patterns.
class ConditionBuilder {
  /// Condition: label is not empty (common requirement).
  static Condition labelNotEmpty() => StringPropertyCondition(
      propertyName: 'label', operator: StringOperator.isNotEmpty);

  /// Condition: label or tooltip is not empty (common fallback).
  static Condition labelOrTooltip() => OrCondition([
        StringPropertyCondition(
            propertyName: 'label', operator: StringOperator.isNotEmpty),
        StringPropertyCondition(
            propertyName: 'tooltip', operator: StringOperator.isNotEmpty),
      ]);

  /// Condition: node is enabled and focusable.
  static Condition enabledAndFocusable() => AndCondition([
        PropertyCondition(
            propertyName: 'isEnabled',
            operator: PropertyOperator.eq,
            expectedValue: true),
        PropertyCondition(
            propertyName: 'isFocusable',
            operator: PropertyOperator.eq,
            expectedValue: true),
      ]);

  /// Condition: node has a static label.
  static Condition hasStaticLabel() =>
      GuaranteeCondition(LabelGuarantee.hasStaticLabel);
}
