import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_tree.dart';

/// A11 — Minimum Tap Target Size (literal-only conservative check)
class A11MinimumTapTargetSize {
  static const code = 'a11_minimum_tap_target_size';
  static const message = 'Interactive element has too small literal tap target';
  static const correctionMessage =
      'Wrap interactive control with a parent that provides at least 44px size';

  static List<A11Violation> checkTree(SemanticTree tree) {
    final violations = <A11Violation>[];
    for (final node in tree.accessibilityFocusNodes) {
      if (!_isInteractive(node)) continue;
      final ancestor = _findSizingAncestor(node, tree);
      if (ancestor == null) continue;
      final size = _extractLiteralSize(ancestor);
      if (size == null) continue;
      if (size.width < 44 || size.height < 44) {
        violations.add(A11Violation(
            node: node,
            container: ancestor,
            width: size.width,
            height: size.height));
      }
    }
    return violations;
  }

  static bool _isInteractive(SemanticNode node) =>
      node.isEnabled && (node.hasTap || node.hasLongPress);

  static SemanticNode? _findSizingAncestor(
      SemanticNode node, SemanticTree tree) {
    var current = node;
    while (current.parentId != null) {
      final parent = tree.byId[current.parentId!];
      if (parent == null) break;
      if (parent.widgetType == 'SizedBox' ||
          parent.widgetType == 'Container' ||
          parent.widgetType == 'ConstrainedBox') {
        return parent;
      }
      current = parent;
    }
    return null;
  }

  static _Size? _extractLiteralSize(SemanticNode node) {
    final ast = node.astNode;
    if (ast is! InstanceCreationExpression) return null;
    for (final arg in ast.argumentList.arguments) {
      if (arg is NamedExpression) {
        final name = arg.name.label.name;
        if (name == 'width' || name == 'height') {
          final expr = arg.expression;
          if (expr is IntegerLiteral) {
            final val = expr.value?.toDouble();
            if (val == null) return null;
            if (name == 'width') return _Size(val, double.infinity);
            return _Size(double.infinity, val);
          }
          if (expr is DoubleLiteral) {
            final val = expr.value;
            if (name == 'width') return _Size(val, double.infinity);
            return _Size(double.infinity, val);
          }
        }
        if (name == 'constraints') {
          final cexpr = arg.expression;
          if (cexpr is InstanceCreationExpression) {
            final typeSrc = cexpr.constructorName.type.toSource();
            if (typeSrc.contains('BoxConstraints')) {
              double? w;
              double? h;
              for (final cArg in cexpr.argumentList.arguments) {
                if (cArg is NamedExpression) {
                  final cname = cArg.name.label.name;
                  final inner = cArg.expression;
                  if ((cname == 'maxWidth' ||
                          cname == 'minWidth' ||
                          cname == 'tightWidth' ||
                          cname == 'width' ||
                          cname == 'tightFor') &&
                      inner is IntegerLiteral) {
                    w = inner.value?.toDouble();
                  }
                  if ((cname == 'maxHeight' ||
                          cname == 'minHeight' ||
                          cname == 'height') &&
                      inner is IntegerLiteral) {
                    h = inner.value?.toDouble();
                  }
                }
              }
              if (w != null || h != null) {
                return _Size(w ?? double.infinity, h ?? double.infinity);
              }
            }
          }
        }
      }
    }
    return null;
  }
}

class A11Violation {
  final SemanticNode node;
  final SemanticNode container;
  final double width;
  final double height;

  A11Violation(
      {required this.node,
      required this.container,
      required this.width,
      required this.height});

  String get description =>
      '${node.widgetType} has literal tap container ${container.widgetType} with size ${width}x${height} (<44)';
}

class _Size {
  _Size(this.width, this.height);
  final double width;
  final double height;
}
