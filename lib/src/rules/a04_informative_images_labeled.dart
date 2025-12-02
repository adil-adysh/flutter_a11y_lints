import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_tree.dart';

class A04InformativeImagesLabeled {
  static const code = 'a04_informative_images_labeled';
  static const message = 'Informative images must provide semantic labels';
  static const correctionMessage =
      'Add semantic labels via semanticLabel/semanticsLabel or wrap in Semantics with a label.';

  static const _imageConstructors = {'network', 'file'};

  static List<A04Violation> checkTree(SemanticTree tree) {
    final violations = <A04Violation>[];

    for (final node in tree.physicalNodes) {
      final circleViolation = _checkCircleAvatar(tree, node);
      if (circleViolation != null) {
        violations.add(circleViolation);
      }

      final listTileViolation = _checkListTileLeading(tree, node);
      if (listTileViolation != null) {
        violations.add(listTileViolation);
      }
    }

    return violations;
  }

  static A04Violation? _checkCircleAvatar(
    SemanticTree tree,
    SemanticNode node,
  ) {
    if (node.widgetType != 'CircleAvatar') return null;
    final creation = _asInstanceCreation(node.astNode);
    if (creation == null) return null;

    final hasBackgroundImage = _hasNonNullNamedArg(creation, 'backgroundImage');
    if (!hasBackgroundImage) return null;

    final hasSemanticsLabel = _hasAnyNonNullNamedArg(
      creation,
      const ['semanticsLabel', 'semanticLabel'],
    );
    if (hasSemanticsLabel) return null;

    if (_nodeOrAncestorHasLabel(tree, node)) return null;

    return A04Violation(node: node, context: 'CircleAvatar backgroundImage');
  }

  static A04Violation? _checkListTileLeading(
    SemanticTree tree,
    SemanticNode node,
  ) {
    if (node.widgetType != 'ListTile') return null;
    final creation = _asInstanceCreation(node.astNode);
    if (creation == null) return null;

    final leadingArg = _namedArgument(creation, 'leading');
    if (leadingArg == null) return null;
    final target = _extractInformativeImageTarget(leadingArg.expression);
    if (target == null) return null;

    final semanticNode = _findNodeByAst(tree, target.expression);
    if (semanticNode != null && _nodeOrAncestorHasLabel(tree, semanticNode)) {
      return null;
    }

    return A04Violation(
      node: semanticNode ?? node,
      context: target.description,
    );
  }

  static _InformativeImageTarget? _extractInformativeImageTarget(
    Expression expression,
  ) {
    final unwrapped = expression.unParenthesized;
    if (unwrapped is InstanceCreationExpression) {
      final widgetType = _widgetTypeName(unwrapped);
      if (widgetType == 'Semantics') {
        if (_hasNonNullNamedArg(unwrapped, 'label')) {
          return null;
        }
        final childArg = _namedArgument(unwrapped, 'child');
        if (childArg == null) return null;
        return _extractInformativeImageTarget(childArg.expression);
      }

      if (widgetType == 'Image') {
        final ctor = unwrapped.constructorName.name?.name;
        if (ctor == null || !_imageConstructors.contains(ctor)) {
          return null;
        }
        if (_hasNonNullNamedArg(unwrapped, 'semanticLabel')) {
          return null;
        }
        return _InformativeImageTarget(
          expression: unwrapped,
          description: 'ListTile.leading Image.$ctor',
        );
      }
    }
    return null;
  }

  static bool _nodeOrAncestorHasLabel(SemanticTree tree, SemanticNode node) {
    if (_nodeHasExplicitLabel(node)) {
      return true;
    }

    var current = node;
    while (current.parentId != null) {
      final parent = tree.byId[current.parentId!];
      if (parent == null) {
        break;
      }
      if (parent.widgetType == 'Semantics' && _nodeHasExplicitLabel(parent)) {
        return true;
      }
      current = parent;
    }
    return false;
  }

  static bool _nodeHasExplicitLabel(SemanticNode node) {
    return node.labelGuarantee != LabelGuarantee.none &&
        node.effectiveLabel != null;
  }

  static InstanceCreationExpression? _asInstanceCreation(AstNode? node) {
    if (node is InstanceCreationExpression) {
      return node;
    }
    return null;
  }

  static NamedExpression? _namedArgument(
    InstanceCreationExpression creation,
    String name,
  ) {
    for (final argument in creation.argumentList.arguments) {
      if (argument is NamedExpression && argument.name.label.name == name) {
        return argument;
      }
    }
    return null;
  }

  static bool _hasNonNullNamedArg(
    InstanceCreationExpression creation,
    String name,
  ) {
    final arg = _namedArgument(creation, name);
    if (arg == null) return false;
    final value = arg.expression.unParenthesized;
    if (value is NullLiteral) {
      return false;
    }
    return true;
  }

  static bool _hasAnyNonNullNamedArg(
    InstanceCreationExpression creation,
    Iterable<String> names,
  ) {
    for (final name in names) {
      if (_hasNonNullNamedArg(creation, name)) {
        return true;
      }
    }
    return false;
  }

  static SemanticNode? _findNodeByAst(
    SemanticTree tree,
    AstNode target,
  ) {
    for (final candidate in tree.physicalNodes) {
      if (identical(candidate.astNode, target)) {
        return candidate;
      }
    }
    return null;
  }

  static String? _widgetTypeName(InstanceCreationExpression expression) {
    final type = expression.staticType ?? expression.constructorName.type.type;
    if (type is InterfaceType) {
      return type.element.name;
    }
    return expression.constructorName.type.toSource();
  }
}

class A04Violation {
  A04Violation({required this.node, required this.context});

  final SemanticNode node;
  final String context;

  String get description => '$context is missing a semantic label.';
}

class _InformativeImageTarget {
  _InformativeImageTarget({
    required this.expression,
    required this.description,
  });

  final InstanceCreationExpression expression;
  final String description;
}
