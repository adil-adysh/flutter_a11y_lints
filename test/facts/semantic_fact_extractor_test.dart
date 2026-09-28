import 'package:flutter_a11y_lints/src/facts/semantic_fact_extractor.dart';
import 'package:flutter_a11y_lints/src/facts/fact_store.dart';
import 'package:flutter_a11y_lints/src/facts/model/composition_facts.dart';
import 'package:flutter_a11y_lints/src/facts/model/exposure_facts.dart'
    as typed_exposure;
import 'package:flutter_a11y_lints/src/facts/model/image_facts.dart'
    as typed_images;
import 'package:flutter_a11y_lints/src/facts/model/naming_facts.dart'
    as typed_naming;
import 'package:flutter_a11y_lints/src/facts/model/role_action_facts.dart'
    as typed_actions;
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
      final composition =
          SemanticFactExtractor().extract(tree).compositionFactFor(tree.root.id!);

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
        facts.actionsFor(node.id!).singleWhere(
              (action) => action.kind == typed_actions.ActionKind.tap,
            ).availability,
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
              .singleWhere((action) => action.kind == typed_actions.ActionKind.tap)
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
