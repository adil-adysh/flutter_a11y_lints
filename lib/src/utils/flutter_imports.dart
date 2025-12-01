import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';

bool fileUsesFlutter(ResolvedUnitResult unit) {
  // Check if the file imports any Flutter packages
  final imports = unit.unit.directives.whereType<ImportDirective>();
  return imports.any((import) {
    final uri = import.uri.stringValue;
    return uri != null && uri.startsWith('package:flutter/');
  });
}

