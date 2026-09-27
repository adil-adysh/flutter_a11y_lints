import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a plain Semantics label may absorb descendant text',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Semantics(label: 'Wrapper', child: const Text('Child content')),
      ),
    );

    final labels = tester.semantics
        .simulatedAccessibilityTraversal()
        .map((node) => node.label);
    expect(labels, contains('Wrapper\nChild content'));
    handle.dispose();
  });

  testWidgets(
      'explicit child nodes keep container and child semantics separate',
      (tester) async {
    final handle = tester.ensureSemantics();
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
    handle.dispose();
  });

  testWidgets(
      'replacement retains wrapper semantics and removes child semantics',
      (tester) async {
    final handle = tester.ensureSemantics();
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
    handle.dispose();
  });

  testWidgets('ExcludeSemantics removes the descendant subtree',
      (tester) async {
    final handle = tester.ensureSemantics();
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
    handle.dispose();
  });

  testWidgets('MergeSemantics combines descendant text into one node',
      (tester) async {
    final handle = tester.ensureSemantics();
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
    handle.dispose();
  });
}
