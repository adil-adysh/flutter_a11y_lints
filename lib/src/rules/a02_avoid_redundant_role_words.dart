import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_tree.dart';
import 'package:flutter_a11y_lints/src/semantics/known_semantics.dart';

/// A02: Avoid Redundant Role Words
///
/// Detects labels that include redundant role words like "button", "icon", etc.
/// that are already announced by the widget's semantic role.
class A02AvoidRedundantRoleWords {
  static const code = 'a02_avoid_redundant_role_words';
  static const message = 'Label contains redundant role words';
  static const correctionMessage =
      'Remove words like "button", "icon" from tooltip or Semantics labels; the role is announced automatically.';

  static const _inspectSources = {
    LabelSource.tooltip,
    LabelSource.semanticsWidget,
    LabelSource.customWidgetParameter,
    LabelSource.inputDecoration,
    LabelSource.other,
  };

  static final _redundantWords = RegExp(
    r'\b(button|btn|icon|image|link|checkbox|radio|switch|selected|checked|toggle)\b',
    caseSensitive: false,
  );

  /// Check if a semantic node violates this rule
  static bool check(SemanticNode node) {
    if (!_isEligibleNode(node)) return false;
    final label = _labelText(node);
    if (label == null || label.isEmpty) return false;
    return _redundantWords.hasMatch(label);
  }

  /// Get violations for a semantic tree
  static List<A02Violation> checkTree(SemanticTree tree) {
    final violations = <A02Violation>[];

    for (final node in tree.accessibilityFocusNodes) {
      if (!_isEligibleNode(node)) {
        continue;
      }
      final label = _labelText(node);
      if (label == null || label.isEmpty) {
        continue;
      }
      final redundantWords = _extractRedundantWords(label);
      if (redundantWords.isEmpty) {
        continue;
      }
      violations.add(A02Violation(
        node: node,
        label: label,
        redundantWords: redundantWords,
      ));
    }
    return violations;
  }

  static List<String> _extractRedundantWords(String label) {
    final matches = _redundantWords.allMatches(label);
    return matches.map((m) => m.group(0)!.toLowerCase()).toSet().toList();
  }

  static bool _isEligibleNode(SemanticNode node) {
    if (!node.isEnabled) return false;
    if (!_isInteractive(node)) return false;
    if (!_inspectSources.contains(node.labelSource)) return false;
    if (node.labelGuarantee == LabelGuarantee.none) return false;
    return true;
  }

  static bool _isInteractive(SemanticNode node) {
    if (node.controlKind != ControlKind.none) return true;
    return node.hasTap ||
        node.hasLongPress ||
        node.hasIncrease ||
        node.hasDecrease;
  }

  static String? _labelText(SemanticNode node) {
    switch (node.labelSource) {
      case LabelSource.tooltip:
        return node.tooltip ?? node.label;
      case LabelSource.semanticsWidget:
      case LabelSource.customWidgetParameter:
      case LabelSource.inputDecoration:
      case LabelSource.other:
        return node.label ?? node.effectiveLabel;
      default:
        return null;
    }
  }
}

class A02Violation {
  final SemanticNode node;
  final List<String> redundantWords;
  final String label;

  A02Violation({
    required this.node,
    required this.label,
    required this.redundantWords,
  });

  String get description {
    final words = redundantWords.join(', ');
    return 'Label "$label" contains redundant role word(s): $words';
  }
}
