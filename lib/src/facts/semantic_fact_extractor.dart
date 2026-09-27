import 'package:analyzer/dart/ast/ast.dart';

import '../semantics/semantic_node.dart';
import '../semantics/semantic_tree.dart';
import '../semantics/known_semantics.dart';
import 'fact_store.dart';

enum LabelState { unknown, absent, dynamic, static }

/// Converts the semantic IR into general-purpose facts. Query code must not
/// inspect analyzer nodes or widget constructor syntax directly.
class SemanticFactExtractor {
  ExtractedSemanticFacts extract(SemanticTree tree) {
    var store = AccessibilityFactStore.empty();
    final labelStates = <int, LabelState>{};
    final slots = <int, Map<String, int>>{};
    final properties = <int, Map<String, Object?>>{};

    for (final node in tree.physicalNodes) {
      final id = node.id!;
      store = store.addNode(
        FactNode(
          id: id,
          widgetType: node.widgetType,
          branchPath: node.branchPath,
        ),
      );
      final labelState = _labelState(node);
      labelStates[id] = labelState;
      store = store
          .add(SemanticFact(
              nodeId: id,
              name: 'labelState',
              value: labelState.name,
              provenance: FactProvenance.exact))
          .add(SemanticFact(
              nodeId: id,
              name: 'labelSource',
              value: node.labelSource.name,
              provenance: FactProvenance.exact))
          .add(SemanticFact(
              nodeId: id,
              name: 'role',
              value: node.role.name,
              provenance: node.isHeuristic
                  ? FactProvenance.heuristic
                  : FactProvenance.exact))
          .add(SemanticFact(
              nodeId: id,
              name: 'controlKind',
              value: node.controlKind.name,
              provenance: node.isHeuristic
                  ? FactProvenance.heuristic
                  : FactProvenance.exact))
          .add(SemanticFact(
              nodeId: id,
              name: 'enabled',
              value: node.isEnabled,
              provenance: FactProvenance.exact))
          .add(SemanticFact(
              nodeId: id,
              name: 'focusable',
              value: node.isFocusable,
              provenance: FactProvenance.exact))
          .add(SemanticFact(
              nodeId: id,
              name: 'tap',
              value: node.hasTap,
              provenance: FactProvenance.exact))
          .add(SemanticFact(
              nodeId: id,
              name: 'longPress',
              value: node.hasLongPress,
              provenance: FactProvenance.exact))
          .add(SemanticFact(
              nodeId: id,
              name: 'mergesDescendants',
              value: node.mergesDescendants,
              provenance: FactProvenance.exact))
          .add(SemanticFact(
              nodeId: id,
              name: 'excludesDescendants',
              value: node.excludesDescendants,
              provenance: FactProvenance.exact))
          .add(SemanticFact(
              nodeId: id,
              name: 'semanticBoundary',
              value: node.isSemanticBoundary,
              provenance: FactProvenance.exact));
      if (node.parentId != null) {
        store = store.addParent(parentId: node.parentId!, childId: id);
      }
      slots[id] = {
        for (final entry in node.slots.entries)
          if (entry.value.id != null) entry.key: entry.value.id!,
      };
      for (final entry in slots[id]!.entries) {
        store =
            store.addSlot(parentId: id, name: entry.key, childId: entry.value);
      }
      final nodeProperties = <String, Object?>{};
      for (final name in node.attributeNames) {
        final value = _literalValue(node.getAttribute(name));
        if (value != null) {
          nodeProperties[name] = value;
          store = store.add(SemanticFact(
            nodeId: id,
            name: 'property:$name',
            value: value,
            provenance: FactProvenance.exact,
          ));
        }
      }
      final visibility = _visibilityState(node, nodeProperties);
      if (visibility != null) {
        nodeProperties['visibilityState'] = visibility;
        store = store.add(SemanticFact(
          nodeId: id,
          name: 'visibilityState',
          value: visibility,
          provenance: FactProvenance.exact,
        ));
      }
      properties[id] = nodeProperties;
      for (final fact in _imageFacts(node)) {
        store = store.add(SemanticFact(
          nodeId: id,
          name: fact.$1,
          value: fact.$2,
          provenance: FactProvenance.exact,
        ));
      }
    }
    return ExtractedSemanticFacts(store, labelStates, slots, properties);
  }

  Iterable<(String, Object)> _imageFacts(SemanticNode node) sync* {
    if (node.widgetType == 'CircleAvatar') {
      final background = node.getAttribute('backgroundImage');
      // A variable or property expression may evaluate to null at runtime.
      // Only a directly constructed provider establishes image presence.
      yield ('hasImageContent', background is InstanceCreationExpression);
      return;
    }
    if (node.widgetType != 'Image' ||
        node.astNode is! InstanceCreationExpression) {
      return;
    }
    final creation = node.astNode as InstanceCreationExpression;
    final constructor = creation.constructorName.name?.name;
    const kinds = {'asset', 'network', 'file', 'memory'};
    if (!kinds.contains(constructor)) return;
    yield ('hasImageContent', true);
    yield ('imageSourceKind', constructor!);
    final exclusion = node.getAttribute('excludeFromSemantics');
    if (exclusion is BooleanLiteral) {
      if (!exclusion.value) {
        yield ('isDefinitelyNotExcludedFromSemantics', true);
      }
    } else if (exclusion == null) {
      // Flutter Image constructors default excludeFromSemantics to false.
      yield ('isDefinitelyNotExcludedFromSemantics', true);
    }
    if (constructor == 'asset' && creation.argumentList.arguments.isNotEmpty) {
      final first = creation.argumentList.arguments.first;
      final expression = first is NamedExpression ? first.expression : first;
      final assetName = _literalValue(expression);
      if (assetName is String) {
        final decorative = RegExp(
          r'(background|bg|backdrop|decor|decorative|pattern|wallpaper|divider|separator)',
          caseSensitive: false,
        ).hasMatch(assetName);
        if (decorative) yield ('isDecorativeAssetName', true);
      }
    }
  }

  LabelState _labelState(SemanticNode node) {
    switch (node.labelGuarantee) {
      case LabelGuarantee.hasStaticLabel:
        return LabelState.static;
      case LabelGuarantee.hasLabelButDynamic:
        return LabelState.dynamic;
      case LabelGuarantee.none:
        return node.isHeuristic ||
                (node.role == SemanticRole.unknown &&
                    node.controlKind == ControlKind.none)
            ? LabelState.unknown
            : LabelState.absent;
    }
  }

  Object? _literalValue(Expression? expression) {
    if (expression is BooleanLiteral) return expression.value;
    if (expression is IntegerLiteral) return expression.value;
    if (expression is SimpleStringLiteral) return expression.value;
    return null;
  }

  String? _visibilityState(SemanticNode node, Map<String, Object?> properties) {
    if (node.excludesDescendants) return 'excluded';
    if (node.widgetType == 'Offstage' && properties['offstage'] == true)
      return 'hidden';
    if (node.widgetType == 'Visibility' && properties['visible'] == false)
      return 'hidden';
    return null;
  }
}

class ExtractedSemanticFacts {
  const ExtractedSemanticFacts(
      this.store, this._labelStates, this._slots, this._properties);

  final AccessibilityFactStore store;
  final Map<int, LabelState> _labelStates;
  final Map<int, Map<String, int>> _slots;
  final Map<int, Map<String, Object?>> _properties;

  LabelState labelStateFor(int nodeId) =>
      _labelStates[nodeId] ?? LabelState.unknown;
  Map<String, int> slotsFor(int nodeId) => _slots[nodeId] ?? const {};
  Object? propertyValueFor(int nodeId, String name) =>
      _properties[nodeId]?[name];
}
