import 'package:analyzer/dart/analysis/results.dart';

bool fileUsesFlutter(ResolvedUnitResult unit) =>
    unit.content.contains("package:flutter");
