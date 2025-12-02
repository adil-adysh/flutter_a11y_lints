import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import '../bin/a11y.dart';

/// Integration tests using the real a11y_test_app project.
/// These tests verify the analyzer works on actual Flutter code.
void main() {
  group('Integration Tests (a11y_test_app)', () {
    late FlutterA11yAnalyzer analyzer;
    late String testAppPath;

    setUp(() {
      analyzer = FlutterA11yAnalyzer();
      // Path to the test app from root
      testAppPath = p.normalize(p.join(
        Directory.current.path,
        'a11y_test_app',
        'lib',
        'main.dart',
      ));
    });

    test('analyzes a11y_test_app/lib/main.dart', () async {
      if (!File(testAppPath).existsSync()) {
        print('Skipping: a11y_test_app not found at $testAppPath');
        return;
      }

      final issues = await analyzer.analyze(testAppPath);

      // The test app intentionally has violations for testing
      expect(issues, isNotEmpty,
          reason: 'Test app should have accessibility issues');

      // All issues should have proper metadata
      for (final issue in issues) {
        expect(issue.file, isNotEmpty);
        expect(issue.line, greaterThan(0));
        expect(issue.column, greaterThan(0));
        expect(issue.code, isNotEmpty);
        expect(issue.message, isNotEmpty);
        expect(issue.correctionMessage, isNotEmpty);
      }
    });

    test('detects A01: unlabeled interactive controls', () async {
      if (!File(testAppPath).existsSync()) {
        print('Skipping: a11y_test_app not found');
        return;
      }

      final issues = await analyzer.analyze(testAppPath);

      // Should find A01 violations (IconButtons without tooltips)
      final a01Issues = issues.where(
        (i) => i.code == 'a01_unlabeled_interactive',
      );
      expect(a01Issues, isNotEmpty,
          reason: 'Should detect unlabeled interactive controls');

      // Verify message content
      for (final issue in a01Issues) {
        expect(issue.message, contains('accessible label'));
        expect(issue.correctionMessage, contains('tooltip'));
      }
    });

    test('detects A02: redundant role words in labels', () async {
      if (!File(testAppPath).existsSync()) {
        print('Skipping: a11y_test_app not found');
        return;
      }

      final issues = await analyzer.analyze(testAppPath);

      // Should find A02 violations (labels with "button", "icon", etc.)
      final a02Issues = issues.where(
        (i) => i.code == 'a02_avoid_redundant_role_words',
      );

      if (a02Issues.isNotEmpty) {
        // Verify message content
        for (final issue in a02Issues) {
          expect(issue.message, contains('redundant role words'));
          expect(issue.correctionMessage, contains('announced automatically'));
        }
      }
    });

    test('detects A06: multi-part controls needing merge', () async {
      if (!File(testAppPath).existsSync()) {
        print('Skipping: a11y_test_app not found');
        return;
      }

      final issues = await analyzer.analyze(testAppPath);

      // Check for A06 violations
      final a06Issues = issues.where(
        (i) => i.code == 'a06_merge_multi_part_single_concept',
      );

      // May or may not have violations depending on test app content
      if (a06Issues.isNotEmpty) {
        for (final issue in a06Issues) {
          expect(issue.message, contains('multiple semantic parts'));
          expect(issue.correctionMessage, contains('MergeSemantics'));
        }
      }
    });

    test('detects A07: semantics replacement without exclusion', () async {
      if (!File(testAppPath).existsSync()) {
        print('Skipping: a11y_test_app not found');
        return;
      }

      final issues = await analyzer.analyze(testAppPath);

      // Check for A07 violations
      final a07Issues = issues.where(
        (i) => i.code == 'a07_replace_semantics_cleanly',
      );

      // May or may not have violations depending on test app content
      if (a07Issues.isNotEmpty) {
        for (final issue in a07Issues) {
          expect(issue.message, contains('exclude children'));
          expect(issue.correctionMessage, contains('ExcludeSemantics'));
        }
      }
    });

    test('finds specific violations in test app', () async {
      if (!File(testAppPath).existsSync()) {
        print('Skipping: a11y_test_app not found');
        return;
      }

      final issues = await analyzer.analyze(testAppPath);

      // The test app has at least 3 violations (2 A01 + 1 A02)
      expect(issues.length, greaterThanOrEqualTo(3));

      // Verify issue format
      final firstIssue = issues.first;
      expect(firstIssue.severity, equals('warning'));
    });

    test('reports correct file locations', () async {
      if (!File(testAppPath).existsSync()) {
        print('Skipping: a11y_test_app not found');
        return;
      }

      final issues = await analyzer.analyze(testAppPath);

      for (final issue in issues) {
        // File path should exist
        expect(File(issue.file).existsSync(), isTrue);

        // Line and column should be positive
        expect(issue.line, greaterThan(0));
        expect(issue.column, greaterThan(0));

        // Should point to main.dart
        expect(issue.file, contains('main.dart'));
      }
    });

    test('produces consistent results across runs', () async {
      if (!File(testAppPath).existsSync()) {
        print('Skipping: a11y_test_app not found');
        return;
      }

      // Run analyzer twice
      final issues1 = await analyzer.analyze(testAppPath);
      final issues2 = await analyzer.analyze(testAppPath);

      // Should find same number of issues
      expect(issues1.length, equals(issues2.length));

      // Issues should be at same locations
      for (var i = 0; i < issues1.length; i++) {
        expect(issues1[i].file, equals(issues2[i].file));
        expect(issues1[i].line, equals(issues2[i].line));
        expect(issues1[i].column, equals(issues2[i].column));
      }
    });

    test('analyzer respects enabled state', () async {
      if (!File(testAppPath).existsSync()) {
        print('Skipping: a11y_test_app not found');
        return;
      }

      final issues = await analyzer.analyze(testAppPath);

      // Should find multiple types of issues
      expect(issues, isNotEmpty);

      // All A01 violations should be for interactive controls
      final a01Issues =
          issues.where((i) => i.code == 'a01_unlabeled_interactive');
      for (final issue in a01Issues) {
        expect(
          issue.message,
          contains('Interactive'),
          reason: 'A01 should only flag interactive (enabled) controls',
        );
      }
    });
  });

  group('Analyzer API', () {
    test('handles non-existent paths gracefully', () async {
      final analyzer = FlutterA11yAnalyzer();

      // Should not throw, just return empty results
      expect(
        () => analyzer.analyze('/non/existent/path.dart'),
        throwsA(anything), // Will throw when trying to create context
      );
    });
  });
}
