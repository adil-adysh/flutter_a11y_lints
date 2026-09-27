import 'package:analyzer/dart/ast/ast.dart';

import '../semantics/semantic_node.dart';
import '../semantics/semantic_tree.dart';
import '../semantics/known_semantics.dart';
import 'fact_store.dart';

enum LabelState { unknown, absent, dynamic, static }

enum EffectiveNameState { unknown, absent, dynamic, static }

enum EnabledState { unknown, enabled, disabled }

enum FocusableState { unknown, focusable, notFocusable }

enum VisibilityState { unknown, visible, hidden }

/// Converts the semantic IR into general-purpose facts. Query code must not
/// inspect analyzer nodes or widget constructor syntax directly.
class SemanticFactExtractor {
  ExtractedSemanticFacts extract(SemanticTree tree) {
    var store = AccessibilityFactStore.empty();
    final labelStates = <int, LabelState>{};
    final effectiveNameStates = <int, EffectiveNameState>{};
    final enabledStates = <int, EnabledState>{};
    final focusableStates = <int, FocusableState>{};
    final visibilityStates = <int, VisibilityState>{};
    final exposureStates = <int, SemanticExposureState>{};
    final inclusionStates = <int, SemanticInclusionState>{};
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
      enabledStates[id] = node.isHeuristic
          ? EnabledState.unknown
          : node.isEnabled
              ? EnabledState.enabled
              : EnabledState.disabled;
      focusableStates[id] = node.isHeuristic
          ? FocusableState.unknown
          : node.isFocusable
              ? FocusableState.focusable
              : FocusableState.notFocusable;
      exposureStates[id] = node.exposureState;
      inclusionStates[id] = node.inclusionState;
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
              name: 'enabledState',
              value: enabledStates[id]!.name,
              provenance: FactProvenance.exact))
          .add(SemanticFact(
              nodeId: id,
              name: 'focusable',
              value: node.isFocusable,
              provenance: FactProvenance.exact))
          .add(SemanticFact(
              nodeId: id,
              name: 'focusableState',
              value: focusableStates[id]!.name,
              provenance: FactProvenance.exact))
          .add(SemanticFact(
              nodeId: id,
              name: 'semanticExposureState',
              value: exposureStates[id]!.name,
              provenance: node.isHeuristic
                  ? FactProvenance.heuristic
                  : exposureStates[id] == SemanticExposureState.unknown
                      ? FactProvenance.derived
                      : FactProvenance.exact))
          .add(SemanticFact(
              nodeId: id,
              name: 'semanticInclusionState',
              value: inclusionStates[id]!.name,
              provenance: node.isHeuristic
                  ? FactProvenance.heuristic
                  : inclusionStates[id] == SemanticInclusionState.unknown
                      ? FactProvenance.derived
                      : FactProvenance.exact))
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
      if (node.widgetType == 'Semantics') {
        store = store
            .add(SemanticFact(
              nodeId: id,
              name: 'semanticsContainerState',
              value: node.semanticsConfig.container.name,
              provenance: FactProvenance.exact,
            ))
            .add(SemanticFact(
              nodeId: id,
              name: 'semanticsExplicitChildNodesState',
              value: node.semanticsConfig.explicitChildNodes.name,
              provenance: FactProvenance.exact,
            ))
            .add(SemanticFact(
              nodeId: id,
              name: 'semanticsExcludeState',
              value: node.semanticsConfig.excludeSemantics.name,
              provenance: FactProvenance.exact,
            ))
            .add(SemanticFact(
              nodeId: id,
              name: 'semanticsBlockUserActionsState',
              value: node.semanticsConfig.blockUserActions.name,
              provenance: FactProvenance.exact,
            ))
            .add(SemanticFact(
              nodeId: id,
              name: 'semanticsLabelArgumentState',
              value: node.semanticsLabelArgumentState.name,
              provenance: FactProvenance.exact,
            ))
            .add(SemanticFact(
              nodeId: id,
              name: 'semanticsButtonState',
              value: _nullableBoolState(node.getAttribute('button')),
              provenance: FactProvenance.exact,
            ));
        if (node.semanticsLabelArgumentState ==
            SemanticsLabelArgumentState.static) {
          store = store.add(SemanticFact(
            nodeId: id,
            name: 'hasExplicitSemanticsLabel',
            value: true,
            provenance: FactProvenance.exact,
          ));
        }
        if (_nullableBoolState(node.getAttribute('button')) == 'true') {
          store = store.add(SemanticFact(
            nodeId: id,
            name: 'hasExplicitSemanticsButtonRole',
            value: true,
            provenance: FactProvenance.exact,
          ));
        }
        if (node.semanticsConfig.excludeSemantics == KnownBool.no) {
          store = store.add(SemanticFact(
            nodeId: id,
            name: 'isDefinitelyNotExcludingDescendants',
            value: true,
            provenance: FactProvenance.exact,
          ));
        }
        if (node.nodeCreation == SemanticNodeCreation.createsNode) {
          store = store.add(SemanticFact(
            nodeId: id,
            name: 'createsSemanticContainer',
            value: true,
            provenance: FactProvenance.derived,
          ));
        }
        if (node.childContribution ==
            ChildContributionPolicy.mustRemainExplicit) {
          store = store.add(SemanticFact(
            nodeId: id,
            name: 'requiresExplicitChildNodes',
            value: true,
            provenance: FactProvenance.derived,
          ));
        }
        if (node.descendantReplacement == DescendantReplacementState.replaced) {
          store = store.add(SemanticFact(
            nodeId: id,
            name: 'replacesDescendantSemantics',
            value: true,
            provenance: FactProvenance.derived,
          ));
        }
        if (node.semanticsConfig.blockUserActions == KnownBool.yes) {
          store = store.add(SemanticFact(
            nodeId: id,
            name: 'blocksSemanticUserActions',
            value: true,
            provenance: FactProvenance.derived,
          ));
        }
      }
      if (node.widgetType == 'ExcludeSemantics' && node.excludesDescendants) {
        store = store.add(SemanticFact(
          nodeId: id,
          name: 'isDefinitelyExcludingDescendants',
          value: true,
          provenance: FactProvenance.exact,
        ));
      }
      final visibility = _visibilityState(node, nodeProperties);
      visibilityStates[id] = node.isHeuristic
          ? VisibilityState.unknown
          : visibility == null
              ? VisibilityState.visible
              : VisibilityState.hidden;
      store = store.add(SemanticFact(
        nodeId: id,
        name: 'visibilityStateTyped',
        value: visibilityStates[id]!.name,
        provenance: FactProvenance.exact,
      ));
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
    for (final node in tree.physicalNodes) {
      final id = node.id!;
      final effective = _effectiveNameState(node, tree, labelStates);
      effectiveNameStates[id] = effective.$1;
      store = store.add(SemanticFact(
        nodeId: id,
        name: 'effectiveNameState',
        value: effective.$1.name,
        provenance: effective.$2,
      ));
    }
    return ExtractedSemanticFacts(
        store,
        labelStates,
        effectiveNameStates,
        enabledStates,
        focusableStates,
        visibilityStates,
        exposureStates,
        inclusionStates,
        slots,
        properties);
  }

  (EffectiveNameState, FactProvenance) _effectiveNameState(
    SemanticNode node,
    SemanticTree tree,
    Map<int, LabelState> labels,
  ) {
    final parentId = node.parentId;
    final parent = parentId == null ? null : tree.byId[parentId];
    if (parent?.widgetType == 'Semantics') {
      final state = labels[parentId] ?? LabelState.unknown;
      if (state == LabelState.static || state == LabelState.dynamic) {
        // A wrapper label is evidence about the wrapper itself, not proof that
        // this physical child has the same final accessible name.
        return (EffectiveNameState.unknown, FactProvenance.derived);
      }
      if (parent!.descendantReplacement !=
          DescendantReplacementState.preserved) {
        return (EffectiveNameState.unknown, FactProvenance.derived);
      }
    } else if (parentId != null) {
      var ancestorId = parent?.parentId;
      while (ancestorId != null) {
        final ancestor = tree.byId[ancestorId];
        if (ancestor?.widgetType == 'Semantics') {
          return (EffectiveNameState.unknown, FactProvenance.derived);
        }
        ancestorId = ancestor?.parentId;
      }
    }
    return (
      switch (labels[node.id!]) {
        LabelState.static => EffectiveNameState.static,
        LabelState.dynamic => EffectiveNameState.dynamic,
        LabelState.absent => EffectiveNameState.absent,
        _ => EffectiveNameState.unknown,
      },
      FactProvenance.exact,
    );
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

  String _nullableBoolState(Expression? expression) {
    if (expression is BooleanLiteral)
      return expression.value ? 'true' : 'false';
    return 'unknown';
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
      this.store,
      this._labelStates,
      this._effectiveNameStates,
      this._enabledStates,
      this._focusableStates,
      this._visibilityStates,
      this._exposureStates,
      this._inclusionStates,
      this._slots,
      this._properties);

  final AccessibilityFactStore store;
  final Map<int, LabelState> _labelStates;
  final Map<int, EffectiveNameState> _effectiveNameStates;
  final Map<int, EnabledState> _enabledStates;
  final Map<int, FocusableState> _focusableStates;
  final Map<int, VisibilityState> _visibilityStates;
  final Map<int, SemanticExposureState> _exposureStates;
  final Map<int, SemanticInclusionState> _inclusionStates;
  final Map<int, Map<String, int>> _slots;
  final Map<int, Map<String, Object?>> _properties;

  LabelState labelStateFor(int nodeId) =>
      _labelStates[nodeId] ?? LabelState.unknown;
  EffectiveNameState effectiveNameStateFor(int nodeId) =>
      _effectiveNameStates[nodeId] ?? EffectiveNameState.unknown;
  EnabledState enabledStateFor(int nodeId) =>
      _enabledStates[nodeId] ?? EnabledState.unknown;
  FocusableState focusableStateFor(int nodeId) =>
      _focusableStates[nodeId] ?? FocusableState.unknown;
  VisibilityState visibilityStateFor(int nodeId) =>
      _visibilityStates[nodeId] ?? VisibilityState.unknown;
  SemanticExposureState exposureStateFor(int nodeId) =>
      _exposureStates[nodeId] ?? SemanticExposureState.unknown;
  SemanticInclusionState inclusionStateFor(int nodeId) =>
      _inclusionStates[nodeId] ?? SemanticInclusionState.unknown;
  Map<String, int> slotsFor(int nodeId) => _slots[nodeId] ?? const {};
  Object? propertyValueFor(int nodeId, String name) =>
      _properties[nodeId]?[name];
}
