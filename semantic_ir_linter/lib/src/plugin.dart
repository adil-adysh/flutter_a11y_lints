import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'rules/a01_unlabeled_interactive.dart';
import 'rules/a01_simple_test.dart';

/// Entry point used by `custom_lint` to instantiate the semantic IR plugin.
PluginBase createPlugin() => _SemanticIrPlugin();

class _SemanticIrPlugin extends PluginBase {
  _SemanticIrPlugin();

  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        const SimpleIconButtonTestRule(),
        const UnlabeledInteractiveControlsRule(),
      ];
}
