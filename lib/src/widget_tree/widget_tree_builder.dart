import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';

import 'widget_node.dart';

/// Builds [WidgetNode] trees directly from resolved AST nodes.
class WidgetTreeBuilder {
  /// `constEval` is an optional callback used to attempt constant folding of
  /// boolean expressions encountered when building collection `if`/`?:`
  /// elements. When provided, it should return `true`, `false`, or `null`
  /// when the expression cannot be resolved at analysis time.
  WidgetTreeBuilder(this.unit, {bool? Function(Expression?)? constEval})
      : _constEval = constEval;

  final ResolvedUnitResult unit;
  int _nextBranchGroupId = 0;
  final bool? Function(Expression?)? _constEval;

  /// WidgetTreeBuilder
  ///
  /// Responsible for converting an expression (typically the body returned by
  /// a `build()` method) into a `WidgetNode` tree. This builder preserves
  /// control-flow structure: when encountering `if`/`?:`/collection `if`
  /// elements that cannot be constant-evaluated, it assigns a `branchGroupId`
  /// and per-branch `branchValue` so downstream phases can tell which nodes
  /// are mutually exclusive. Preserving branch information is crucial to
  /// prevent heuristics from combining information that never co-occurs at
  /// runtime (e.g., using a sibling Text from an alternate branch as a label).

  WidgetNode? fromExpression(
    Expression? expression, {
    int? branchGroupId,
    int? branchValue,
  }) {
    // Entry point to convert an `Expression` into a `WidgetNode`.
    // We strip parentheses, handle cascades by delegating to the target, and
    // dispatch instance creation expressions and conditional expressions to
    // specialized builders. Returns `null` when the expression does not
    // represent a widget construction the builder recognizes.
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
    // Build a `WidgetNode` for a constructor call. Extract positional args,
    // named props, recognize known slot names, and collect `children` when
    // the `children` named argument is present.
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
    // Collect children from a value that can either be a `ListLiteral` (the
    // common `children: [ ... ]` case) or a single widget expression.
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
    // Handle collection elements inside list literals. We support:
    // - plain Expression elements (widgets)
    // - `IfElement` (conditional collection element) with constant folding
    //   when possible; otherwise assign a `branchGroupId` and distinct
    //   `branchValue`s for then/else branches
    // - `ForElement` by descending into its body
    // - `SpreadElement` by collecting children from the spread expression
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

      // Non-const conditional: assign a group id so mutually-exclusive
      // branches can be identified by downstream heuristics.
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
    // Convert a conditional expression (`cond ? then : else`) into either a
    // single chosen node (if the condition const-evaluates) or a
    // `WidgetNode` representing a conditional branch with two `branchChildren`.
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
    // Try to constant-evaluate a boolean expression. Only handles literal
    // booleans at the moment; this keeps the builder conservative.
    condition = condition.unParenthesized;
    // Prefer the provided `_constEval` callback when available so callers can
    // provide a richer constant evaluator.
    if (_constEval != null) {
      try {
        return _constEval(condition);
      } catch (_) {
        // fall through to conservative checks
      }
    }

    if (condition is BooleanLiteral) {
      return condition.value;
    }

    // If the condition is a simple identifier referencing a top-level const
    // variable in the same resolved unit, attempt to read the initializer.
    // This helps fold constructs like `const showFirst = true;`.
    if (condition is SimpleIdentifier) {
      final name = condition.name;
      try {
        for (final decl in unit.unit.declarations) {
          if (decl is TopLevelVariableDeclaration) {
            final vars = decl.variables.variables;
            for (final v in vars) {
              if (v.name.lexeme == name) {
                final init = v.initializer;
                if (init != null) return _tryEvalBool(init);
              }
            }
          }
        }
      } catch (_) {
        // ignore resolution failures
      }
    }

    return null;
  }

  String? _widgetTypeName(InstanceCreationExpression expression) {
    // Resolve the constructor's type name. Prefer `staticType` when available
    // (resolved AST), otherwise fall back to the source text. This provides a
    // stable widgetType string used by KnownSemantics lookups.
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
