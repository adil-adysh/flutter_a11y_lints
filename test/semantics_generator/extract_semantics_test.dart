import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_catalogue.dart';

void main() {
  testWidgets(
    'Extract widget semantics to JSON',
    (WidgetTester tester) async {
      final extractedData = <String, Map<String, dynamic>>{};

      // Enable semantics once at the start
      final handle = tester.ensureSemantics();

      for (final entry in widgetCatalogue) {
        final name = entry.name;
        final type = entry.type;
        final builder = entry.builder;

        // Build minimal app with the widget
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: builder(),
              ),
            ),
          ),
        );

        // Pump frames to allow widget to build and get semantics
        await tester.pump();

        // Find the widget - use byWidgetPredicate for better matching
        final finder = find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString().startsWith(name),
        );

        if (finder.evaluate().isEmpty) {
          extractedData[name] = _createEmptySemantics(
            error: 'Widget not found',
          );
          continue;
        }

        // Get render object and semantics
        final element = finder.evaluate().first;
        final renderObject = element.renderObject;
        final rootSemantics = renderObject?.debugSemantics;
        final node = _findRelevantSemanticsNode(rootSemantics);

        if (node != null) {
          final data = node.getSemanticsData();

          extractedData[name] = {
            'isButton': data.hasFlag(SemanticsFlag.isButton),
            'isImage': data.hasFlag(SemanticsFlag.isImage),
            'isToggled': data.hasFlag(SemanticsFlag.isToggled),
            'isChecked': data.hasFlag(SemanticsFlag.isChecked),
            'isLink': data.hasFlag(SemanticsFlag.isLink),
            'isSlider': data.hasFlag(SemanticsFlag.isSlider),
            'isTextField': data.hasFlag(SemanticsFlag.isTextField),
            'isHeader': data.hasFlag(SemanticsFlag.namesRoute) ||
                data.hasFlag(SemanticsFlag.isHeader),
            'isFocusable': data.hasFlag(SemanticsFlag.isFocusable),
            'isInMutuallyExclusiveGroup':
                data.hasFlag(SemanticsFlag.isInMutuallyExclusiveGroup),
            'hasTap': data.hasAction(SemanticsAction.tap),
            'hasLongPress': data.hasAction(SemanticsAction.longPress),
            'hasIncrease': data.hasAction(SemanticsAction.increase),
            'hasDecrease': data.hasAction(SemanticsAction.decrease),
            'hasChildren':
                node.mergeAllDescendantsIntoThisNode || node.childrenCount > 0,
            'childCount': node.childrenCount,
            'mergesDescendants': node.mergeAllDescendantsIntoThisNode,
            'label': data.label,
            'hint': data.hint,
            'value': data.value,
          };
        } else {
          extractedData[name] = _createEmptySemantics();
        }
      }

      // Clean up semantics
      handle.dispose();

      // Write to JSON file synchronously
      final jsonContent =
          const JsonEncoder.withIndent('  ').convert(extractedData);
      File('tool/semantics_generator/semantics_dump.json')
          .writeAsStringSync(jsonContent);

      // Verify file was written
      expect(
        File('tool/semantics_generator/semantics_dump.json').existsSync(),
        isTrue,
      );
      expect(extractedData.length, equals(widgetCatalogue.length));

      // ignore: avoid_print
      print('✓ Extracted semantics for ${extractedData.length} widgets');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Map<String, dynamic> _createEmptySemantics({String? error}) {
  return {
    'isButton': false,
    'isImage': false,
    'isToggled': false,
    'isChecked': false,
    'isLink': false,
    'isSlider': false,
    'isTextField': false,
    'isHeader': false,
    'isFocusable': false,
    'isInMutuallyExclusiveGroup': false,
    'hasTap': false,
    'hasLongPress': false,
    'hasIncrease': false,
    'hasDecrease': false,
    'hasChildren': false,
    'childCount': 0,
    'mergesDescendants': false,
    'label': '',
    'hint': '',
    'value': '',
    if (error != null) 'error': error,
  };
}

/// Find the most relevant semantics node in the tree
SemanticsNode? _findRelevantSemanticsNode(SemanticsNode? root) {
  if (root == null) return null;

  // BFS through semantics subtree to find first "interesting" node
  final queue = <SemanticsNode>[root];

  while (queue.isNotEmpty) {
    final current = queue.removeAt(0);
    final data = current.getSemanticsData();

    // Check for interesting flags or actions
    final hasInterestingFlag = data.hasFlag(SemanticsFlag.isButton) ||
        data.hasFlag(SemanticsFlag.isImage) ||
        data.hasFlag(SemanticsFlag.isTextField) ||
        data.hasFlag(SemanticsFlag.isLink) ||
        data.hasFlag(SemanticsFlag.isSlider) ||
        data.hasFlag(SemanticsFlag.isToggled) ||
        data.hasFlag(SemanticsFlag.isChecked) ||
        data.hasAction(SemanticsAction.tap) ||
        data.hasAction(SemanticsAction.longPress);

    if (hasInterestingFlag) {
      return current;
    }

    // Add children to queue
    current.visitChildren((child) {
      queue.add(child);
      return true;
    });
  }

  // If nothing interesting found, return root
  return root;
}
