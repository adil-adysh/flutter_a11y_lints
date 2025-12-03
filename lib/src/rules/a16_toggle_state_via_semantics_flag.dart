import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_tree.dart';
import 'package:flutter_a11y_lints/src/semantics/known_semantics.dart';

/// A16 — Toggle State Via Semantics Flags
/// Conservative: if a Semantics parent provides a literal label that contains
/// state words (on/off/checked/unchecked) and the child toggle control does
/// not use `toggled`/`checked` semantic flags, warn.
class A16ToggleStateViaSemanticsFlag {
  static const code = 'a16_toggle_state_via_semantics_flag';
  static const message = 'Toggle state should be expressed via semantics flags';
  static const correctionMessage =
      'Use Semantics(toggled: ...) or checked: ... instead of embedding state words in label';

  static final _statePattern = RegExp(
      r'\b(on|off|checked|unchecked|enabled|disabled)\b',
      caseSensitive: false);

  static List<A16Violation> checkTree(SemanticTree tree) {
    final violations = <A16Violation>[];

    for (final parent in tree.physicalNodes) {
      if (parent.widgetType != 'Semantics') continue;
      final label = parent.label;
      if (label == null) continue;
      if (!_statePattern.hasMatch(label)) continue;

      // Look for descendant toggle controls under this semantics node.
      void visit(SemanticNode n) {
        if (_isToggleControl(n) && !n.isToggled && !n.isChecked) {
          violations.add(
              A16Violation(node: n, semanticsWrapper: parent, label: label));
        }
        for (final c in n.children) visit(c);
      }

      for (final child in parent.children) {
        visit(child);
      }

      // Fallback: if the semantic wrapper AST directly wraps a Checkbox/Switch
      // and the semantic children search didn't find anything, inspect the
      // parent's AST to detect a direct child expression.
      if (violations.isEmpty) {
        final ast = parent.astNode;
        if (ast is InstanceCreationExpression) {
          for (final arg in ast.argumentList.arguments) {
            if (arg is NamedExpression && arg.name.label.name == 'child') {
              final childExpr = arg.expression;
              if (childExpr is InstanceCreationExpression) {
                final typeName = childExpr.constructorName.type.toSource();
                if ({'Checkbox', 'Switch', 'Radio'}.contains(typeName)) {
                  // Create a synthetic violation referencing the parent
                  violations.add(A16Violation(
                      node: parent, semanticsWrapper: parent, label: label));
                }
              }
            }
          }
        }
      }
    }

    return violations;
  }

  static bool _isToggleControl(SemanticNode node) {
    final byKind = node.controlKind == ControlKind.checkboxControl ||
        node.controlKind == ControlKind.switchControl;
    final byName = {'Checkbox', 'Switch', 'Radio'}.contains(node.widgetType);
    return byKind || byName;
  }
}

class A16Violation {
  final SemanticNode node;
  final SemanticNode semanticsWrapper;
  final String label;

  A16Violation(
      {required this.node,
      required this.semanticsWrapper,
      required this.label});

  String get description =>
      '${node.widgetType} uses label "${label}" containing state words; prefer semantics flags.';
}
