// GENERATED FILE - DO NOT EDIT.
// Built-in FAQL rules embedded as string literals for snapshot-friendly CLI.

// Keys are rule codes and values are the FAQL source text.
const Map<String, String> builtinFaqlRules = {
  'a01_unlabeled_interactive': r'''
rule "a01_unlabeled_interactive" on any {
  meta { severity: "warning" code: "a01_unlabeled_interactive" }
  when: enabled && (has_tap || has_long_press)
  ensure: prop("label").is_resolved || ancestors.any(prop("widgetType") == "Semantics" && prop("label").is_resolved)
  report: "Interactive control must have an accessible label"
}
''',
  'a02_avoid_redundant_role_words': r'''
rule "a02_avoid_redundant_role_words" on any {
  meta { severity: "warning" code: "a02_avoid_redundant_role_words" }
  when: enabled && (prop("controlKind") != "none" || has_tap || has_long_press)
  ensure: !(prop("label") matches "(?i)\\b(button|btn|icon|image|link|checkbox|radio|switch|selected|checked|toggle)\\b")
  report: "Label contains redundant role words"
}
''',
  'a03_decorative_images_excluded': r'''
rule "a03_decorative_images_excluded" on type(Image) {
  meta { severity: "warning" code: "a03_decorative_images_excluded" }
  when: prop("assetPath").is_resolved
  // DEPRECATED: generated built-in rules moved to `builtin_faql_rules.g.dart`.
  // Left in place for historical reasons. Do not edit.

}
''',
  'a07_replace_semantics_cleanly': r'''
rule "a07_replace_semantics_cleanly" on type(Semantics) {
  meta {
    severity: "warning"
    code: "a07_replace_semantics_cleanly"
    message: "Semantics replacement doesn't exclude children"
    correction: "Wrap children with ExcludeSemantics to prevent double announcements"
  }

  when:
    prop("labelSource") == "semanticsWidget" &&
    prop("label").is_resolved &&
    !prop("excludesDescendants") &&
    children.length > 0

  ensure:
    prop("labeledChildrenCount") == 0

  report: "Semantics replacement doesn't exclude children"
}
''',
  'a09_numeric_values_require_units': r'''
rule "a09_numeric_values_require_units" on any {
  meta {
    severity: "warning"
    code: "a09_numeric_values_require_units"
    message: "Numeric label should include units"
    correction: "Include units (e.g., 'bpm', '%') in numeric labels"
  }

  when:
    prop("labelGuarantee") == "hasStaticLabel" &&
    prop("label").is_resolved &&
    prop("label") matches "^\\s*\\d+(?:\\.\\d+)?\\s*$"

  ensure:
    !(prop("label") matches "^\\s*\\d+(?:\\.\\d+)?\\s*$")

  report: "Numeric label should include units"
}
''',
  'a13_single_role_composite_control': r'''
rule "a13_single_role_composite_control" on any {
  meta {
    severity: "warning"
    code: "a13_single_role_composite_control"
    message: "Composite control should present a single semantic role"
    correction: "Merge child controls into a single composite control or use MergeSemantics"
  }

  when:
    !focusable &&
    !prop("isPureContainer") &&
    (prop("isSemanticBoundary") || prop("isCompositeControl")) &&
    !(widgetType == "Row") &&
    !(widgetType == "Column") &&
    !(widgetType == "Wrap") &&
    !(widgetType == "Flex") &&
    !(widgetType == "ListView") &&
    !(widgetType == "GridView") &&
    !(widgetType == "Stack") &&
    !(widgetType == "SizedBox") &&
    !(widgetType == "Container") &&
    !(widgetType == "Padding") &&
    !(widgetType == "Center") &&
    !(widgetType == "Align") &&
    !(widgetType == "ListBody") &&
    !(widgetType == "MergeSemantics")

  ensure:
    prop("focusableDescendantCount") < 2

  report: "Composite control should present a single semantic role"
}
''',
  'a15_map_custom_gestures_to_on_tap': r'''
rule "a15_map_custom_gestures_to_on_tap" on type(GestureDetector) {
  meta {
    severity: "warning"
    code: "a15_map_custom_gestures_to_on_tap"
    message: "Custom gestures should surface semantic actions"
    correction: "Add a Semantics( button: true ) or provide an accessible label for GestureDetector"
  }

  when:
    true

  ensure:
    prop("labelGuarantee") != "none" ||
    ancestors.any(widgetType == "Semantics")

  report: "GestureDetector should expose semantic action"
}
''',
  'a21_use_iconbutton_tooltip': r'''
rule "a21_use_iconbutton_tooltip" on type(Tooltip) {
  meta {
    severity: "warning"
    code: "a21_use_iconbutton_tooltip"
    message: "Use the IconButton.tooltip parameter instead of wrapping with Tooltip"
    correction: "Move the tooltip text into the IconButton.tooltip parameter"
  }

  when:
    children.any(prop("controlKind") == "iconButton")

  ensure:
    !children.any(prop("controlKind") == "iconButton" && prop("labelSource") != "tooltip")

  report: "Use IconButton.tooltip parameter instead of Tooltip widget"
}
''',
  'a22_respect_widget_semantic_boundaries': r'''
rule "a22_respect_widget_semantic_boundaries" on type(MergeSemantics) {
  meta {
    severity: "warning"
    code: "a22_respect_widget_semantic_boundaries"
    message: "Avoid wrapping ListTile family widgets in MergeSemantics"
    correction: "Remove the MergeSemantics wrapper to keep the widget's built-in semantics"
  }

  when:
    children.any(
      widgetType == "ListTile" ||
      widgetType == "CheckboxListTile" ||
      widgetType == "SwitchListTile" ||
      widgetType == "RadioListTile"
    )

  ensure:
    false

  report: "ListTile family widgets already merge semantics; remove MergeSemantics wrapper"
}
''',
  'a99_faql_label_required': r'''
rule "a99_faql_label_required" on any {
  meta { severity: "warning" code: "a99_faql_label_required" }
  when: focusable && enabled
  ensure: prop("label").is_resolved || prop("tooltip").is_resolved
  report: "Focusable controls should have a label or tooltip"
}
''',
};
// GENERATED FILE - DO NOT EDIT.
// Built-in FAQL rules embedded as string literals for snapshot-friendly CLI.

// Keys are filenames (not rule codes) and values are the FAQL source text.
const Map<String, String> builtinFaqlRules = {
  'a01_unlabeled_interactive.faql': r'''
rule "a01_unlabeled_interactive" on any {
  meta {
    severity: "warning"
    code: "a01_unlabeled_interactive"
    message: "Interactive control must have an accessible label"
    correction: "Add a tooltip, Text child, or Semantics label"
  }
  when:
    enabled &&
    (has_tap || has_long_press) &&
    (
      prop("controlKind") == "iconButton" ||
      prop("controlKind") == "elevatedButton" ||
      prop("controlKind") == "textButton" ||
      prop("controlKind") == "floatingActionButton" ||
      prop("controlKind") == "filledButton" ||
      prop("controlKind") == "outlinedButton"
    )
  ensure:
    prop("label").is_resolved ||
    ancestors.any(prop("widgetType") == "Semantics" && prop("label").is_resolved)
  report: "Interactive control must have an accessible label"
}
''',
  'a02_avoid_redundant_role_words.faql': r'''
rule "a02_avoid_redundant_role_words" on any {
  meta {
    severity: "warning"
    code: "a02_avoid_redundant_role_words"
    message: "Label contains redundant role words"
    correction: "Remove words like \"button\" or \"icon\"; the role is announced automatically."
  }

  when:
    enabled &&
    (
      prop("controlKind") != "none" ||
      has_tap || has_long_press ||
      prop("hasIncrease") == true ||
      prop("hasDecrease") == true
    ) &&
    prop("labelGuarantee") != "none" &&
    (
      prop("labelSource") == "tooltip" ||
      prop("labelSource") == "semanticsWidget" ||
      prop("labelSource") == "customWidgetParameter" ||
      prop("labelSource") == "inputDecoration" ||
      prop("labelSource") == "other"
    ) &&
    prop("label").is_resolved

  ensure:
    !(prop("label") matches "(?i)\b(button|btn|icon|image|link|checkbox|radio|switch|selected|checked|toggle)\b")

  report: "Label contains redundant role words"
}
''',
  'a03_decorative_images_excluded.faql': r'''
rule "a03_decorative_images_excluded" on type(Image) {
  meta {
    severity: "warning"
    code: "a03_decorative_images_excluded"
    message: "Exclude purely decorative images from semantics"
    correction: "Set excludeFromSemantics: true or provide a semanticLabel for decorative assets."
  }

  when:
    prop("assetPath").is_resolved &&
    (prop("assetPath") matches "(?i)(background|bg|backdrop|decor|decorative|pattern|wallpaper|divider|separator)")

  ensure:
    prop("semanticLabel").is_resolved ||
    prop("label").is_resolved ||
    prop("tooltip").is_resolved ||
    prop("excludeFromSemantics") == true ||
    ancestors.any(widgetType == "ExcludeSemantics" || prop("excludesDescendants") == true)

  report: "Exclude purely decorative images from semantics"
}
''',
  'a04_informative_images_labeled.faql': r'''
rule "a04_informative_images_labeled_circle_avatar" on type(CircleAvatar) {
  meta {
    severity: "warning"
    code: "a04_informative_images_labeled"
    message: "Informative images must provide semantic labels"
    correction: "Add semanticLabel/semanticsLabel or wrap with Semantics label."
  }

  when:
    prop("backgroundImageProvided") == true &&
    !prop("label").is_resolved &&
    !prop("tooltip").is_resolved &&
    !prop("semanticLabel").is_resolved &&
    !prop("semanticsLabel").is_resolved

  ensure:
    ancestors.any(widgetType == "Semantics" && prop("label").is_resolved) ||
    prop("label").is_resolved ||
    prop("tooltip").is_resolved ||
    prop("semanticLabel").is_resolved ||
    prop("semanticsLabel").is_resolved

  report: "Informative images must provide semantic labels"
}
''',
  'a04_informative_images_labeled_listtile.faql': r'''
rule "a04_informative_images_labeled_listtile_image" on type(Image) {
  meta {
    severity: "warning"
    code: "a04_informative_images_labeled"
    message: "Informative images must provide semantic labels"
    correction: "Add semanticLabel or wrap with Semantics label."
  }

  when:
    (prop("imageConstructor") == "network" || prop("imageConstructor") == "file") &&
    ancestors.any(widgetType == "ListTile") &&
    !prop("label").is_resolved &&
    !prop("tooltip").is_resolved &&
    !prop("semanticLabel").is_resolved

  ensure:
    prop("label").is_resolved ||
    prop("tooltip").is_resolved ||
    prop("semanticLabel").is_resolved ||
    ancestors.any(widgetType == "Semantics" && prop("label").is_resolved)

  report: "Informative images must provide semantic labels"
}
''',
  'a05_no_redundant_button_semantics.faql': r'''
rule "a05_no_redundant_button_semantics" on type(Semantics) {
  meta {
    severity: "warning"
    code: "a05_no_redundant_button_semantics"
    message: "Remove redundant Semantics wrapper around button"
    correction: "Remove the Semantics wrapper or provide a custom label instead of button:true."
  }

  when:
    !prop("excludesDescendants") &&
    (
      prop("controlKind") == "iconButton" ||
      prop("controlKind") == "elevatedButton" ||
      prop("controlKind") == "textButton" ||
      prop("controlKind") == "filledButton" ||
      prop("controlKind") == "outlinedButton" ||
      prop("controlKind") == "floatingActionButton" ||
      prop("childWidgetType") == "IconButton" ||
      prop("childWidgetType") == "ElevatedButton" ||
      prop("childWidgetType") == "TextButton" ||
      prop("childWidgetType") == "FilledButton" ||
      prop("childWidgetType") == "OutlinedButton" ||
      prop("childWidgetType") == "FloatingActionButton" ||
      prop("hasButtonDescendant") == true ||
      children.any(
        prop("controlKind") == "iconButton" ||
        prop("controlKind") == "elevatedButton" ||
        prop("controlKind") == "textButton" ||
        prop("controlKind") == "filledButton" ||
        prop("controlKind") == "outlinedButton" ||
        prop("controlKind") == "floatingActionButton"
      )
    )

  ensure:
    (prop("button") != true) &&
    prop("hasMeaningfulSemanticsArgs") == true

  report: "Remove redundant Semantics wrapper around button"
}
''',
  'a06_merge_multi_part_single_concept.faql': r'''
rule "a06_merge_multi_part_single_concept" on any {
  meta {
    severity: "warning"
    code: "a06_merge_multi_part_single_concept"
    message: "Interactive control has multiple semantic parts"
    correction: "Use MergeSemantics to combine icon and text into a single announcement"
  }

  when:
    enabled &&
    (has_tap || has_long_press || prop("hasIncrease") == true || prop("hasDecrease") == true) &&
    children.length >= 2 &&
    !merges_descendants

  ensure:
    prop("labeledChildrenCount") < 2

  report: "Interactive control has multiple semantic parts"
}
''',
  'a07_replace_semantics_cleanly.faql': r'''
rule "a07_replace_semantics_cleanly" on type(Semantics) {
  meta {
    severity: "warning"
    code: "a07_replace_semantics_cleanly"
    message: "Semantics replacement doesn't exclude children"
    correction: "Wrap children with ExcludeSemantics to prevent double announcements"
  }

  when:
    prop("labelSource") == "semanticsWidget" &&
    prop("label").is_resolved &&
    !prop("excludesDescendants") &&
    children.length > 0

  ensure:
    prop("labeledChildrenCount") == 0

  report: "Semantics replacement doesn't exclude children"
}
''',
  'a09_numeric_values_require_units.faql': r'''
rule "a09_numeric_values_require_units" on any {
  meta {
    severity: "warning"
    code: "a09_numeric_values_require_units"
    message: "Numeric label should include units"
    correction: "Include units (e.g., 'bpm', '%') in numeric labels"
  }

  when:
    prop("labelGuarantee") == "hasStaticLabel" &&
    prop("label").is_resolved &&
    prop("label") matches "^\\s*\\d+(?:\\.\\d+)?\\s*$"

  ensure:
    !(prop("label") matches "^\\s*\\d+(?:\\.\\d+)?\\s*$")

  report: "Numeric label should include units"
}
''',
  'a13_single_role_composite_control.faql': r'''
rule "a13_single_role_composite_control" on any {
  meta {
    severity: "warning"
    code: "a13_single_role_composite_control"
    message: "Composite control should present a single semantic role"
    correction: "Merge child controls into a single composite control or use MergeSemantics"
  }

  when:
    !focusable &&
    !prop("isPureContainer") &&
    (prop("isSemanticBoundary") || prop("isCompositeControl")) &&
    !(widgetType == "Row") &&
    !(widgetType == "Column") &&
    !(widgetType == "Wrap") &&
    !(widgetType == "Flex") &&
    !(widgetType == "ListView") &&
    !(widgetType == "GridView") &&
    !(widgetType == "Stack") &&
    !(widgetType == "SizedBox") &&
    !(widgetType == "Container") &&
    !(widgetType == "Padding") &&
    !(widgetType == "Center") &&
    !(widgetType == "Align") &&
    !(widgetType == "ListBody") &&
    !(widgetType == "MergeSemantics")

  ensure:
    prop("focusableDescendantCount") < 2

  report: "Composite control should present a single semantic role"
}
''',
  'a15_map_custom_gestures_to_on_tap.faql': r'''
rule "a15_map_custom_gestures_to_on_tap" on type(GestureDetector) {
  meta {
    severity: "warning"
    code: "a15_map_custom_gestures_to_on_tap"
    message: "Custom gestures should surface semantic actions"
    correction: "Add a Semantics( button: true ) or provide an accessible label for GestureDetector"
  }

  when:
    true

  ensure:
    prop("labelGuarantee") != "none" ||
    ancestors.any(widgetType == "Semantics")

  report: "GestureDetector should expose semantic action"
}
''',
  'a21_use_iconbutton_tooltip.faql': r'''
rule "a21_use_iconbutton_tooltip" on type(Tooltip) {
  meta {
    severity: "warning"
    code: "a21_use_iconbutton_tooltip"
    message: "Use the IconButton.tooltip parameter instead of wrapping with Tooltip"
    correction: "Move the tooltip text into the IconButton.tooltip parameter"
  }

  when:
    children.any(prop("controlKind") == "iconButton")

  ensure:
    !children.any(prop("controlKind") == "iconButton" && prop("labelSource") != "tooltip")

  report: "Use IconButton.tooltip parameter instead of Tooltip widget"
}
''',
  'a22_respect_widget_semantic_boundaries.faql': r'''
rule "a22_respect_widget_semantic_boundaries" on type(MergeSemantics) {
  meta {
    severity: "warning"
    code: "a22_respect_widget_semantic_boundaries"
    message: "Avoid wrapping ListTile family widgets in MergeSemantics"
    correction: "Remove the MergeSemantics wrapper to keep the widget's built-in semantics"
  }

  when:
    children.any(
      widgetType == "ListTile" ||
      widgetType == "CheckboxListTile" ||
      widgetType == "SwitchListTile" ||
      widgetType == "RadioListTile"
    )

  ensure:
    false

  report: "ListTile family widgets already merge semantics; remove MergeSemantics wrapper"
}
''',
  'a99_faql_label_required.faql': r'''
rule "a99_faql_label_required" on any {
  meta { severity: "warning" code: "a99_faql_label_required" }
  when: focusable && enabled
  ensure: prop("label").is_resolved || prop("tooltip").is_resolved
  report: "Focusable controls should have a label or tooltip"
}
''',
};
