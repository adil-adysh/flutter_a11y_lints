import 'dart:io';

import 'package:flutter_a11y_lints/src/analyzer/flutter_a11y_analyzer.dart';
import 'package:test/test.dart';

void main() {
  test('rejects an invalid analysis path', () async {
    final missing = Directory.systemTemp
        .createTempSync('flutter_a11y_missing_')
        .path;
    Directory(missing).deleteSync();

    expect(
      FlutterA11yAnalyzer().analyze(missing),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('ignores a non-Flutter Dart file in a directory', () async {
    final directory = Directory.systemTemp.createTempSync('flutter_a11y_api_');
    try {
      File('${directory.path}${Platform.pathSeparator}plain.dart')
          .writeAsStringSync('void main() {}');

      final issues = await FlutterA11yAnalyzer().analyze(directory.path);

      expect(issues, isEmpty);
    } finally {
      directory.deleteSync(recursive: true);
    }
  });
}
