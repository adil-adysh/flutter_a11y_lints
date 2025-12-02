import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';

import 'widget_node.dart';

/// Builds [WidgetNode] trees directly from resolved AST nodes.
class WidgetTreeBuilder {
  WidgetTreeBuilder(this.unit);

  final ResolvedUnitResult unit;
  int _nextBranchGroupId = 0;

  WidgetNode? fromExpression(
    Expression? expression, {
    int? branchGroupId,
    int? branchValue,
  }) {
    if (expression == null) return null;
    expression = expression.unParenthesized;

    if (expression is InstanceCreationExpression) {
      return _fromInstanceCreation(
        expression,
        branchGroupId: branchGroupId,
        branchValue: branchValue,
      );
    }

    if (expression is ConditionalExpression) {
      return _fromConditional(
        expression,
        branchGroupId: branchGroupId,
        branchValue: branchValue,
      );
    }

    if (expression is CascadeExpression) {
      return fromExpression(
        expression.target,
        branchGroupId: branchGroupId,
        branchValue: branchValue,
      );
    }

    return null;
  }

  WidgetNode? _fromInstanceCreation(
    InstanceCreationExpression expression, {
    int? branchGroupId,
    int? branchValue,
  }) {
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
          _collectChildren(
            value,
            children,
            branchGroupId: branchGroupId,
            branchValue: branchValue,
          );
          continue;
        }

        if (_slotNames.contains(name)) {
          final childNode = fromExpression(
            value,
            branchGroupId: branchGroupId,
            branchValue: branchValue,
          );
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
      branchGroupId: branchGroupId,
      branchValue: branchValue,
    );
  }

  void _collectChildren(
    Expression expression,
    List<WidgetNode> children, {
    int? branchGroupId,
    int? branchValue,
  }) {
    if (expression is ListLiteral) {
      for (final element in expression.elements) {
        _collectElement(
          element,
          children,
          branchGroupId: branchGroupId,
          branchValue: branchValue,
        );
      }
      return;
    }

    final childNode = fromExpression(
      expression,
      branchGroupId: branchGroupId,
      branchValue: branchValue,
    );
    if (childNode != null) {
      children.add(childNode);
    }
  }

  void _collectElement(
    CollectionElement element,
    List<WidgetNode> children, {
    int? branchGroupId,
    int? branchValue,
  }) {
    if (element is Expression) {
      final childNode = fromExpression(
        element,
        branchGroupId: branchGroupId,
        branchValue: branchValue,
      );
      if (childNode != null) {
        children.add(childNode);
      }
      return;
    }

    if (element is IfElement) {
      final resolved = _tryEvalBool(element.expression);
      if (resolved != null) {
        final active = resolved ? element.thenElement : element.elseElement;
        if (active != null) {
          _collectElement(
            active,
            children,
            branchGroupId: branchGroupId,
            branchValue: branchValue,
          );
        }
        return;
      }

      final conditionalGroupId = _nextBranchGroupId++;
      _collectElement(
        element.thenElement,
        children,
        branchGroupId: conditionalGroupId,
        branchValue: 0,
      );
      final elseElement = element.elseElement;
      if (elseElement != null) {
        _collectElement(
          elseElement,
          children,
          branchGroupId: conditionalGroupId,
          branchValue: 1,
        );
      }
      return;
    }

    if (element is ForElement) {
      _collectElement(
        element.body,
        children,
        branchGroupId: branchGroupId,
        branchValue: branchValue,
      );
      return;
    }

    if (element is SpreadElement) {
      _collectChildren(
        element.expression,
        children,
        branchGroupId: branchGroupId,
        branchValue: branchValue,
      );
    }
  }

  WidgetNode? _fromConditional(
    ConditionalExpression expression, {
    int? branchGroupId,
    int? branchValue,
  }) {
    final resolved = _tryEvalBool(expression.condition);
    if (resolved != null) {
      final chosen =
          resolved ? expression.thenExpression : expression.elseExpression;
      return fromExpression(
        chosen,
        branchGroupId: branchGroupId,
        branchValue: branchValue,
      );
    }

    final conditionalGroupId = _nextBranchGroupId++;
    final branches = <WidgetNode>[];
    final thenNode = fromExpression(
      expression.thenExpression,
      branchGroupId: conditionalGroupId,
      branchValue: 0,
    );
    if (thenNode != null) {
      branches.add(thenNode);
    }

    final elseNode = fromExpression(
      expression.elseExpression,
      branchGroupId: conditionalGroupId,
      branchValue: 1,
    );
    if (elseNode != null) {
      branches.add(elseNode);
    }

    if (branches.isEmpty) {
      return null;
    }

    return WidgetNode(
      widgetType: '<conditional>',
      astNode: expression,
      positionalArgs: const <Expression>[],
      props: const <String, Expression>{},
      slots: const <String, WidgetNode?>{},
      children: const <WidgetNode>[],
      nodeType: WidgetNodeType.conditionalBranch,
      branchGroupId: branchGroupId,
      branchValue: branchValue,
      branchChildren: branches,
    );
  }

  bool? _tryEvalBool(Expression condition) {
    condition = condition.unParenthesized;
    if (condition is BooleanLiteral) {
      return condition.value;
    }
    return null;
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
  'label',
};
