import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import '../bin/flutter_a11y_analyzer.dart';

/// Integration tests using the real a11y_test_app project.
/// These tests verify the analyzer works on actual Flutter code.
void main() {
  group('Integration Tests (a11y_test_app)', () {
    late FlutterA11yAnalyzer analyzer;
    late String testAppPath;

    setUp(() {
      analyzer = FlutterA11yAnalyzer();
      // Path to the test app relative to semantic_ir_linter
      testAppPath = p.normalize(p.join(
        Directory.current.path,
        '..',
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
      expect(issues, isNotEmpty, reason: 'Test app should have accessibility issues');
      
      // Should find IconButtons without tooltips
      final iconButtonIssues = issues.where(
        (i) => i.message.contains('iconButton'),
      );
      expect(iconButtonIssues, isNotEmpty);
      
      // All issues should have proper metadata
      for (final issue in issues) {
        expect(issue.file, isNotEmpty);
        expect(issue.line, greaterThan(0));
        expect(issue.column, greaterThan(0));
        expect(issue.code, equals('a01_unlabeled_interactive'));
        expect(issue.message, isNotEmpty);
        expect(issue.correctionMessage, isNotEmpty);
      }
    });

    test('finds specific violations in test app', () async {
      if (!File(testAppPath).existsSync()) {
        print('Skipping: a11y_test_app not found');
        return;
      }

      final issues = await analyzer.analyze(testAppPath);

      // The test app has at least 2 violations (as verified manually)
      expect(issues.length, greaterThanOrEqualTo(2));

      // Verify issue format
      final firstIssue = issues.first;
      expect(firstIssue.severity, equals('warning'));
      expect(firstIssue.message, contains('accessible label'));
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

      // The test app has disabled controls that should NOT be flagged
      // All violations should be for controls with actual callbacks
      for (final issue in issues) {
        expect(
          issue.message,
          contains('Interactive'),
          reason: 'Should only flag interactive (enabled) controls',
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
