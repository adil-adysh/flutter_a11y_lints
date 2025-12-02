/// Flutter accessibility analyzer - semantic IR-based accessibility analysis
library;

// Core semantic IR components
export 'src/semantics/semantic_node.dart';
export 'src/semantics/semantic_tree.dart';
export 'src/semantics/semantic_builder.dart';
export 'src/semantics/semantic_context.dart';
export 'src/semantics/known_semantics.dart';
export 'src/semantics/semantic_neighborhood.dart';

// Pipeline components
export 'src/widget_tree/widget_node.dart';
export 'src/pipeline/semantic_ir_builder.dart';

// Rules
export 'src/rules/a01_unlabeled_interactive.dart';
export 'src/rules/a02_avoid_redundant_role_words.dart';
export 'src/rules/a06_merge_multi_part_single_concept.dart';
export 'src/rules/a07_replace_semantics_cleanly.dart';

// Utilities
export 'src/utils/flutter_utils.dart';
export 'src/utils/method_utils.dart';
