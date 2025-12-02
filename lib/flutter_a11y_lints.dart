/// Flutter accessibility analyzer - semantic IR-based accessibility analysis
library;

// Core semantic IR components
export 'src/semantics/semantic_node.dart';
export 'src/semantics/semantic_tree.dart';
export 'src/semantics/semantic_builder.dart';
export 'src/semantics/known_semantics.dart';

// Pipeline components
export 'src/widget_tree/widget_node.dart';
export 'src/pipeline/semantic_ir_builder.dart';

// Rules
export 'src/rules/a01_unlabeled_interactive.dart';

// Utilities
export 'src/utils/type_utils.dart';
export 'src/utils/method_utils.dart';
