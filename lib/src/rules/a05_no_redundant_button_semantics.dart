import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_a11y_lints/src/semantics/known_semantics.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_tree.dart';

/// A05: No redundant Semantics wrappers on Material buttons.
class A05NoRedundantButtonSemantics {
  static const code = 'a05_no_redundant_button_semantics';
  static const message = 'Remove redundant Semantics wrapper around button';
  static const correctionMessage =
      'Remove the Semantics wrapper or provide a custom label instead of button:true.';

  static const _materialControls = <ControlKind>{
    ControlKind.iconButton,
    ControlKind.elevatedButton,
    ControlKind.textButton,
    ControlKind.filledButton,
    ControlKind.outlinedButton,
    ControlKind.floatingActionButton,
  };

  static bool check(SemanticNode node) {
    if (node.widgetType != 'Semantics') return false;
    if (node.children.isEmpty) return false;
    if (node.excludesDescendants) return false;

    final creation = node.astNode;
    if (creation is! InstanceCreationExpression) return false;

    final wrapsMaterialButton = node.children.any(
      (child) => _materialControls.contains(child.controlKind),
    );
    if (!wrapsMaterialButton) return false;

    final hasMeaningfulSemantics = _hasMeaningfulSemanticsArgs(creation);
    final setsButtonTrue = _literalBoolArg(creation, 'button') == true;

    if (!setsButtonTrue && hasMeaningfulSemantics) {
      return false;
    }

    return setsButtonTrue || !hasMeaningfulSemantics;
  }

  static List<A05Violation> checkTree(SemanticTree tree) {
    final violations = <A05Violation>[];
    for (final node in tree.physicalNodes) {
      if (check(node)) {
        violations.add(A05Violation(node: node));
      }
    }
    return violations;
  }
}

class A05Violation {
  A05Violation({required this.node});

  final SemanticNode node;

  String get description =>
      'Semantics wrapper around ${node.children.first.widgetType} is redundant; '
      'use the button\'s built-in semantics or provide a custom label.';
}

const _meaningfulArgNames = {
  'label',
  'tooltip',
  'hint',
  'value',
  'attributedLabel',
  'attributedHint',
  'attributedValue',
};

bool _hasMeaningfulSemanticsArgs(InstanceCreationExpression creation) {
  for (final argument in creation.argumentList.arguments) {
    if (argument is! NamedExpression) continue;
    final name = argument.name.label.name;
    if (!_meaningfulArgNames.contains(name)) continue;
    final expression = argument.expression.unParenthesized;
    if (expression is NullLiteral) {
      continue;
    }
    return true;
  }
  return false;
}

bool? _literalBoolArg(InstanceCreationExpression creation, String name) {
  for (final argument in creation.argumentList.arguments) {
    if (argument is NamedExpression && argument.name.label.name == name) {
      final expression = argument.expression.unParenthesized;
      if (expression is BooleanLiteral) {
        return expression.value;
      }
      if (expression is NullLiteral) {
        return false;
      }
      return null;
    }
  }
  return null;
}
