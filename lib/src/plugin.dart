import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'rules/a01_label_non_text_controls.dart';
import 'rules/a02_avoid_redundant_role_words.dart';
import 'rules/a03_decorative_images_excluded.dart';
import 'rules/a04_informative_images_labeled.dart';
import 'rules/a05_no_redundant_button_semantics.dart';
import 'rules/a06_merge_multi_part_single_concept.dart';
import 'rules/a07_replace_semantics_cleanly.dart';
import 'rules/a08_block_semantics_only_for_true_modals.dart';
import 'rules/a21_use_iconbutton_tooltip.dart';

// This is the entrypoint of our plugin.
// It simply returns a list of lints to run.
PluginBase createPlugin() => _A11yLints();

class _A11yLints extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        const LabelNonTextControls(), // Uses heuristic analysis (works with custom_lint)
        const AvoidRedundantRoleWords(),
        const DecorativeImagesExcluded(),
        const InformativeImagesLabeled(),
        const NoRedundantButtonSemantics(),
        const MergeMultiPartSingleConcept(),
        const ReplaceSemanticsCleanly(),
        const BlockSemanticsOnlyForTrueModals(),
        const UseIconButtonTooltipParameter(),
      ];
}
