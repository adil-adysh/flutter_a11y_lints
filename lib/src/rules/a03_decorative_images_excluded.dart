import 'package:analyzer/dart/ast/ast.dart';
// Rule: A03 — Decorative Images Excluded
//
// Purpose: Ensure decorative images are excluded from the accessibility
// tree (e.g., Image with semantic label omitted and marked as decorative).
// The rule checks `Image` semantics and `excludeSemantics` wrappers.
//
// Testing: Add tests in `test/rules/a03_decorative_images_excluded_test.dart`.
// Use the test helpers to create Image examples and assert whether
// `accessibilityFocusNodes` contains the image node.
//
// See also:
// - `lib/src/semantics/semantic_node.dart` (image semantics fields)
// - `lib/src/semantics/known_semantics.dart` (Image widget entries)
// - `test/rules/test_semantic_utils.dart` (test tree helpers)
import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_tree.dart';

/// A03: Decorative images should be excluded from semantics.
class A03DecorativeImagesExcluded {
  static const code = 'a03_decorative_images_excluded';
  static const message = 'Exclude purely decorative images from semantics';
  static const correctionMessage =
      'Set excludeFromSemantics: true or provide a semanticLabel for decorative assets.';

  static final _decorativePattern = RegExp(
    r'(background|bg|backdrop|decor|decorative|pattern|wallpaper|divider|separator)',
    caseSensitive: false,
  );

  static List<A03Violation> checkTree(SemanticTree tree) {
    final violations = <A03Violation>[];

    for (final node in tree.physicalNodes) {
      final violation = _checkNode(node, tree);
      if (violation != null) {
        violations.add(violation);
      }
    }

    return violations;
  }

  static A03Violation? _checkNode(SemanticNode node, SemanticTree tree) {
    if (node.widgetType != 'Image') return null;

    final creation = node.astNode;
    if (creation is! InstanceCreationExpression) return null;

    final constructorName = creation.constructorName.name?.name;
    if (constructorName != 'asset') return null;

    final assetPath = _extractAssetPath(creation);
    if (assetPath == null) return null;
    if (!_decorativePattern.hasMatch(assetPath)) return null;

    if (_hasSemanticLabel(creation)) {
      return null;
    }

    final excludeState = _excludeSetting(creation);
    if (excludeState == _ExcludeState.explicitTrue) {
      return null;
    }
    if (excludeState == _ExcludeState.unknownExpression) {
      return null;
    }

    if (_hasExcludeAncestor(node, tree)) {
      return null;
    }

    return A03Violation(node: node, assetPath: assetPath);
  }

  static bool _hasExcludeAncestor(SemanticNode node, SemanticTree tree) {
    var current = node;
    while (current.parentId != null) {
      final parent = tree.byId[current.parentId!];
      if (parent == null) break;
      if (parent.excludesDescendants ||
          parent.widgetType == 'ExcludeSemantics') {
        return true;
      }
      current = parent;
    }
    return false;
  }

  static String? _extractAssetPath(InstanceCreationExpression creation) {
    final arguments = creation.argumentList.arguments;
    if (arguments.isEmpty) {
      return null;
    }

    Expression? assetExpression;
    final firstArg = arguments.first;
    if (firstArg is NamedExpression) {
      if (firstArg.name.label.name == 'name') {
        assetExpression = firstArg.expression;
      }
    } else {
      assetExpression = firstArg;
    }

    return _literalString(assetExpression);
  }

  static bool _hasSemanticLabel(InstanceCreationExpression creation) {
    final arg = _namedArgument(creation, 'semanticLabel');
    if (arg == null) return false;
    if (arg.expression is NullLiteral) {
      return false;
    }
    return true;
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

  static String? _literalString(Expression? expression) {
    if (expression is SimpleStringLiteral) {
      return expression.value;
    }
    if (expression is AdjacentStrings) {
      final buffer = StringBuffer();
      for (final string in expression.strings) {
        final value = _literalString(string);
        if (value == null) {
          return null;
        }
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

  static _ExcludeState _excludeSetting(InstanceCreationExpression creation) {
    final arg = _namedArgument(creation, 'excludeFromSemantics');
    if (arg == null) {
      return _ExcludeState.notProvided;
    }

    final expression = arg.expression;
    if (expression is BooleanLiteral) {
      return expression.value
          ? _ExcludeState.explicitTrue
          : _ExcludeState.explicitFalse;
    }

    if (expression is NullLiteral) {
      return _ExcludeState.explicitFalse;
    }

    return _ExcludeState.unknownExpression;
  }
}

class A03Violation {
  A03Violation({required this.node, required this.assetPath});

  final SemanticNode node;
  final String assetPath;

  String get description =>
      'Decorative asset "$assetPath" should set excludeFromSemantics: true.';
}

enum _ExcludeState {
  notProvided,
  explicitTrue,
  explicitFalse,
  unknownExpression,
}
