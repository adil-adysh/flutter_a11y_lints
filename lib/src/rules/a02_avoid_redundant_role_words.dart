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
      'Remove words like "button", "icon" from label - the role is announced automatically';

  static final _redundantWords = RegExp(
    r'\b(button|btn|icon|image|link|checkbox|radio|switch|selected|checked|toggle)\b',
    caseSensitive: false,
  );

  /// Check if a semantic node violates this rule
  static bool check(SemanticNode node) {
    final label = node.label;
    if (label == null || label.isEmpty) return false;

    // Only check interactive controls
    if (!node.isEnabled) return false;
    if (node.controlKind == ControlKind.none) return false;

    // Check if label contains redundant words
    return _redundantWords.hasMatch(label);
  }

  /// Get violations for a semantic tree
  static List<A02Violation> checkTree(SemanticTree tree) {
    final violations = <A02Violation>[];

    void visit(SemanticNode node) {
      if (check(node)) {
        violations.add(A02Violation(
          node: node,
          redundantWords: _extractRedundantWords(node.label!),
        ));
      }
      for (final child in node.children) {
        visit(child);
      }
    }

    visit(tree.root);
    return violations;
  }

  static List<String> _extractRedundantWords(String label) {
    final matches = _redundantWords.allMatches(label);
    return matches.map((m) => m.group(0)!.toLowerCase()).toSet().toList();
  }
}

class A02Violation {
  final SemanticNode node;
  final List<String> redundantWords;

  A02Violation({
    required this.node,
    required this.redundantWords,
  });

  String get description {
    final words = redundantWords.join(', ');
    return 'Label "${node.label}" contains redundant role word(s): $words';
  }
}
