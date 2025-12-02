import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';

import 'widget_node.dart';

/// Builds [WidgetNode] trees directly from resolved AST nodes.
class WidgetTreeBuilder {
  WidgetTreeBuilder(this.unit);

  final ResolvedUnitResult unit;

  WidgetNode? fromExpression(Expression? expression) {
    if (expression == null) return null;
    expression = expression.unParenthesized;

    if (expression is InstanceCreationExpression) {
      return _fromInstanceCreation(expression);
    }

    if (expression is ConditionalExpression) {
      return fromExpression(expression.thenExpression) ??
          fromExpression(expression.elseExpression);
    }

    if (expression is CascadeExpression) {
      return fromExpression(expression.target);
    }

    return null;
  }

  WidgetNode? _fromInstanceCreation(InstanceCreationExpression expression) {
    final widgetType = _widgetTypeName(expression);
    if (widgetType == null) return null;

    final positionalArgs = <Expression>[];
    final props = <String, Expression>{};
    final slots = <String, WidgetNode?>{};
    final children = <WidgetNode>[];

    for (final argument in expression.argumentList.arguments) {
      if (argument is NamedExpression) {
        final name = argument.name.label.name;
        final value = argument.expression;
        props[name] = value;

        if (name == 'children') {
          _collectChildren(value, children);
          continue;
        }

        if (_slotNames.contains(name)) {
          final childNode = fromExpression(value);
          slots[name] = childNode;
        }
      } else {
        positionalArgs.add(argument);
      }
    }

    return WidgetNode(
      widgetType: widgetType,
      astNode: expression,
      positionalArgs: positionalArgs,
      props: props,
      slots: slots,
      children: children,
    );
  }

  void _collectChildren(Expression expression, List<WidgetNode> children) {
    if (expression is ListLiteral) {
      for (final element in expression.elements) {
        _collectElement(element, children);
      }
      return;
    }

    final childNode = fromExpression(expression);
    if (childNode != null) {
      children.add(childNode);
    }
  }

  void _collectElement(CollectionElement element, List<WidgetNode> children) {
    if (element is Expression) {
      final childNode = fromExpression(element);
      if (childNode != null) {
        children.add(childNode);
      }
      return;
    }

    if (element is IfElement) {
      _collectElement(element.thenElement, children);
      final elseElement = element.elseElement;
      if (elseElement != null) {
        _collectElement(elseElement, children);
      }
      return;
    }

    if (element is ForElement) {
      _collectElement(element.body, children);
      return;
    }

    if (element is SpreadElement) {
      _collectChildren(element.expression, children);
    }
  }

  String? _widgetTypeName(InstanceCreationExpression expression) {
    final type = expression.staticType ?? expression.constructorName.type.type;
    if (type is InterfaceType) {
      return type.element.name;
    }
    return expression.constructorName.type.toSource();
  }
}

const _slotNames = <String>{
  'child',
  'title',
  'subtitle',
  'leading',
  'trailing',
  'body',
  'appBar',
  'floatingActionButton',
  'bottomNavigationBar',
  'bottomSheet',
  'drawer',
  'endDrawer',
  'icon',
};
