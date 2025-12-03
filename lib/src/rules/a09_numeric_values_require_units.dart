import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_tree.dart';

/// A09 — Numeric values should include units
class A09NumericValuesRequireUnits {
  static const code = 'a09_numeric_values_require_units';
  static const message = 'Numeric label should include units';
  static const correctionMessage =
      'Include units (e.g., "bpm", "%") in numeric labels';

  static final _digitsOnly = RegExp(r'^\s*\d+(?:\.\d+)?\s*$');

  static List<A09Violation> checkTree(SemanticTree tree) {
    final violations = <A09Violation>[];
    for (final node in tree.accessibilityFocusNodes) {
      if (node.labelGuarantee != LabelGuarantee.hasStaticLabel) continue;
      final label = node.effectiveLabel;
      if (label == null) continue;
      if (_digitsOnly.hasMatch(label)) {
        violations.add(A09Violation(node: node, label: label));
      }
    }
    return violations;
  }
}

class A09Violation {
  final SemanticNode node;
  final String label;
  A09Violation({required this.node, required this.label});

  String get description => 'Numeric label "$label" should include units.';
}
