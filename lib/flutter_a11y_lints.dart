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
export 'src/rules/a03_decorative_images_excluded.dart';
export 'src/rules/a04_informative_images_labeled.dart';
export 'src/rules/a05_no_redundant_button_semantics.dart';
export 'src/rules/a06_merge_multi_part_single_concept.dart';
export 'src/rules/a07_replace_semantics_cleanly.dart';
export 'src/rules/a21_use_iconbutton_tooltip.dart';
export 'src/rules/a22_respect_widget_semantic_boundaries.dart';
export 'src/rules/a18_avoid_hidden_focus_traps.dart';
export 'src/rules/a09_numeric_values_require_units.dart';
export 'src/rules/a11_minimum_tap_target_size.dart';
export 'src/rules/a13_single_role_composite_control.dart';
export 'src/rules/a15_map_custom_gestures_to_on_tap.dart';
export 'src/rules/a16_toggle_state_via_semantics_flag.dart';
export 'src/rules/a24_exclude_visual_only_indicators.dart';
export 'src/rules/faql_rule_runner.dart';

// Utilities
export 'src/utils/flutter_utils.dart';
export 'src/utils/method_utils.dart';
