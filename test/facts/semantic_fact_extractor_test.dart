import 'package:flutter_a11y_lints/src/facts/semantic_fact_extractor.dart';
import 'package:flutter_a11y_lints/src/facts/fact_store.dart';
import 'package:flutter_a11y_lints/src/facts/model/composition_facts.dart';
import 'package:flutter_a11y_lints/src/facts/model/exposure_facts.dart'
    as typed_exposure;
import 'package:flutter_a11y_lints/src/facts/model/evidence.dart'
    show KnowledgeState;
import 'package:flutter_a11y_lints/src/facts/model/form_association_facts.dart'
    as typed_forms;
import 'package:flutter_a11y_lints/src/facts/model/image_facts.dart'
    as typed_images;
import 'package:flutter_a11y_lints/src/facts/model/naming_facts.dart'
    as typed_naming;
import 'package:flutter_a11y_lints/src/facts/model/role_action_facts.dart'
    as typed_actions;
import 'package:flutter_a11y_lints/src/facts/model/relationship_facts.dart'
    as typed_relationships;
import 'package:flutter_a11y_lints/src/facts/model/state_facts.dart'
    as typed_states;
import 'package:flutter_a11y_lints/src/facts/model/value_input_facts.dart'
    as typed_values;
import 'package:flutter_a11y_lints/src/semantics/semantic_node.dart';
import 'package:flutter_a11y_lints/src/semantics/semantic_tree.dart';
import 'package:test/test.dart';

import '../rules/test_semantic_utils.dart';

void main() {
  group('SemanticFactExtractor', () {
    test('does not treat a non-replacing Semantics label as a child name',
        () async {
      final tree = await buildTestSemanticTree(
        "Semantics(label: 'Profile photo', child: Image.network('https://x'))",
      );
      final facts = SemanticFactExtractor().extract(tree);
      final image =
          tree.physicalNodes.singleWhere((node) => node.widgetType == 'Image');

      expect(
          facts.effectiveNameStateFor(image.id!), EffectiveNameState.unknown);
      expect(
        facts.store.expanded
            .factsFor(image.id!)
            .singleWhere((fact) => fact.name == 'effectiveNameState')
            .provenance,
        FactProvenance.derived,
      );
    });

    test('extracts explicit literal Semantics wrapper intent', () async {
      final tree = await buildTestSemanticTree(
        "Semantics(label: 'Save', button: true, child: Text('Save'))",
      );
      final facts = SemanticFactExtractor().extract(tree);
      final wrapper = tree.root;
      final names = facts.store.conservative
          .factsFor(wrapper.id!)
          .map((fact) => fact.name)
          .toSet();

      expect(names, contains('hasExplicitSemanticsLabel'));
      expect(names, contains('hasExplicitSemanticsButtonRole'));
      expect(names, contains('isDefinitelyNotExcludingDescendants'));
      expect(names, contains('semanticsContainerState'));
      expect(names, contains('semanticsExplicitChildNodesState'));
      expect(names, contains('semanticsExcludeState'));
      expect(names, contains('semanticsLabelArgumentState'));
    });

    test('projects raw Semantics configuration with documented defaults',
        () async {
      final tree = await buildTestSemanticTree('''
Semantics(
  container: true,
  blockUserActions: false,
  child: Text('Save'),
)
''');
      final composition = SemanticFactExtractor()
          .extract(tree)
          .compositionFactFor(tree.root.id!);

      expect(
        composition!.rawSemanticsConfiguration!.container.state,
        KnownBooleanState.trueValue,
      );
      expect(
        composition.rawSemanticsConfiguration!.container.origin,
        ArgumentEvidenceOrigin.literal,
      );
      expect(
        composition.rawSemanticsConfiguration!.explicitChildNodes.state,
        KnownBooleanState.falseValue,
      );
      expect(
        composition.rawSemanticsConfiguration!.explicitChildNodes.origin,
        ArgumentEvidenceOrigin.defaultValue,
      );
    });

    test('does not inherit a group Semantics label through an unrelated child',
        () async {
      final tree = await buildTestSemanticTree('''
Semantics(
  label: 'Account settings',
  child: Column(children: [
    ListTile(leading: Image.network('https://example.test/profile.png')),
  ]),
)
''');
      final facts = SemanticFactExtractor().extract(tree);
      final image =
          tree.physicalNodes.singleWhere((node) => node.widgetType == 'Image');

      expect(
        facts.effectiveNameStateFor(image.id!),
        EffectiveNameState.unknown,
      );
    });

    test('emits typed states for verified semantic nodes', () async {
      final tree = buildManualTree(makeSemanticNode());
      final facts = SemanticFactExtractor().extract(tree);
      final node = tree.root;

      expect(facts.enabledStateFor(node.id!), EnabledState.enabled);
      expect(facts.focusableStateFor(node.id!), FocusableState.focusable);
      expect(facts.visibilityStateFor(node.id!), VisibilityState.visible);
      expect(
        facts.store.conservative
            .factsFor(node.id!)
            .where((fact) => fact.name == 'enabledState')
            .single
            .value,
        'enabled',
      );
      expect(
        facts.controlStateFactFor(node.id!)!.enabled,
        typed_states.EnabledState.enabled,
      );
      expect(
        facts.store.conservative.typedFactsFor(node.id!)!.controlState!.enabled,
        typed_states.EnabledState.enabled,
      );
      expect(
        facts
            .actionsFor(node.id!)
            .singleWhere(
              (action) => action.kind == typed_actions.ActionKind.tap,
            )
            .availability,
        typed_actions.ActionAvailability.absent,
      );
      expect(
        facts.exposureFactFor(node.id!)!.semantic,
        typed_exposure.SemanticInclusionState.included,
      );
    });
    test('distinguishes proven absence from dynamic and unknown labels', () {
      final absent = makeSemanticNode(labelGuarantee: LabelGuarantee.none);
      final dynamic = makeSemanticNode(
        labelGuarantee: LabelGuarantee.hasLabelButDynamic,
      );
      final static = makeSemanticNode(
        label: 'Delete',
        labelGuarantee: LabelGuarantee.hasStaticLabel,
      );
      final tree = SemanticTree.fromRoot(
        makeSemanticNode(children: [absent, dynamic, static]),
      );

      final facts = SemanticFactExtractor().extract(tree);
      final childIds = tree.root.children.map((node) => node.id!).toList();
      expect(facts.labelStateFor(childIds[0]), LabelState.absent);
      expect(facts.labelStateFor(childIds[1]), LabelState.dynamic);
      expect(facts.labelStateFor(childIds[2]), LabelState.static);
    });

    test('keeps heuristic nodes with no label evidence unknown', () {
      final heuristic = makeSemanticNode().copyWith(isHeuristic: true);
      final tree = SemanticTree.fromRoot(heuristic);

      final facts = SemanticFactExtractor().extract(tree);

      expect(facts.labelStateFor(tree.root.id!), LabelState.unknown);
      expect(
        facts.nameFactFor(tree.root.id!)!.state,
        typed_naming.NameState.unknown,
      );
      expect(
        facts.actionsFor(tree.root.id!).first.availability,
        typed_actions.ActionAvailability.unknown,
      );
    });

    test('extracts named slots and literal primitive properties', () async {
      final tree = await buildTestSemanticTree('''
ListTile(
  leading: const Icon('avatar'),
  title: const Text('Account'),
  trailing: const IconButton(icon: Icon('delete'), tooltip: 'Delete'),
)
''');

      final facts = SemanticFactExtractor().extract(tree);
      final rootId = tree.root.id!;

      expect(facts.slotsFor(rootId).keys,
          containsAll(['leading', 'title', 'trailing']));
      expect(facts.propertyValueFor(rootId, 'title'), isNull);
      expect(facts.propertyValueFor(tree.root.children.last.id!, 'tooltip'),
          'Delete');
    });

    test('does not claim an explicitly excluded image is not excluded',
        () async {
      final tree = await buildTestSemanticTree('''
Image.network(
  'https://example.com/avatar.png',
  excludeFromSemantics: true,
)
''');

      final facts = SemanticFactExtractor().extract(tree);
      final image = tree.physicalNodes.singleWhere(
        (node) => node.widgetType == 'Image',
      );
      final imageFacts = facts.store.conservative.factsFor(image.id!);

      expect(
        imageFacts.any(
          (fact) =>
              fact.name == 'isDefinitelyNotExcludedFromSemantics' &&
              fact.value == true,
        ),
        isFalse,
      );
    });

    test('proves default and explicit-false image semantics are not excluded',
        () async {
      final defaultTree = await buildTestSemanticTree('''
Image.network('https://example.com/default.png')
''');
      final explicitFalseTree = await buildTestSemanticTree('''
Image.network(
  'https://example.com/explicit.png',
  excludeFromSemantics: false,
)
''');

      bool hasNotExcludedFact(SemanticTree tree) {
        final extracted = SemanticFactExtractor().extract(tree);
        final image = tree.physicalNodes.singleWhere(
          (node) => node.widgetType == 'Image',
        );
        return extracted.store.conservative.factsFor(image.id!).any(
              (fact) =>
                  fact.name == 'isDefinitelyNotExcludedFromSemantics' &&
                  fact.value == true,
            );
      }

      expect(hasNotExcludedFact(defaultTree), isTrue);
      expect(hasNotExcludedFact(explicitFalseTree), isTrue);
      final extracted = SemanticFactExtractor().extract(defaultTree);
      final image = defaultTree.physicalNodes.singleWhere(
        (node) => node.widgetType == 'Image',
      );
      final typedImage =
          extracted.store.conservative.typedFactsFor(image.id!)!.image!;
      expect(typedImage.sourceKind, typed_images.ImageSourceKind.network);
      expect(typedImage.isDefinitelyNotExcludedFromSemantics, isTrue);
    });

    test('emits visibility only for explicit hiding widgets', () async {
      final tree = await buildTestSemanticTree('''
Offstage(offstage: true, child: const IconButton(icon: Icon('delete')))
''');

      final facts = SemanticFactExtractor().extract(tree);

      expect(
          facts.propertyValueFor(tree.root.id!, 'visibilityState'), 'hidden');
    });

    test('keeps dynamically excluded descendant exposure unknown', () async {
      final tree = await buildTestSemanticTree('''
ExcludeSemantics(
  excluding: purchasePending,
  child: IconButton(
    icon: const Icon('delete'),
    tooltip: 'Delete',
    onPressed: () {},
  ),
)
''');
      final facts = SemanticFactExtractor().extract(tree);
      final child = tree.root.children.single;

      expect(facts.exposureStateFor(child.id!), SemanticExposureState.unknown);
      expect(
        facts.inclusionStateFor(child.id!),
        SemanticInclusionState.unknown,
      );
      final exposureFact = facts.store.conservative
          .factsFor(child.id!)
          .singleWhere((fact) => fact.name == 'semanticExposureState');
      expect(exposureFact.value, 'unknown');
      expect(exposureFact.provenance, FactProvenance.derived);
    });

    test('retains semantic inclusion for a ListTile leading image', () async {
      final tree = await buildTestSemanticTree(
        "ListTile(leading: Image.network('https://example.test/photo.png'))",
      );
      final facts = SemanticFactExtractor().extract(tree);
      final image = tree.physicalNodes.singleWhere(
        (node) => node.widgetType == 'Image',
      );

      expect(
        facts.inclusionStateFor(image.id!),
        SemanticInclusionState.included,
      );
    });

    test('preserves every nested branch constraint in facts', () {
      final branchChild = makeSemanticNode().copyWith(
        branchPath: BranchPath([Branch(1, 0), Branch(2, 1)]),
      );
      final tree =
          SemanticTree.fromRoot(makeSemanticNode(children: [branchChild]));

      final facts = SemanticFactExtractor().extract(tree);
      final childId = tree.root.children.single.id!;
      expect(
        facts.store.nodeById(childId)!.effectiveBranchPath.constraints,
        hasLength(2),
      );
    });

    test('derives callback action availability without assuming runtime values',
        () async {
      final present = await buildTestSemanticTree(
        "IconButton(icon: Icon('add'), onPressed: () {})",
      );
      final absent = await buildTestSemanticTree(
        "IconButton(icon: Icon('add'), onPressed: null)",
      );
      final dynamic = await buildTestSemanticTree(
        "IconButton(icon: Icon('add'), onPressed: handler)",
        extraDeclarations: 'void Function()? handler;',
      );

      typed_actions.ActionAvailability availability(SemanticTree tree) =>
          SemanticFactExtractor()
              .extract(tree)
              .actionsFor(tree.root.id!)
              .singleWhere(
                  (action) => action.kind == typed_actions.ActionKind.tap)
              .availability;

      expect(availability(present), typed_actions.ActionAvailability.present);
      expect(availability(absent), typed_actions.ActionAvailability.absent);
      expect(availability(dynamic), typed_actions.ActionAvailability.dynamic);
    });

    test('extracts literal semantic value and hint without guessing dynamics',
        () async {
      final tree = await buildTestSemanticTree('''
Semantics(semanticValue: '42', semanticHint: 'Percentage', child: Text('42'))
''');
      final facts = SemanticFactExtractor().extract(tree);
      final valueInput =
          facts.store.conservative.typedFactsFor(tree.root.id!)!.valueInput!;

      expect(valueInput.value.state, typed_values.TextState.static);
      expect(valueInput.value.value, '42');
      expect(valueInput.hint.value, 'Percentage');
    });

    test('extracts typed semantic range and length evidence', () async {
      final literalTree = await buildTestSemanticTree('''
Semantics(
  minValue: '0',
  maxValue: '100',
  currentValueLength: 3,
  maxValueLength: 20,
  child: Text('Value'),
)
''');
      final dynamicTree = await buildTestSemanticTree(
        'Semantics(minValue: minimum, currentValueLength: length, child: Text("Value"))',
        extraDeclarations: '''
String minimum = '0';
int length = 3;
''',
      );

      typed_values.ValueInputFact inputFor(SemanticTree tree) =>
          SemanticFactExtractor()
              .extract(tree)
              .store
              .conservative
              .typedFactsFor(tree.root.id!)!
              .valueInput!;

      final literal = inputFor(literalTree);
      expect(literal.minValue.state, typed_values.TextState.static);
      expect(literal.minValue.value, '0');
      expect(literal.maxValue.value, '100');
      expect(
          literal.currentValueLength.state, typed_values.IntegerState.static);
      expect(literal.currentValueLength.value, 3);
      expect(literal.maxValueLength.value, 20);

      final dynamic = inputFor(dynamicTree);
      expect(dynamic.minValue.state, typed_values.TextState.dynamic);
      expect(
        dynamic.currentValueLength.state,
        typed_values.IntegerState.dynamic,
      );
    });

    test('extracts only static semantic relationship identifiers', () async {
      final staticTree = await buildTestSemanticTree('''
Semantics(
  identifier: 'menu-button',
  traversalParentIdentifier: 'toolbar',
  traversalChildIdentifier: 'overflow-menu',
  controlsNodes: {'overflow-menu', 'profile-menu'},
  child: Text('Menu'),
)
''');
      final dynamicTree = await buildTestSemanticTree('''
Semantics(
  identifier: semanticIdentifier,
  traversalParentIdentifier: parentIdentifier,
  controlsNodes: controlledNodes,
  child: Text('Menu'),
)
''', extraDeclarations: '''
String semanticIdentifier = 'menu-button';
Object parentIdentifier = 'toolbar';
Set<String> controlledNodes = {'overflow-menu'};
''');

      typed_relationships.SemanticRelationshipFact relationshipFor(
        SemanticTree tree,
      ) =>
          SemanticFactExtractor()
              .extract(tree)
              .relationshipFactFor(tree.root.id!)!;

      final staticFact = relationshipFor(staticTree);
      expect(staticFact.identifier.state, typed_values.TextState.static);
      expect(staticFact.identifier.value, 'menu-button');
      expect(staticFact.traversalParentIdentifier.state,
          typed_values.TextState.static);
      expect(staticFact.traversalChildIdentifier.value, 'overflow-menu');
      expect(staticFact.controlsNodeIdentifiers.state,
          typed_relationships.IdentifierSetState.static);
      expect(staticFact.controlsNodeIdentifiers.values,
          unorderedEquals(['overflow-menu', 'profile-menu']));
      expect(staticFact.evidence.provenance, FactProvenance.exact);

      final dynamicFact = relationshipFor(dynamicTree);
      expect(dynamicFact.identifier.state, typed_values.TextState.dynamic);
      expect(dynamicFact.traversalParentIdentifier.state,
          typed_values.TextState.dynamic);
      expect(dynamicFact.controlsNodeIdentifiers.state,
          typed_relationships.IdentifierSetState.dynamic);
    });

    test('extracts explicit typed semantic states without defaulting dynamics',
        () async {
      final literalTree = await buildTestSemanticTree('''
Semantics(
  enabled: false,
  checked: true,
  selected: false,
  toggled: true,
  expanded: false,
  focusable: true,
  focused: false,
  isRequired: true,
  readOnly: true,
  obscured: false,
  multiline: true,
  child: Text('Password'),
)
''');
      final dynamicTree = await buildTestSemanticTree(
        'Semantics(checked: isChecked, child: Text("Choice"))',
        extraDeclarations: 'bool isChecked = true;',
      );

      typed_states.ControlStateFact stateFor(SemanticTree tree) =>
          SemanticFactExtractor()
              .extract(tree)
              .controlStateFactFor(tree.root.id!)!;

      final literal = stateFor(literalTree);
      expect(literal.enabled, typed_states.EnabledState.disabled);
      expect(literal.checked, typed_states.CheckedState.checked);
      expect(literal.selected, typed_states.SelectedState.unselected);
      expect(literal.toggled, typed_states.ToggledState.on);
      expect(literal.expanded, typed_states.ExpandedState.collapsed);
      expect(literal.focusable, typed_states.FocusableState.focusable);
      expect(literal.focused, typed_states.FocusedState.unfocused);
      expect(literal.required, typed_states.RequiredState.required);
      expect(literal.readOnly, typed_states.ReadOnlyState.readOnly);
      expect(literal.obscured, typed_states.ObscuredState.unobscured);
      expect(literal.multiline, typed_states.MultilineState.multiline);
      expect(literal.evidence.provenance, FactProvenance.exact);

      final dynamic = stateFor(dynamicTree);
      expect(dynamic.checked, typed_states.CheckedState.unknown);
      expect(dynamic.evidence.knowledge, KnowledgeState.dynamic);
    });

    test('extracts explicit semantic callback availability', () async {
      final tree = await buildTestSemanticTree(
        '''
Semantics(
  onScrollLeft: () {},
  onCopy: copyHandler,
  onPaste: null,
  onExpand: () {},
  onSetText: () {},
  onMoveCursorForwardByCharacter: () {},
  child: Text('Actions'),
)
''',
        extraDeclarations: 'void copyHandler() {}',
      );
      final actions = SemanticFactExtractor().extract(tree).actionsFor(
            tree.root.id!,
          );
      typed_actions.ActionAvailability availability(
        typed_actions.ActionKind kind,
      ) =>
          actions.singleWhere((action) => action.kind == kind).availability;

      expect(
        availability(typed_actions.ActionKind.scrollLeft),
        typed_actions.ActionAvailability.present,
      );
      expect(
        availability(typed_actions.ActionKind.copy),
        typed_actions.ActionAvailability.dynamic,
      );
      expect(
        availability(typed_actions.ActionKind.paste),
        typed_actions.ActionAvailability.absent,
      );
      expect(
        availability(typed_actions.ActionKind.expand),
        typed_actions.ActionAvailability.present,
      );
      expect(
        availability(typed_actions.ActionKind.setText),
        typed_actions.ActionAvailability.present,
      );
      expect(
        availability(typed_actions.ActionKind.moveCursorForwardByCharacter),
        typed_actions.ActionAvailability.present,
      );
    });

    test('projects only compatible explicit traversal and controls edges',
        () async {
      final tree = await buildTestSemanticTree('''
Column(children: [
  Semantics(
    identifier: 'controller',
    traversalParentIdentifier: 'toolbar',
    controlsNodes: {'overflow-menu'},
    child: Text('Controller'),
  ),
  Semantics(
    identifier: 'overflow-menu',
    traversalChildIdentifier: 'toolbar',
    child: Text('Menu'),
  ),
])
''');
      final facts = SemanticFactExtractor().extract(tree);
      final controller = tree.physicalNodes.singleWhere(
        (node) => node.getAttribute('controlsNodes') != null,
      );
      final menu = tree.physicalNodes.singleWhere(
        (node) => node.getAttribute('traversalChildIdentifier') != null,
      );

      expect(
        facts.graph.traversalChildren
            .map((edge) => (parentId: edge.parentId, childId: edge.childId)),
        contains((parentId: controller.id!, childId: menu.id!)),
      );
      expect(
        facts.graph.controlsNodes.map(
          (edge) => (
            controllerId: edge.controllerId,
            controlledId: edge.controlledId,
          ),
        ),
        contains((controllerId: controller.id!, controlledId: menu.id!)),
      );
    });

    test('derives static label associations only from explicit controls nodes',
        () async {
      final tree = await buildTestSemanticTree('''
Column(children: [
  Semantics(
    label: 'Email address',
    controlsNodes: {'email-field'},
    child: Text('Email address'),
  ),
  Semantics(identifier: 'email-field', child: Text('Input')),
])
''');
      final facts = SemanticFactExtractor().extract(tree);
      final field = tree.physicalNodes.singleWhere(
        (node) => node.getAttribute('identifier') != null,
      );
      final association = facts.formAssociationFor(field.id!);

      expect(
          association!.state, typed_forms.StaticLabelAssociationState.static);
      expect(association.labelNodeIds, hasLength(1));
      expect(association.evidence.provenance, FactProvenance.derived);
      expect(
        facts.store.conservative.typedFactsFor(field.id!)!.formAssociation,
        same(association),
      );
    });

    test('does not derive label associations across incompatible branches',
        () async {
      final tree = await buildTestSemanticTree('''
Column(children: [
  if (purchasePending)
    Semantics(
      label: 'Email address',
      controlsNodes: {'email-field'},
      child: Text('Email address'),
    )
  else
    Semantics(identifier: 'email-field', child: Text('Input')),
])
''');
      final field = tree.physicalNodes.singleWhere(
        (node) => node.getAttribute('identifier') != null,
      );

      expect(
        SemanticFactExtractor()
            .extract(tree)
            .formAssociationFor(field.id!)!
            .state,
        typed_forms.StaticLabelAssociationState.unknown,
      );
    });

    test('does not project traversal edges across incompatible branches',
        () async {
      final tree = await buildTestSemanticTree('''
Column(children: [
  if (purchasePending)
    Semantics(
      traversalParentIdentifier: 'toolbar',
      child: Text('Controller'),
    )
  else
    Semantics(
      traversalChildIdentifier: 'toolbar',
      child: Text('Menu'),
    ),
])
''');

      expect(
        SemanticFactExtractor().extract(tree).graph.traversalChildren,
        isEmpty,
      );
    });

    test('projects source, composition, and accessibility graphs separately',
        () async {
      final tree = await buildTestSemanticTree(
        "ListTile(leading: Image.network('https://example.test/photo.png'))",
      );
      final facts = SemanticFactExtractor().extract(tree);

      expect(facts.graph.sourceNodes, hasLength(tree.physicalNodes.length));
      expect(
        facts.graph.sourceChildren.map((edge) => edge.parentId),
        contains(tree.root.id),
      );
      expect(
        facts.graph.compositionNodes.map((node) => node.sourceWidgetId),
        contains(tree.root.id),
      );
      expect(
        facts.graph.accessibilityNodes.map((node) => node.compositionNodeId),
        contains(tree.root.id),
      );
      expect(facts.graph.slots.single.name, 'leading');
    });

    test('does not emit an independent accessibility node for merge children',
        () async {
      final tree = await buildTestSemanticTree('''
MergeSemantics(
  child: Row(children: [
    IconButton(icon: Icon('add'), onPressed: () {}),
  ]),
)
''');
      final facts = SemanticFactExtractor().extract(tree);
      final button = tree.physicalNodes.singleWhere(
        (node) => node.widgetType == 'IconButton',
      );

      expect(
        facts.graph.accessibilityNodes
            .where((node) => node.compositionNodeId == button.id),
        isEmpty,
      );
    });
  });
}
