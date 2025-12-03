import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_tree.dart';
import 'package:flutter_a11y_lints/src/semantics/known_semantics.dart';

/// A16 — Toggle State Via Semantics Flags
/// Detect Semantics wrappers that encode toggle state in their label instead
/// of using the dedicated `toggled`/`checked` properties. This focuses on
/// Semantics containers that sit above Toggle widgets (Switch/Checkbox/etc.).
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

    for (final node in tree.physicalNodes) {
      if (node.widgetType != 'Semantics') continue;
      final label = node.label;
      if (label == null || !_statePattern.hasMatch(label)) continue;
      if (!_hasToggleDescendant(node)) continue;
      violations.add(A16Violation(node: node, label: label));
    }

    return violations;
  }

  static bool _hasToggleDescendant(SemanticNode node) {
    bool visit(SemanticNode current) {
      for (final child in current.children) {
        if (_isToggleControl(child)) {
          return true;
        }
        if (visit(child)) return true;
      }
      return false;
    }

    return visit(node);
  }

  static bool _isToggleControl(SemanticNode node) {
    final byKind = node.controlKind == ControlKind.checkboxControl ||
        node.controlKind == ControlKind.switchControl;
    final byName = {'Checkbox', 'Switch', 'Radio', 'SwitchListTile'}
        .contains(node.widgetType);
    return byKind || byName;
  }
}

class A16Violation {
  final SemanticNode node;
  final String label;

  A16Violation({required this.node, required this.label});

  String get description =>
      'Semantics uses label "$label" containing state words; prefer semantics flags.';
}
