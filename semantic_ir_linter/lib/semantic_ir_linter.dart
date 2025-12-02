/// Entry point for the experimental semantic IR linter package.
///
/// The first iteration exposes a minimal plugin that builds a lightweight
/// semantic tree and runs a single high-confidence lint.
library semantic_ir_linter;

export 'src/plugin.dart';
export 'src/rules/a01_unlabeled_interactive.dart';
