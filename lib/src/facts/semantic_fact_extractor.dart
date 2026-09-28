import 'package:analyzer/dart/ast/ast.dart';

import '../semantics/semantic_node.dart';
import '../semantics/semantic_tree.dart';
import '../semantics/accessibility_tree_approximation.dart';
import '../semantics/known_semantics.dart';
import 'fact_store.dart';
import 'model/composition_facts.dart';
import 'model/evidence.dart'
    show FactEvidence, KnowledgeState, SourceSpan;
import 'model/exposure_facts.dart' as typed_exposure;
import 'model/image_facts.dart' as typed_images;
import 'model/naming_facts.dart' as typed_naming;
import 'model/role_action_facts.dart' as typed_actions;
import 'model/state_facts.dart' as typed_states;
import 'model/structure_facts.dart';
import 'model/typed_node_facts.dart';
import 'model/value_input_facts.dart' as typed_values;

enum LabelState { unknown, absent, dynamic, static }

enum EffectiveNameState { unknown, absent, dynamic, static }

enum EnabledState { unknown, enabled, disabled }

enum FocusableState { unknown, focusable, notFocusable }

enum VisibilityState { unknown, visible, hidden }

/// Converts the semantic IR into general-purpose facts. Query code must not
/// inspect analyzer nodes or widget constructor syntax directly.
class SemanticFactExtractor {
  ExtractedSemanticFacts extract(SemanticTree tree) {
    final accessibility = AccessibilityTreeApproximation.fromSemanticTree(tree);
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
    final compositionFacts = <int, CompositionFact>{};
    final nameFacts = <int, typed_naming.NameFact>{};
    final controlStateFacts = <int, typed_states.ControlStateFact>{};
    final actionFacts = <int, List<typed_actions.SemanticActionFact>>{};
    final exposureFacts = <int, typed_exposure.ExposureFact>{};
    final roleFacts = <int, typed_actions.RoleFact>{};
    final imageFacts = <int, typed_images.ImageFact>{};
    final valueInputFacts = <int, typed_values.ValueInputFact>{};
    final sourceNodes = <SourceWidgetNode>[];
    final sourceChildren = <SourceWidgetChildEdge>[];
    final slotEdges = <NamedSlotEdge>[];
    final compositionNodes = <SemanticCompositionNode>[];
    final compositionChildren = <SemanticCompositionChildEdge>[];
    final accessibilityNodes = <AccessibilityNode>[];

    for (final node in tree.physicalNodes) {
      final id = node.id!;
      final nodeProvenance = _nodeProvenance(node);
      final evidence = FactEvidence(
        provenance: nodeProvenance,
        knowledge: KnowledgeState.known,
        sources: [SourceSpan(node.fileUri.toString(), node.offset, node.length)],
      );
      store = store.addNode(
        FactNode(
          id: id,
          widgetType: node.widgetType,
          branchPath: node.branchPath,
          source: SourceSpan(
            node.fileUri.toString(),
            node.offset,
            node.length,
          ),
        ),
      );
      sourceNodes.add(SourceWidgetNode(
        id: id,
        widgetType: node.widgetType,
        evidence: evidence,
        branchPath: node.branchPath,
      ));
      compositionNodes.add(SemanticCompositionNode(
        id: id,
        sourceWidgetId: id,
        evidence: evidence,
        branchPath: node.branchPath,
      ));
      compositionFacts[id] = _compositionFact(node, evidence);
      roleFacts[id] = _roleFact(node, evidence);
      final imageFact = _imageFact(node, evidence);
      if (imageFact != null) imageFacts[id] = imageFact;
      valueInputFacts[id] = _valueInputFact(node, evidence);
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
              provenance: nodeProvenance))
          .add(SemanticFact(
              nodeId: id,
              name: 'labelSource',
              value: node.labelSource.name,
              provenance: nodeProvenance))
          .add(SemanticFact(
              nodeId: id,
              name: 'role',
              value: node.role.name,
              provenance: nodeProvenance))
          .add(SemanticFact(
              nodeId: id,
              name: 'controlKind',
              value: node.controlKind.name,
              provenance: nodeProvenance))
          .add(SemanticFact(
              nodeId: id,
              name: 'enabled',
              value: node.isEnabled,
              provenance: nodeProvenance))
          .add(SemanticFact(
              nodeId: id,
              name: 'enabledState',
              value: enabledStates[id]!.name,
              provenance: nodeProvenance))
          .add(SemanticFact(
              nodeId: id,
              name: 'focusable',
              value: node.isFocusable,
              provenance: nodeProvenance))
          .add(SemanticFact(
              nodeId: id,
              name: 'focusableState',
              value: focusableStates[id]!.name,
              provenance: nodeProvenance))
          .add(SemanticFact(
              nodeId: id,
              name: 'semanticExposureState',
              value: exposureStates[id]!.name,
              provenance: _withIntrinsicProvenance(
                node,
                exposureStates[id] == SemanticExposureState.unknown
                    ? FactProvenance.derived
                    : FactProvenance.exact,
              )))
          .add(SemanticFact(
              nodeId: id,
              name: 'semanticInclusionState',
              value: inclusionStates[id]!.name,
              provenance: _withIntrinsicProvenance(
                node,
                inclusionStates[id] == SemanticInclusionState.unknown
                    ? FactProvenance.derived
                    : FactProvenance.exact,
              )))
          .add(SemanticFact(
              nodeId: id,
              name: 'tap',
              value: node.hasTap,
              provenance: nodeProvenance))
          .add(SemanticFact(
              nodeId: id,
              name: 'longPress',
              value: node.hasLongPress,
              provenance: nodeProvenance))
          .add(SemanticFact(
              nodeId: id,
              name: 'mergesDescendants',
              value: node.mergesDescendants,
              provenance: nodeProvenance))
          .add(SemanticFact(
              nodeId: id,
              name: 'excludesDescendants',
              value: node.excludesDescendants,
              provenance: nodeProvenance))
          .add(SemanticFact(
              nodeId: id,
              name: 'semanticBoundary',
              value: node.isSemanticBoundary,
              provenance: nodeProvenance));
      if (node.parentId != null) {
        store = store.addParent(parentId: node.parentId!, childId: id);
        sourceChildren.add(
          SourceWidgetChildEdge(parentId: node.parentId!, childId: id),
        );
        compositionChildren.add(
          SemanticCompositionChildEdge(parentId: node.parentId!, childId: id),
        );
      }
      slots[id] = {
        for (final entry in node.slots.entries)
          if (entry.value.id != null) entry.key: entry.value.id!,
      };
      for (final entry in slots[id]!.entries) {
        store =
            store.addSlot(parentId: id, name: entry.key, childId: entry.value);
        slotEdges.add(
          NamedSlotEdge(parentId: id, name: entry.key, childId: entry.value),
        );
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
            provenance: nodeProvenance,
          ));
        }
      }
      if (node.widgetType == 'Semantics') {
        store = store
            .add(SemanticFact(
              nodeId: id,
              name: 'semanticsContainerState',
              value: node.semanticsConfig.container.name,
              provenance: nodeProvenance,
            ))
            .add(SemanticFact(
              nodeId: id,
              name: 'semanticsExplicitChildNodesState',
              value: node.semanticsConfig.explicitChildNodes.name,
              provenance: nodeProvenance,
            ))
            .add(SemanticFact(
              nodeId: id,
              name: 'semanticsExcludeState',
              value: node.semanticsConfig.excludeSemantics.name,
              provenance: nodeProvenance,
            ))
            .add(SemanticFact(
              nodeId: id,
              name: 'semanticsBlockUserActionsState',
              value: node.semanticsConfig.blockUserActions.name,
              provenance: nodeProvenance,
            ))
            .add(SemanticFact(
              nodeId: id,
              name: 'semanticsLabelArgumentState',
              value: node.semanticsLabelArgumentState.name,
              provenance: nodeProvenance,
            ))
            .add(SemanticFact(
              nodeId: id,
              name: 'semanticsButtonState',
              value: _nullableBoolState(node.getAttribute('button')),
              provenance: nodeProvenance,
            ));
        if (node.semanticsLabelArgumentState ==
            SemanticsLabelArgumentState.static) {
          store = store.add(SemanticFact(
            nodeId: id,
            name: 'hasExplicitSemanticsLabel',
            value: true,
            provenance: nodeProvenance,
          ));
        }
        if (_nullableBoolState(node.getAttribute('button')) == 'true') {
          store = store.add(SemanticFact(
            nodeId: id,
            name: 'hasExplicitSemanticsButtonRole',
            value: true,
            provenance: nodeProvenance,
          ));
        }
        if (node.semanticsConfig.excludeSemantics == KnownBool.no) {
          store = store.add(SemanticFact(
            nodeId: id,
            name: 'isDefinitelyNotExcludingDescendants',
            value: true,
            provenance: nodeProvenance,
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
          provenance: nodeProvenance,
        ));
      }
      final visibility = _visibilityState(node, nodeProperties);
      visibilityStates[id] = node.isHeuristic
          ? VisibilityState.unknown
          : visibility == null
              ? VisibilityState.visible
              : VisibilityState.hidden;
      nameFacts[id] = _nameFact(node, labelState, nodeProvenance);
      controlStateFacts[id] = typed_states.ControlStateFact(
        enabled: switch (enabledStates[id]!) {
          EnabledState.enabled => typed_states.EnabledState.enabled,
          EnabledState.disabled => typed_states.EnabledState.disabled,
          EnabledState.unknown => typed_states.EnabledState.unknown,
        },
        focusable: switch (focusableStates[id]!) {
          FocusableState.focusable => typed_states.FocusableState.focusable,
          FocusableState.notFocusable => typed_states.FocusableState.notFocusable,
          FocusableState.unknown => typed_states.FocusableState.unknown,
        },
        evidence: evidence,
      );
      actionFacts[id] = _actionFacts(node, evidence);
      exposureFacts[id] = typed_exposure.ExposureFact(
        visual: switch (visibilityStates[id]!) {
          VisibilityState.visible => typed_exposure.VisualVisibilityState.visible,
          VisibilityState.hidden =>
            typed_exposure.VisualVisibilityState.visuallyHidden,
          VisibilityState.unknown => typed_exposure.VisualVisibilityState.unknown,
        },
        semantic: switch (inclusionStates[id]!) {
          SemanticInclusionState.included =>
            typed_exposure.SemanticInclusionState.included,
          SemanticInclusionState.excluded =>
            typed_exposure.SemanticInclusionState.excluded,
          SemanticInclusionState.unknown =>
            typed_exposure.SemanticInclusionState.unknown,
        },
        focus: switch (exposureStates[id]!) {
          SemanticExposureState.exposed =>
            typed_exposure.AccessibilityFocusExposureState.exposed,
          SemanticExposureState.hidden =>
            typed_exposure.AccessibilityFocusExposureState.blocked,
          SemanticExposureState.unknown =>
            typed_exposure.AccessibilityFocusExposureState.unknown,
        },
        evidence: evidence,
      );
      store = store.add(SemanticFact(
        nodeId: id,
        name: 'visibilityStateTyped',
        value: visibilityStates[id]!.name,
        provenance: nodeProvenance,
      ));
      if (visibility != null) {
        nodeProperties['visibilityState'] = visibility;
        store = store.add(SemanticFact(
          nodeId: id,
          name: 'visibilityState',
          value: visibility,
          provenance: nodeProvenance,
        ));
      }
      properties[id] = nodeProperties;
      for (final fact in _imageFacts(node)) {
        store = store.add(SemanticFact(
          nodeId: id,
          name: fact.$1,
          value: fact.$2,
          provenance: nodeProvenance,
        ));
      }
      // An accessibility node requires both semantic participation and proven
      // exposure. A merged descendant can still contribute to its parent's
      // semantics, but is not independently represented in this projection.
      if (accessibility.forSemanticNode(id) != null) {
        accessibilityNodes.add(AccessibilityNode(
          id: id,
          compositionNodeId: id,
          evidence: evidence,
          branchPath: node.branchPath,
        ));
      }
    }
    final accessibleIds = accessibilityNodes.map((node) => node.id).toSet();
    final accessibilityChildren = <AccessibilityChildEdge>[];
    for (final node in tree.physicalNodes) {
      final parentId = node.parentId;
      if (parentId == null ||
          !accessibleIds.contains(parentId) ||
          !accessibleIds.contains(node.id)) {
        continue;
      }
      final parent = tree.byId[parentId];
      if (parent == null ||
          parent.mergeState == SemanticMergeState.merged ||
          parent.descendantReplacement != DescendantReplacementState.preserved) {
        continue;
      }
      accessibilityChildren.add(
        AccessibilityChildEdge(parentId: parentId, childId: node.id!),
      );
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
    for (final node in tree.physicalNodes) {
      final id = node.id!;
      store = store.addTyped(
        id,
        TypedNodeFacts(
          composition: compositionFacts[id],
          name: nameFacts[id],
          controlState: controlStateFacts[id],
          exposure: exposureFacts[id],
          role: roleFacts[id],
          image: imageFacts[id],
          valueInput: valueInputFacts[id],
          actions: actionFacts[id] ?? const [],
        ),
      );
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
        properties,
        compositionFacts,
        nameFacts,
        controlStateFacts,
        actionFacts,
        exposureFacts,
        accessibility,
        AccessibilityFactGraph(
          sourceNodes: sourceNodes,
          sourceChildren: sourceChildren,
          slots: slotEdges,
          compositionNodes: compositionNodes,
          compositionChildren: compositionChildren,
          accessibilityNodes: accessibilityNodes,
          accessibilityChildren: accessibilityChildren,
        ));
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
      _nodeProvenance(node),
    );
  }

  FactProvenance _nodeProvenance(SemanticNode node) =>
      _withIntrinsicProvenance(node, FactProvenance.exact);

  FactProvenance _withIntrinsicProvenance(
    SemanticNode node,
    FactProvenance intrinsic,
  ) {
    if (node.isHeuristic) return FactProvenance.heuristic;
    if (node.factProvenance != FactProvenance.exact) {
      return node.factProvenance;
    }
    return intrinsic;
  }

  CompositionFact _compositionFact(
    SemanticNode node,
    FactEvidence evidence,
  ) {
    KnownBooleanFact boolFact(
      KnownBool state,
      SemanticsArgumentOrigin origin,
    ) =>
        KnownBooleanFact(
          state: switch (state) {
            KnownBool.yes => KnownBooleanState.trueValue,
            KnownBool.no => KnownBooleanState.falseValue,
            KnownBool.unknown => KnownBooleanState.unknown,
          },
          origin: switch (origin) {
            SemanticsArgumentOrigin.defaultValue =>
              ArgumentEvidenceOrigin.defaultValue,
            SemanticsArgumentOrigin.literal => ArgumentEvidenceOrigin.literal,
            SemanticsArgumentOrigin.resolved =>
              ArgumentEvidenceOrigin.resolved,
            SemanticsArgumentOrigin.dynamic => ArgumentEvidenceOrigin.dynamic,
          },
        );

    return CompositionFact(
      nodeCreation: switch (node.nodeCreation) {
        SemanticNodeCreation.createsNode => NodeCreationState.createsNode,
        SemanticNodeCreation.noNewNode => NodeCreationState.noNewNode,
        SemanticNodeCreation.unknown => NodeCreationState.unknown,
      },
      childContribution: switch (node.childContribution) {
        ChildContributionPolicy.mayContributeToParent =>
          ChildContributionState.mayContribute,
        ChildContributionPolicy.mustRemainExplicit =>
          ChildContributionState.mustRemainExplicit,
        ChildContributionPolicy.unknown => ChildContributionState.unknown,
      },
      descendantDisposition: switch (node.descendantReplacement) {
        DescendantReplacementState.preserved => DescendantDisposition.preserved,
        DescendantReplacementState.replaced => DescendantDisposition.replaced,
        DescendantReplacementState.excluded => DescendantDisposition.excluded,
        DescendantReplacementState.unknown => DescendantDisposition.unknown,
      },
      merge: switch (node.mergeState) {
        SemanticMergeState.notMerged => MergeState.notMerged,
        SemanticMergeState.merged => MergeState.merged,
        SemanticMergeState.unknown => MergeState.unknown,
      },
      blocksUserActions: boolFact(
        node.semanticsConfig.blockUserActions,
        node.semanticsConfig.blockUserActionsOrigin,
      ),
      rawSemanticsConfiguration: node.widgetType == 'Semantics'
          ? RawSemanticsConfigurationFact(
              container: boolFact(
                node.semanticsConfig.container,
                node.semanticsConfig.containerOrigin,
              ),
              explicitChildNodes: boolFact(
                node.semanticsConfig.explicitChildNodes,
                node.semanticsConfig.explicitChildNodesOrigin,
              ),
              excludeSemantics: boolFact(
                node.semanticsConfig.excludeSemantics,
                node.semanticsConfig.excludeSemanticsOrigin,
              ),
              blockUserActions: boolFact(
                node.semanticsConfig.blockUserActions,
                node.semanticsConfig.blockUserActionsOrigin,
              ),
            )
          : null,
      evidence: evidence,
    );
  }

  typed_naming.NameFact _nameFact(
    SemanticNode node,
    LabelState state,
    FactProvenance provenance,
  ) {
    final knowledge = switch (state) {
      LabelState.static || LabelState.absent => KnowledgeState.known,
      LabelState.dynamic => KnowledgeState.dynamic,
      LabelState.unknown => KnowledgeState.unknown,
    };
    return typed_naming.NameFact(
      state: switch (state) {
        LabelState.static => typed_naming.NameState.static,
        LabelState.absent => typed_naming.NameState.absent,
        LabelState.dynamic => typed_naming.NameState.dynamic,
        LabelState.unknown => typed_naming.NameState.unknown,
      },
      source: switch (node.labelSource) {
        LabelSource.semanticsWidget => typed_naming.NameSource.semanticsLabel,
        LabelSource.tooltip => typed_naming.NameSource.tooltip,
        LabelSource.textChild => typed_naming.NameSource.textChild,
        LabelSource.inputDecoration => typed_naming.NameSource.inputDecoration,
        LabelSource.customWidgetParameter =>
          typed_naming.NameSource.customWidgetDerived,
        LabelSource.none || LabelSource.valueToString || LabelSource.other =>
          null,
      },
      value: state == LabelState.static ? node.label : null,
      evidence: FactEvidence(
        provenance: provenance,
        knowledge: knowledge,
        sources: [SourceSpan(node.fileUri.toString(), node.offset, node.length)],
      ),
    );
  }

  List<typed_actions.SemanticActionFact> _actionFacts(
    SemanticNode node,
    FactEvidence evidence,
  ) {
    typed_actions.ActionAvailability availability(
      bool knownAction,
      List<String> callbackNames,
    ) {
      if (node.isHeuristic) return typed_actions.ActionAvailability.unknown;
      if (!knownAction) return typed_actions.ActionAvailability.absent;
      Expression? callback;
      for (final name in callbackNames) {
        callback = node.getAttribute(name);
        if (callback != null) break;
      }
      if (callback == null || callback is NullLiteral) {
        return typed_actions.ActionAvailability.absent;
      }
      if (callback is FunctionExpression) {
        return typed_actions.ActionAvailability.present;
      }
      // A resolved identifier, tear-off, callback field, or arbitrary
      // expression can still evaluate to null at runtime.
      return typed_actions.ActionAvailability.dynamic;
    }

    return [
      typed_actions.SemanticActionFact(
        kind: typed_actions.ActionKind.tap,
        availability: availability(node.hasTap, const [
          'onTap',
          'onPressed',
          'onChanged',
        ]),
        evidence: evidence,
      ),
      typed_actions.SemanticActionFact(
        kind: typed_actions.ActionKind.longPress,
        availability: availability(node.hasLongPress, const ['onLongPress']),
        evidence: evidence,
      ),
      typed_actions.SemanticActionFact(
        kind: typed_actions.ActionKind.increase,
        availability: availability(node.hasIncrease, const ['onIncrease']),
        evidence: evidence,
      ),
      typed_actions.SemanticActionFact(
        kind: typed_actions.ActionKind.decrease,
        availability: availability(node.hasDecrease, const ['onDecrease']),
        evidence: evidence,
      ),
      typed_actions.SemanticActionFact(
        kind: typed_actions.ActionKind.dismiss,
        availability: availability(node.hasDismiss, const ['onDismiss']),
        evidence: evidence,
      ),
    ];
  }

  typed_actions.RoleFact _roleFact(
    SemanticNode node,
    FactEvidence evidence,
  ) =>
      typed_actions.RoleFact(
        role: switch (node.role) {
          SemanticRole.button => typed_actions.AccessibilityRole.button,
          SemanticRole.image => typed_actions.AccessibilityRole.image,
          SemanticRole.checkbox => typed_actions.AccessibilityRole.checkbox,
          SemanticRole.switchRole => typed_actions.AccessibilityRole.switchRole,
          SemanticRole.slider => typed_actions.AccessibilityRole.slider,
          SemanticRole.textField => typed_actions.AccessibilityRole.textField,
          SemanticRole.staticText => typed_actions.AccessibilityRole.staticText,
          SemanticRole.header => typed_actions.AccessibilityRole.heading,
          SemanticRole.group => typed_actions.AccessibilityRole.group,
          SemanticRole.unknown => typed_actions.AccessibilityRole.unknown,
        },
        control: switch (node.controlKind) {
          ControlKind.none => typed_actions.ControlClassification.none,
          ControlKind.elevatedButton =>
            typed_actions.ControlClassification.elevatedButton,
          ControlKind.textButton => typed_actions.ControlClassification.textButton,
          ControlKind.filledButton =>
            typed_actions.ControlClassification.filledButton,
          ControlKind.outlinedButton =>
            typed_actions.ControlClassification.outlinedButton,
          ControlKind.iconButton => typed_actions.ControlClassification.iconButton,
          ControlKind.floatingActionButton =>
            typed_actions.ControlClassification.floatingActionButton,
          ControlKind.listTile => typed_actions.ControlClassification.listTile,
          ControlKind.checkboxControl => typed_actions.ControlClassification.checkbox,
          ControlKind.switchControl =>
            typed_actions.ControlClassification.switchControl,
          ControlKind.sliderControl => typed_actions.ControlClassification.slider,
          ControlKind.textFieldControl =>
            typed_actions.ControlClassification.textField,
        },
        evidence: evidence,
      );

  typed_images.ImageFact? _imageFact(
    SemanticNode node,
    FactEvidence evidence,
  ) {
    if (node.widgetType == 'CircleAvatar') {
      final background = node.getAttribute('backgroundImage');
      return typed_images.ImageFact(
        content: background is InstanceCreationExpression
            ? typed_images.ImageContentState.present
            : typed_images.ImageContentState.unknown,
        sourceKind: typed_images.ImageSourceKind.unknown,
        evidence: evidence,
      );
    }
    if (node.widgetType != 'Image' ||
        node.astNode is! InstanceCreationExpression) {
      return null;
    }
    final creation = node.astNode as InstanceCreationExpression;
    final constructor = creation.constructorName.name?.name;
    final sourceKind = switch (constructor) {
      'asset' => typed_images.ImageSourceKind.asset,
      'network' => typed_images.ImageSourceKind.network,
      'file' => typed_images.ImageSourceKind.file,
      'memory' => typed_images.ImageSourceKind.memory,
      _ => typed_images.ImageSourceKind.unknown,
    };
    if (sourceKind == typed_images.ImageSourceKind.unknown) return null;
    final exclusion = node.getAttribute('excludeFromSemantics');
    final explicitlyExcluded = exclusion is BooleanLiteral && exclusion.value;
    final explicitlyNotExcluded =
        exclusion is BooleanLiteral ? !exclusion.value : exclusion == null;
    String? assetPath;
    var decorative = false;
    if (sourceKind == typed_images.ImageSourceKind.asset &&
        creation.argumentList.arguments.isNotEmpty) {
      final first = creation.argumentList.arguments.first;
      final expression = first is NamedExpression ? first.expression : first;
      final value = _literalValue(expression);
      if (value is String) {
        assetPath = value;
        decorative = RegExp(
          r'(background|bg|backdrop|decor|decorative|pattern|wallpaper|divider|separator)',
          caseSensitive: false,
        ).hasMatch(value);
      }
    }
    return typed_images.ImageFact(
      content: typed_images.ImageContentState.present,
      sourceKind: sourceKind,
      staticAssetPath: assetPath,
      isKnownDecorativeAsset: decorative,
      isDefinitelyExcludedFromSemantics: explicitlyExcluded,
      isDefinitelyNotExcludedFromSemantics: explicitlyNotExcluded,
      evidence: evidence,
    );
  }

  typed_values.ValueInputFact _valueInputFact(
    SemanticNode node,
    FactEvidence evidence,
  ) {
    typed_values.TextFact textFact(Expression? expression) {
      if (expression == null) {
        return typed_values.TextFact(
          state: typed_values.TextState.absent,
          evidence: evidence,
        );
      }
      final literal = _literalValue(expression);
      if (literal is String) {
        return typed_values.TextFact(
          state: typed_values.TextState.static,
          value: literal,
          evidence: evidence,
        );
      }
      return typed_values.TextFact(
        state: typed_values.TextState.dynamic,
        evidence: FactEvidence(
          provenance: evidence.provenance,
          knowledge: KnowledgeState.dynamic,
          sources: evidence.sources,
          inputs: evidence.inputs,
        ),
      );
    }

    int? integer(String name) => _literalValue(node.getAttribute(name)) as int?;
    final value = node.getAttribute('semanticValue') ?? node.getAttribute('value');
    final hint = node.getAttribute('semanticHint') ?? node.getAttribute('hint');
    return typed_values.ValueInputFact(
      value: textFact(value),
      hint: textFact(hint),
      inputKind: node.controlKind == ControlKind.textFieldControl
          ? typed_values.InputKind.text
          : typed_values.InputKind.unknown,
      validation: typed_values.ValidationState.unknown,
      minValue: integer('minValue') ?? integer('min'),
      maxValue: integer('maxValue') ?? integer('max'),
      currentValueLength: integer('currentValueLength'),
      maxValueLength: integer('maxLength'),
      evidence: evidence,
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
      this._properties,
      this._compositionFacts,
      this._nameFacts,
      this._controlStateFacts,
      this._actionFacts,
      this._exposureFacts,
      this.accessibility,
      this.graph);

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
  final Map<int, CompositionFact> _compositionFacts;
  final Map<int, typed_naming.NameFact> _nameFacts;
  final Map<int, typed_states.ControlStateFact> _controlStateFacts;
  final Map<int, List<typed_actions.SemanticActionFact>> _actionFacts;
  final Map<int, typed_exposure.ExposureFact> _exposureFacts;

  /// Separate conservative accessibility-tree approximation.
  final AccessibilityTreeApproximation accessibility;

  /// Distinct source, semantic-composition, and accessibility projections.
  final AccessibilityFactGraph graph;

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
  CompositionFact? compositionFactFor(int nodeId) => _compositionFacts[nodeId];
  typed_naming.NameFact? nameFactFor(int nodeId) => _nameFacts[nodeId];
  typed_states.ControlStateFact? controlStateFactFor(int nodeId) =>
      _controlStateFacts[nodeId];
  List<typed_actions.SemanticActionFact> actionsFor(int nodeId) =>
      _actionFacts[nodeId] ?? const [];
  typed_exposure.ExposureFact? exposureFactFor(int nodeId) =>
      _exposureFacts[nodeId];
}
