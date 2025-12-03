import 'package:analyzer/dart/analysis/results.dart';

bool fileUsesFlutter(ResolvedUnitResult unit) =>
    unit.content.contains("package:flutter");

/// Minimal Flutter file detection used by the CLI runner to avoid analyzing
/// non-Flutter packages. This is intentionally conservative and cheap: it
/// performs a simple substring search for the `package:flutter` import in the
/// resolved unit content. If you need more precise detection (for example in
/// complex multi-package workspaces), replace this with a proper analyzer
/// import scan using `unit.unit.directives`.
