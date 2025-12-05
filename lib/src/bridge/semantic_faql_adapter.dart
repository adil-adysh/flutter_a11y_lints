import 'package:analyzer/dart/ast/ast.dart';

import '../faql/interpreter.dart';
import '../semantics/known_semantics.dart';
import '../semantics/semantic_neighborhood.dart';
import '../semantics/semantic_node.dart';
import '../semantics/semantic_tree.dart';

/// Adapter that exposes a `SemanticNode` as a `FaqlContext` for the FAQL interpreter.
class SemanticFaqlContext extends FaqlContext {
  SemanticFaqlContext({required this.node, required this.tree}) {
    _neighborhood = SemanticNeighborhood(tree);
  }

  final SemanticNode node;
  final SemanticTree tree;
  late final SemanticNeighborhood _neighborhood;

  // Direct property mapping
  @override
  String get role => node.role.name;

  @override
  String get widgetType => node.widgetType;

  @override
  bool get isFocusable => node.isFocusable;

  @override
  bool get isEnabled => node.isEnabled;

  @override
  bool get mergesDescendants => node.mergesDescendants;

  @override
  bool get hasTap => node.hasTap;

  @override
  bool get hasLongPress => node.hasLongPress;

  @override
  bool get isHidden {
    // Prefer the neighborhood's visibility heuristic; fall back to exclusion flag.
    final hidden = _neighborhood.isHidden(node);
    return hidden || node.excludesDescendants;
  }

  // Graph traversal
  @override
  Iterable<FaqlContext> get children => node.children
      .map((child) => SemanticFaqlContext(node: child, tree: tree));

  @override
  Iterable<FaqlContext> get ancestors sync* {
    var current = node;
    while (true) {
      final parent = _neighborhood.parentOf(current);
      if (parent == null) break;
      yield SemanticFaqlContext(node: parent, tree: tree);
      current = parent;
    }
  }

  @override
  Iterable<FaqlContext> get siblings => _neighborhood
      .siblingsOf(node)
      .where((s) => !identical(s, node))
      .map((s) => SemanticFaqlContext(node: s, tree: tree));

  // Optional focus traversal helpers (used by FAQL next_focus / prev_focus relations if added later).
  Iterable<FaqlContext> get nextFocus {
    final next = _neighborhood.nextFocusable(node);
    if (next == null) return const <FaqlContext>[];
    return [SemanticFaqlContext(node: next, tree: tree)];
  }

  Iterable<FaqlContext> get prevFocus {
    final prev = _neighborhood.previousFocusable(node);
    if (prev == null) return const <FaqlContext>[];
    return [SemanticFaqlContext(node: prev, tree: tree)];
  }

  // Dynamic properties
  @override
  Object? getProperty(String name) {
    switch (name) {
      case 'label':
        return node.effectiveLabel;
      case 'tooltip':
        return node.tooltip;
      case 'value':
        return node.value;
      case 'depth':
        return node.depth;
      case 'controlKind':
        return node.controlKind.name;
      case 'labelSource':
        return node.labelSource.name;
      case 'hasIncrease':
        return node.hasIncrease;
      case 'hasDecrease':
        return node.hasDecrease;
      case 'labelGuarantee':
        return node.labelGuarantee.name;
      case 'excludesDescendants':
        return node.excludesDescendants;
      case 'isPureContainer':
        return node.isPureContainer;
      case 'isSemanticBoundary':
        return node.isSemanticBoundary;
      case 'isCompositeControl':
        return node.isCompositeControl;
      case 'focusableDescendantCount':
        return _countFocusableDescendants(node);
      case 'assetPath':
        final creation = node.astNode;
        if (creation is InstanceCreationExpression) {
          return _extractAssetPath(creation);
        }
        return null;
      case 'imageConstructor':
        final creation = node.astNode;
        if (creation is InstanceCreationExpression &&
            node.widgetType == 'Image') {
          return creation.constructorName.name?.name ?? 'default';
        }
        return null;
      case 'backgroundImageProvided':
        if (node.widgetType != 'CircleAvatar') return null;
        final expr = node.getAttribute('backgroundImage');
        if (expr == null) return false;
        if (expr is NullLiteral) return false;
        return true;
      case 'childWidgetType':
        final expr = node.getAttribute('child');
        return expr == null ? null : _expressionWidgetType(expr);
      case 'hasMeaningfulSemanticsArgs':
        return _hasMeaningfulSemanticsArgs(node);
      case 'labeledChildrenCount':
        return _labeledChildrenCount(node);
      case 'hasButtonDescendant':
        return _hasButtonDescendant(node);
      default:
        return _extractLiteralValue(node.getAttribute(name));
    }
  }

  @override
  bool isPropertyResolved(String name) => getProperty(name) != null;

  Object? _extractLiteralValue(Expression? expr) {
    if (expr == null) return null;
    if (expr is BooleanLiteral) return expr.value;
    if (expr is IntegerLiteral) return expr.value;
    if (expr is SimpleStringLiteral) return expr.value;
    return null;
  }

  String? _extractAssetPath(InstanceCreationExpression creation) {
    final ctor = creation.constructorName.name?.name;
    if (ctor != 'asset') return null;

    // Prefer named argument 'name', otherwise first positional.
    Expression? expression;
    NamedExpression? named;
    for (final arg in creation.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'name') {
        named = arg;
        break;
      }
    }

    if (named != null) {
      expression = named.expression;
    } else if (creation.argumentList.arguments.isNotEmpty) {
      expression = creation.argumentList.arguments.first;
    }

    return _literalString(expression);
  }

  String? _literalString(Expression? expression) {
    if (expression is SimpleStringLiteral) return expression.value;
    if (expression is AdjacentStrings) {
      final buffer = StringBuffer();
      for (final string in expression.strings) {
        final value = _literalString(string);
        if (value == null) return null;
        buffer.write(value);
      }
      return buffer.toString();
    }
    if (expression is StringInterpolation) {
      final buffer = StringBuffer();
      for (final element in expression.elements) {
        if (element is InterpolationString) {
          buffer.write(element.value);
        } else {
          return null;
        }
      }
      return buffer.toString();
    }
    return null;
  }

  int _labeledChildrenCount(SemanticNode parent) {
    var count = 0;
    for (final child in parent.children) {
      if (_hasLabel(child)) {
        count++;
      }
    }
    return count;
  }

  int _countFocusableDescendants(SemanticNode parent) {
    var count = 0;

    void visit(SemanticNode n) {
      if (count >= 2) return; // early exit
      if (n.isFocusable) {
        count++;
        if (count >= 2) return;
      }
      for (final child in n.children) {
        if (count >= 2) break;
        visit(child);
      }
    }

    for (final child in parent.children) {
      if (count >= 2) break;
      visit(child);
    }

    return count;
  }

  bool _hasLabel(SemanticNode node) {
    if (node.effectiveLabel != null && node.effectiveLabel!.isNotEmpty) {
      return true;
    }
    return node.labelGuarantee != LabelGuarantee.none;
  }

  bool _hasButtonDescendant(SemanticNode root) {
    // Look for any descendant with a button-like controlKind.
    bool isButtonKind(SemanticNode n) {
      switch (n.controlKind) {
        case ControlKind.iconButton:
        case ControlKind.elevatedButton:
        case ControlKind.textButton:
        case ControlKind.filledButton:
        case ControlKind.outlinedButton:
        case ControlKind.floatingActionButton:
          return true;
        default:
          return false;
      }
    }

    for (final candidate in tree.physicalNodes) {
      if (!isButtonKind(candidate)) continue;
      var current = candidate;
      while (true) {
        final parent = _neighborhood.parentOf(current);
        if (parent == null) break;
        if (identical(parent, root)) return true;
        current = parent;
      }
    }

    // Fallback to raw AST inspection when semantic descendants are not linked.
    final childExpr = root.getAttribute('child');
    if (childExpr != null && _expressionIsButton(childExpr)) {
      return true;
    }
    return false;
  }

  bool _expressionIsButton(Expression expr) {
    if (expr is InstanceCreationExpression) {
      final typeName = _expressionWidgetType(expr);
      switch (typeName) {
        case 'IconButton':
        case 'ElevatedButton':
        case 'TextButton':
        case 'FilledButton':
        case 'OutlinedButton':
        case 'FloatingActionButton':
          return true;
      }
    }
    if (expr is NamedExpression) {
      return _expressionIsButton(expr.expression);
    }
    return false;
  }

  String? _expressionWidgetType(Expression expr) {
    if (expr is InstanceCreationExpression) {
      final type = expr.constructorName.type;
      // `toString()` on a TypeName is stable in analyzer for simple identifiers and prefixed names.
      return type.toString();
    }
    if (expr is NamedExpression) {
      return _expressionWidgetType(expr.expression);
    }
    return null;
  }

  bool _hasMeaningfulSemanticsArgs(SemanticNode target) {
    const names = {
      'label',
      'tooltip',
      'hint',
      'value',
      'attributedLabel',
      'attributedHint',
      'attributedValue',
    };

    for (final name in names) {
      final expr = target.getAttribute(name);
      if (expr == null) continue;
      final unwrapped = expr.unParenthesized;
      if (unwrapped is NullLiteral) continue;
      return true;
    }
    return false;
  }
}

/// Allowed FAQL identifier names exposed by the `SemanticFaqlContext`.
/// Used by the FAQL semantic validator to ensure rules only reference
/// known properties.
const Set<String> faqlAllowedIdentifiers = {
  // Direct getters
  'role',
  'widgetType',
  'isFocusable',
  'isEnabled',
  'mergesDescendants',
  'hasTap',
  'hasLongPress',
  'isHidden',

  // Dynamic properties exposed via getProperty
  'label',
  'tooltip',
  'value',
  'depth',
  'controlKind',
  'labelSource',
  'hasIncrease',
  'hasDecrease',
  'labelGuarantee',
  'excludesDescendants',
  'isPureContainer',
  'isSemanticBoundary',
  'isCompositeControl',
  'focusableDescendantCount',
  'assetPath',
  'imageConstructor',
  'backgroundImageProvided',
  'childWidgetType',
  'hasMeaningfulSemanticsArgs',
  'labeledChildrenCount',
  'hasButtonDescendant',
};
