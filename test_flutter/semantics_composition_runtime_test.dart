import 'dart:ui' show SemanticsAction;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a plain Semantics label may absorb descendant text',
      (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child:
              Semantics(label: 'Wrapper', child: const Text('Child content')),
        ),
      );

      final labels = tester.semantics
          .simulatedAccessibilityTraversal()
          .map((node) => node.label);
      expect(labels, contains('Wrapper\nChild content'));
    } finally {
      handle.dispose();
    }
  });

  testWidgets(
      'explicit child nodes keep container and child semantics separate',
      (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            label: 'Container',
            child: const Text('Child content'),
          ),
        ),
      );

      final labels = tester.semantics
          .simulatedAccessibilityTraversal()
          .map((node) => node.label)
          .toList();
      expect(labels, containsAllInOrder(['Container', 'Child content']));
    } finally {
      handle.dispose();
    }
  });

  testWidgets(
      'replacement retains wrapper semantics and removes child semantics',
      (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Semantics(
            excludeSemantics: true,
            label: 'Replacement',
            child: const Text('Child content'),
          ),
        ),
      );

      final labels = tester.semantics
          .simulatedAccessibilityTraversal()
          .map((node) => node.label);
      expect(labels, contains('Replacement'));
      expect(labels, isNot(contains('Child content')));
    } finally {
      handle.dispose();
    }
  });

  testWidgets('replacement does not inherit a discarded child action',
      (tester) async {
    // Runtime contract: excludeSemantics removes a child's tap action.
    // IR mapping: replacement nodes must not inherit child role/action facts.
    // Conservative consequence: replacement-based rules use wrapper-local facts.
    // Deliberate unknown boundary: dynamic exclusion does not expose child facts.
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Semantics(
            excludeSemantics: true,
            label: 'Delete item',
            child: Semantics(
              button: true,
              label: 'Child action',
              onTap: () {},
              child: const Text('Child content'),
            ),
          ),
        ),
      );

      final replacement = tester.getSemantics(find.byType(Semantics).first);
      expect(replacement.label, 'Delete item');
      expect(
        replacement.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );
    } finally {
      handle.dispose();
    }
  });

  testWidgets('ExcludeSemantics removes the descendant subtree',
      (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: const ExcludeSemantics(child: Text('Hidden child')),
        ),
      );

      final labels = tester.semantics
          .simulatedAccessibilityTraversal()
          .map((node) => node.label);
      expect(labels, isNot(contains('Hidden child')));
    } finally {
      handle.dispose();
    }
  });

  testWidgets('Offstage excludes semantics in this Flutter SDK',
      (tester) async {
    // Runtime contract: this SDK's Offstage(true) omits the child from
    // simulated accessibility traversal.
    // IR mapping: visual/hit-test hiding and semantic inclusion are separate;
    // Offstage is not modeled as a semantic descendant replacement.
    // Conservative consequence: no independent child accessibility node.
    // Deliberate unknown boundary: runtime focus order remains unknown.
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Offstage(offstage: true, child: Text('Offstage child')),
        ),
      );

      final labels = tester.semantics
          .simulatedAccessibilityTraversal()
          .map((node) => node.label);
      expect(labels, isNot(contains('Offstage child')));
    } finally {
      handle.dispose();
    }
  });

  testWidgets('hidden Visibility excludes semantics by default',
      (tester) async {
    // Runtime contract: Visibility(false) does not retain child semantics by
    // default.
    // IR mapping: explicit false visibility is visual hiding plus semantic
    // exclusion, not a focus-list inference.
    // Conservative consequence: no independent child accessibility node.
    // Deliberate unknown boundary: dynamic flags remain unknown.
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Visibility(visible: false, child: Text('Hidden child')),
        ),
      );

      final labels = tester.semantics
          .simulatedAccessibilityTraversal()
          .map((node) => node.label);
      expect(labels, isNot(contains('Hidden child')));
    } finally {
      handle.dispose();
    }
  });

  testWidgets('MergeSemantics combines descendant text into one node',
      (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: MergeSemantics(
            child: Row(children: [Text('First'), Text('Second')]),
          ),
        ),
      );

      final labels = tester.semantics
          .simulatedAccessibilityTraversal()
          .map((node) => node.label);
      expect(labels, contains('First\nSecond'));
    } finally {
      handle.dispose();
    }
  });

  testWidgets('Semantics publishes explicit relationship identifiers',
      (tester) async {
    // Runtime contract: explicitly supplied identifier, traversal identifiers,
    // and controlsNodes appear on the emitted semantics node.
    // IR mapping: literal source values become relationship facts; no graph
    // edge is inferred merely because identifiers happen to match.
    // Conservative consequence: rules can use only static relationship facts.
    // Deliberate unknown boundary: dynamic/object identifiers remain unknown.
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Semantics(
            identifier: 'menu-button',
            traversalParentIdentifier: 'toolbar',
            traversalChildIdentifier: 'overflow-menu',
            controlsNodes: const {'overflow-menu', 'profile-menu'},
            child: const Text('Menu'),
          ),
        ),
      );

      final data =
          tester.getSemantics(find.byType(Semantics)).getSemanticsData();
      expect(data.identifier, 'menu-button');
      expect(data.traversalParentIdentifier, 'toolbar');
      expect(data.traversalChildIdentifier, 'overflow-menu');
      expect(data.controlsNodes, {'overflow-menu', 'profile-menu'});
    } finally {
      handle.dispose();
    }
  });

  testWidgets('Semantics publishes explicit callback actions', (tester) async {
    // Runtime contract: documented Semantics callback parameters add their
    // corresponding actions to the emitted semantics node.
    // IR mapping: literal callback expressions map to present action facts.
    // Conservative consequence: action predicates use exact callback facts.
    // Deliberate unknown boundary: identifiers and tear-offs remain dynamic.
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Semantics(
            onScrollLeft: () {},
            onCopy: () {},
            onExpand: () {},
            child: const Text('Actions'),
          ),
        ),
      );

      final data =
          tester.getSemantics(find.byType(Semantics)).getSemanticsData();
      expect(data.hasAction(SemanticsAction.scrollLeft), isTrue);
      expect(data.hasAction(SemanticsAction.copy), isTrue);
      expect(data.hasAction(SemanticsAction.expand), isTrue);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('GestureDetector publishes a tap action unless excluded',
      (tester) async {
    // Runtime contract: GestureDetector exposes onTap as SemanticsAction.tap
    // unless excludeFromSemantics is explicitly true.
    // IR mapping: literal onTap and exclusion values produce typed action
    // availability and inclusion facts for this known Flutter widget.
    // Conservative consequence: a static analyzer may recognize the action,
    // but must not invent an accessible name or role.
    // Deliberate unknown boundary: dynamic callbacks and exclusion values stay
    // unknown, and custom gesture implementations are not inferred.
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: GestureDetector(onTap: () {}, child: const Text('Activate')),
        ),
      );

      final included =
          tester.getSemantics(find.byType(GestureDetector)).getSemanticsData();
      expect(included.hasAction(SemanticsAction.tap), isTrue);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: GestureDetector(
            onTap: () {},
            excludeFromSemantics: true,
            child: const Text('Activate'),
          ),
        ),
      );

      final excluded =
          tester.getSemantics(find.byType(GestureDetector)).getSemanticsData();
      expect(excluded.hasAction(SemanticsAction.tap), isFalse);
    } finally {
      handle.dispose();
    }
  });
}
