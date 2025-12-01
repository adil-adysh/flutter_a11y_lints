# Flutter Accessibility Lint Rules (Comprehensive Reference)

This document defines the accessibility (a11y) standards enforced by the `flutter_a11y_lints` custom lint plugin. It formalizes required and recommended practices for semantics, focus, roles, structure, and dynamic updates in Flutter applications. Use this as the authoritative reference for understanding and extending the linter rules.

**Version:** 1.0  
**Last Updated:** December 1, 2025  
**Maintainer:** flutter_a11y_lints contributors

---

## 1. Core Principles

The linter enforces these fundamental accessibility principles:

- **Perceivable**: All meaningful UI is exposed with clear role, label, value, and state to assistive technologies.
- **Operable**: Every interactive element is focusable and activatable via keyboard (Enter/Space) and assistive tech gestures.
- **Understandable**: Labels are concise, non-redundant, and predictable; state changes are announced only when meaningful.
- **Robust**: Prefer built-in Material/Cupertino semantics; override minimally and intentionally.

---

## 2. Decision Flow (High-Level)

When analyzing Flutter widgets for accessibility, the linter follows this logic:

1. **Is the widget interactive?** If yes, ensure proper base widget (Button, IconButton, InkWell, GestureDetector + Semantics, etc.).
2. **Does the framework already provide correct semantics?** If yes, do not wrap with extra `Semantics` unless adding unique information.
3. **Is the element purely decorative?** Exclude from semantics using `excludeFromSemantics: true` or `ExcludeSemantics`.
4. **Are multiple visual parts one logical control/value?** Merge or replace semantics appropriately.
5. **Is content hidden visually?** Remove from semantics unless intentionally exposed.

---

## 3. Semantics Toolkit Overview

| Widget / Property | Use Case | Linter Enforcement |
|-------------------|----------|-------------------|
| `Semantics` | Add/override label, value, hint, flags | Must not duplicate built-in button semantics |
| `MergeSemantics` | Fuse descendants into one node | Required for multi-part single control/value |
| `ExcludeSemantics` | Strip descendant semantics | Required when replacing semantics |
| `BlockSemantics` | Block traversal to background | Only allowed for modals/blocking overlays |
| `IndexedSemantics` | Provide stable index in builders | Recommended for large virtualized lists |
| `Focus` / `FocusableActionDetector` | Custom focus + key handling | Must provide semantic focus path |
| `SemanticsService.announce` | Live region announcement | Must be debounced; critical updates only |
| `tooltip` parameter | Built-in label for IconButton, etc. | Preferred over `Tooltip` widget wrapper |

---

## 4. Implemented Lint Rules

### Category: Labels & Text (Rules A01-A04)

#### **A01: Label Non-Text Controls** (`flutter_a11y_label_non_text_controls`)

**Severity:** WARNING

**Description:**  
All icon-only or custom painted interactive controls must have an accessible label source (tooltip parameter or Semantics.label).

**Rationale:**  
Screen reader users cannot perceive visual-only affordances. Every interactive element needs a text equivalent.

**Detects:**

- `IconButton` without `tooltip` parameter
- Interactive widgets (InkWell, GestureDetector) wrapping only visual elements (Icon, Image, CustomPaint) without Semantics label

**Violation Example:**

```dart
IconButton(
  icon: Icon(Icons.refresh),
  onPressed: onRefresh,
) // ❌ No tooltip
```

**Correct Pattern:**

```dart
IconButton(
  icon: Icon(Icons.refresh),
  onPressed: onRefresh,
  tooltip: 'Refresh data', // ✅ Accessible label
)
```

---

#### **A02: Avoid Redundant Role Words** (`flutter_a11y_avoid_redundant_role_words`)

**Severity:** WARNING

**Description:**  
Do not include words like "button", "selected", "toggle" in labels that are already conveyed by the widget's semantic role or state.

**Rationale:**  
Screen readers announce the role automatically. Including it in the label creates redundant announcements: "Save button, button".

**Detects:**

- `tooltip` or `Semantics.label` containing words: "button", "icon", "image", "link", "checkbox", "radio", "switch", "selected", "checked"

**Violation Example:**

```dart
IconButton(
  tooltip: 'Save button', // ❌ Redundant "button"
  icon: Icon(Icons.save),
  onPressed: onSave,
)
```

**Correct Pattern:**

```dart
IconButton(
  tooltip: 'Save', // ✅ Role announced automatically
  icon: Icon(Icons.save),
  onPressed: onSave,
)
```

---

#### **A03: Decorative Images Excluded** (`flutter_a11y_decorative_images_excluded`)

**Severity:** WARNING

**Description:**  
Pure decorative images (backgrounds, visual flourishes) must be excluded from the semantic tree using `excludeFromSemantics: true`.

**Rationale:**  
Screen readers should skip non-informative visual elements to avoid clutter and confusion.

**Detects:**

- `Image` widgets without `semanticLabel` and without `excludeFromSemantics: true`
- Common decorative patterns (e.g., assets named "background", "decoration", "pattern")

**Violation Example:**

```dart
Image.asset('assets/background_pattern.png') // ❌ Not excluded
```

**Correct Pattern:**

```dart
Image.asset(
  'assets/background_pattern.png',
  excludeFromSemantics: true, // ✅ Decorative only
)
```

---

#### **A04: Informative Images Labeled** (`flutter_a11y_informative_images_labeled`)

**Severity:** WARNING

**Description:**  
Meaningful images (product photos, icons conveying information, avatars) must have a `semanticLabel` describing their content.

**Rationale:**  
Screen reader users need text descriptions of visual information to understand context.

**Detects:**

- `Image` widgets with content assets (not decorative patterns) missing `semanticLabel`
- Heuristics: assets named with content keywords (e.g., "photo", "avatar", "product")

**Violation Example:**

```dart
Image.network(
  user.avatarUrl,
) // ❌ No semantic label
```

**Correct Pattern:**

```dart
Image.network(
  user.avatarUrl,
  semanticLabel: '${user.name} profile photo', // ✅ Descriptive label
)
```

---

### Category: Button & Control Semantics (Rules A05, A21)

#### **A05: No Redundant Button Semantics** (`flutter_a11y_no_redundant_semantics_wrappers_on_material_buttons`)

**Severity:** WARNING

**Description:**  
Never wrap Material buttons (IconButton, ElevatedButton, FilledButton, TextButton, etc.) with `Semantics(button: true)`. These widgets already provide complete button semantics automatically.

**Rationale:**  
Creates duplicate button announcements: "Save, button, button". The built-in button semantics are sufficient.

**Detects:**

- `Semantics` wrapping Material button widgets
- `Semantics` with `button: true` property wrapping button-type widgets

**Violation Example:**

```dart
Semantics(
  label: 'Delete item',
  button: true, // ❌ Redundant
  child: IconButton(
    icon: Icon(Icons.delete),
    onPressed: onDelete,
  ),
) // Screen reader: "Delete item, button, button"
```

**Correct Pattern:**

```dart
IconButton(
  icon: Icon(Icons.delete),
  onPressed: onDelete,
  tooltip: 'Delete item', // ✅ Single button announcement
)
```

**Applies To:**

- IconButton
- ElevatedButton
- FilledButton, FilledButton.tonal, FilledButton.icon
- TextButton
- OutlinedButton
- FloatingActionButton

---

#### **A21: Use IconButton Tooltip Parameter** (`flutter_a11y_use_iconbutton_tooltip`)

**Severity:** WARNING

**Description:**  
Always use IconButton's built-in `tooltip` parameter instead of wrapping with `Tooltip()` widget. The wrapper creates redundant semantic nodes.

**Rationale:**  
IconButton has a built-in tooltip designed for accessibility. Using the Tooltip widget wrapper complicates the semantic tree unnecessarily.

**Detects:**

- `Tooltip` widget wrapping `IconButton`
- Suggests using `tooltip` parameter instead

**Violation Example:**

```dart
Tooltip(
  message: 'Save session',
  child: IconButton( // ❌ Redundant wrapper
    icon: Icon(Icons.check),
    onPressed: onSave,
  ),
)
```

**Correct Pattern:**

```dart
IconButton(
  icon: Icon(Icons.check),
  onPressed: onSave,
  tooltip: 'Save session', // ✅ Clean semantic tree
)
```

---

### Category: Semantic Structure (Rules A06-A08)

#### **A06: Merge Multi-Part Single Concept** (`flutter_a11y_merge_multi_part_single_concept`)

**Severity:** WARNING

**Description:**  
Use `MergeSemantics` or replacement pattern for composite values/controls that should be announced as one unit (e.g., icon + text, number + unit).

**Rationale:**  
Without merging, screen readers navigate to each element separately, breaking up the logical concept and confusing users.

**Detects:**

- Interactive `Row`/`Column` with multiple text/icon children without `MergeSemantics`
- Multiple semantic nodes that represent a single control

**Violation Example:**

```dart
InkWell(
  onTap: save,
  child: Row(
    children: [
      Icon(Icons.save), // ❌ Read separately
      Text('Save'),     // ❌ Read separately
    ],
  ),
)
// Screen reader navigates: "save icon" → next → "Save text"
```

**Correct Pattern:**

```dart
MergeSemantics(
  child: InkWell(
    onTap: save,
    child: Row(
      children: [
        Icon(Icons.save),
        Text('Save'),
      ],
    ),
  ),
) // ✅ Announced as single unit: "Save, button"
```

---

#### **A07: Replace Semantics Cleanly** (`flutter_a11y_replace_semantics_cleanly`)

**Severity:** WARNING

**Description:**  
When overriding subtree semantics with a custom label, wrap children in `ExcludeSemantics` to prevent both original and replacement labels from being read.

**Rationale:**  
Without exclusion, screen readers announce both the original text and the replacement, creating confusing double announcements.

**Detects:**

- `Semantics` with `label` property containing children that have their own text/semantics
- Missing `ExcludeSemantics` on children being replaced

**Violation Example:**

```dart
Semantics(
  label: 'Mood score 72, up 2 today', // ❌ Children also read
  child: Row(
    children: [
      Text('72'),
      Icon(Icons.trending_up),
      Text('+2'),
    ],
  ),
)
// Announces: "Mood score 72, up 2 today, 72, trending up, +2"
```

**Correct Pattern:**

```dart
Semantics(
  label: 'Mood score 72, up 2 today',
  child: ExcludeSemantics( // ✅ Children excluded
    child: Row(
      children: [
        Text('72'),
        Icon(Icons.trending_up),
        Text('+2'),
      ],
    ),
  ),
)
// Announces: "Mood score 72, up 2 today" (once)
```

---

#### **A08: Block Semantics Only for True Modals** (`flutter_a11y_block_semantics_only_for_true_modals`)

**Severity:** WARNING

**Description:**  
Use `BlockSemantics` only for dialogs, drawers, bottom sheets, and overlays that must trap focus. Do not use for snackbars, banners, or non-blocking UI.

**Rationale:**  
`BlockSemantics` prevents screen readers from accessing background content. Misuse creates accessibility barriers where users cannot navigate the full UI.

**Detects:**

- `BlockSemantics` usage patterns that don't match modal overlays
- Heuristics for non-modal contexts (e.g., not within showDialog, showModalBottomSheet)

**Violation Example:**

```dart
BlockSemantics( // ❌ Snackbar should not block
  child: SnackBar(
    content: Text('Item saved'),
  ),
)
```

**Correct Pattern:**

```dart
// ✅ Modals only
showDialog(
  context: context,
  builder: (context) => BlockSemantics(
    child: AlertDialog(
      title: Text('Confirm'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('OK'),
        ),
      ],
    ),
  ),
)

// ✅ Snackbars without BlockSemantics
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Item saved')),
)
```

---

## 5. Design Patterns & Best Practices

### Pattern 1: Semantics Replacement (Composite Values)

**Use when:** Multiple visual elements represent a single logical value that needs a custom announcement.

```dart
Semantics(
  label: 'Mood score 72, up 2 points today',
  child: ExcludeSemantics(
    child: Row(
      children: [
        Text('72', style: TextStyle(fontSize: 48)),
        Icon(Icons.trending_up, color: Colors.green),
        Text('+2', style: TextStyle(color: Colors.green)),
      ],
    ),
  ),
)
```

---

### Pattern 2: Composite Control (Single Interactive Unit)

**Use when:** Icon and text together form one interactive control.

```dart
MergeSemantics(
  child: InkWell(
    onTap: () => saveEntry(),
    child: Row(
      children: [
        Icon(Icons.save),
        SizedBox(width: 8),
        Text('Save Entry'),
      ],
    ),
  ),
)
```

---

### Pattern 3: Custom Painted Interactive Region

**Use when:** CustomPaint or low-level graphics need interactive semantics.

```dart
Semantics(
  button: true,
  label: 'Play meditation audio',
  onTap: () => playAudio(),
  child: CustomPaint(
    painter: CircularPlayButtonPainter(),
    size: Size(64, 64),
  ),
)
```

---

### Pattern 4: Decorative Visual Indicators

**Use when:** Visual elements serve only aesthetic or redundant purposes.

```dart
ListTile(
  leading: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ExcludeSemantics(child: Icon(Icons.drag_handle)), // Visual affordance
      ExcludeSemantics(child: CircleAvatar(child: Text('1'))), // Position
      ExcludeSemantics(child: Icon(Icons.mail_outline)), // Content type
    ],
  ),
  title: Text('1. Email Subject'), // ✅ Position in text
  subtitle: Text('Preview text...'),
  trailing: IconButton(
    icon: Icon(Icons.delete),
    tooltip: 'Delete Email Subject', // ✅ Contextual label
    onPressed: onDelete,
  ),
)
```

---

### Pattern 5: Live Announcements with Throttling

**Use when:** Dynamic content updates need to be announced (e.g., timers, progress).

```dart
class ThrottledAnnouncer {
  DateTime? _lastAnnounce;
  
  void announce(String message, BuildContext context) {
    final now = DateTime.now();
    if (_lastAnnounce == null || 
        now.difference(_lastAnnounce!).inMilliseconds > 900) {
      SemanticsService.announce(
        message,
        Directionality.of(context),
      );
      _lastAnnounce = now;
    }
  }
}

// Usage:
_announcer.announce('Timer: ${minutes}:${seconds}', context);
```

---

## 6. Widget-Specific Guidelines

### Lists & Virtualization

- Use default `ListView` unless custom slivers require manual indices
- For custom slivers: wrap item builder children in `IndexedSemantics(index: i, child: ...)`
- Provide concise labels; avoid repeating category names on every row
- Exclude decorative visual indicators (drag handles, position badges)
- Include position information in title text: "1. First Item"

### Dialogs & Overlays

- Apply `BlockSemantics` at modal root
- First focus target: title or primary action
- Announce on open only once
- Don't block for snackbars, tooltips, or non-modal feedback

### Forms

- `TextField` uses `labelText` as accessible label
- Use `helperText` for guidance, `errorText` for validation
- For immediate error while focused, optional single announce
- Don't wrap form fields with redundant `Semantics`

### Buttons & Interactive Controls

- **IconButton**: Use `tooltip` parameter for labels
- **Material buttons**: Never wrap with `Semantics(button: true)`
- **Custom gestures**: Map to `onTap` semantics for CustomPaint or low-level widgets
- **Toggle state**: Use `toggled`/`selected` flags rather than embedding in label

---

## 7. Contextual Button Labels (Rule A23 - Planned)

**Concept:** Button labels should include context when the action target isn't obvious from surrounding content. Essential for icon-only buttons in lists or grids.

**Anti-Pattern:**

```dart
ListView.builder(
  itemBuilder: (context, index) {
    return ListTile(
      title: Text(items[index].title),
      trailing: IconButton(
        icon: Icon(Icons.delete),
        tooltip: 'Delete', // ❌ Delete what?
        onPressed: () => delete(items[index]),
      ),
    );
  },
)
```

**Correct Pattern:**

```dart
ListView.builder(
  itemBuilder: (context, index) {
    final item = items[index];
    return ListTile(
      title: Text(item.title),
      trailing: IconButton(
        icon: Icon(Icons.delete),
        tooltip: 'Delete ${item.title}', // ✅ Clear target
        onPressed: () => delete(item),
      ),
    );
  },
)
```

---

## 8. Performance Considerations

- Avoid rebuilding `Semantics` with per-frame changes (e.g., progress animation)
- Only update semantic properties when values meaningfully change
- Prefer combining nodes over deeply nested `Semantics` wrappers
- Use `const` constructors where possible for static semantic widgets

---

## 9. Testing Checklist

Use this checklist to verify accessibility compliance:

- [ ] TalkBack/VoiceOver read order matches visual order
- [ ] No duplicate announcements (e.g., "button, button")
- [ ] All interactive elements have accessible labels
- [ ] Minimum tap target size >= 48x48 dp (44 iOS)
- [ ] Decorative images excluded from semantics
- [ ] Informative images have semantic labels
- [ ] Multi-part values announced as single unit
- [ ] Dynamic updates don't spam announcements
- [ ] Modals block background, non-modals don't
- [ ] Button labels contextual in lists/grids

---

## 10. Lint Rule Development Guidelines

### Adding a New Rule

1. **Create rule file**: `lib/src/rules/aXX_rule_name.dart`
2. **Extend `DartLintRule`**: Define `LintCode` with name, message, severity
3. **Implement `run` method**: Use `context.registry` to register node visitors
4. **Register in plugin**: Add to `lib/src/plugin.dart`
5. **Write tests**: Create `test/rules/aXX_rule_name_test.dart`
6. **Document here**: Add to section 4 with examples

### Coding Standards

**Import Pattern** (always hide LintCode to avoid conflicts):

```dart
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
```

**Rule Structure**:

```dart
class RuleName extends DartLintRule {
  const RuleName() : super(code: _code);

  static const _code = LintCode(
    name: 'flutter_a11y_rule_name',
    problemMessage: 'Clear description of the issue',
    correctionMessage: 'Actionable fix suggestion',
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Async setup in callback, not in registry
    context.addPostRunCallback(() async {
      final result = await resolver.getResolvedUnitResult();
      final unit = result.unit;
      
      if (!fileUsesFlutter(unit)) return;
      
      // Register synchronous node visitors
      context.registry.addInstanceCreationExpression((node) {
        // Rule logic here
        if (violationDetected) {
          reporter.atNode(node).report(_code);
        }
      });
    });
  }
}
```

**Key Points:**

- Use `addPostRunCallback` for async operations (never mark registry callbacks as async)
- Always check `fileUsesFlutter(unit)` before running Flutter-specific checks
- Use `reporter.atNode(node).report(code)` for error reporting
- Leverage utility functions in `lib/src/utils/` for common checks

---

## 11. Rule Enforcement Workflow (AI-Assisted)

When reviewing code for accessibility compliance:

1. **Scan diff** for widget additions/changes
2. **For each interactive widget**: Verify label source present
3. **Flag redundant semantics**: Any `Semantics` around standard buttons without added properties
4. **Check images**: Ensure `semanticLabel` or `excludeFromSemantics: true`
5. **Identify multi-part values**: Row/Column with number + icon + text → require merge/replace
6. **Validate BlockSemantics**: Only in modal contexts
7. **List violations** by ID with fix suggestions

---

## 12. Future Rule Roadmap

### Planned Rules (Not Yet Implemented)

- **A09**: Provide units in numeric values (sliders, stats include units if not implicit)
- **A10**: Debounce live announcements (max ~1/sec for dynamic updates)
- **A11**: Minimum tap target size (interactive area >= 48x48 dp)
- **A12**: Focus order matches visual order
- **A13**: Single interactive role (composite control doesn't create multiple nodes)
- **A14**: Validation feedback accessible (error messages reachable/announced)
- **A15**: Custom gestures mirrored (custom tap/activate maps to onTap semantics)
- **A16**: Toggle state via semantics flag (use toggled/selected rather than embedding in label)
- **A17**: Use hint only for operation (hints describe action, not restating label)
- **A18**: Avoid hidden focus traps (no offstage/focusable controls left reachable)
- **A19**: Reason for disabled optional (no redundant label changes for disabled state)
- **A20**: Announce async success once (async completion announced once, not repeatedly)
- **A22**: Respect widget semantic boundaries (don't wrap ListTile, Card children with MergeSemantics)
- **A23**: Contextual button labels (include item identifier in list/grid button labels)
- **A24**: Exclude visual-only indicators (drag handles, position badges from semantic tree)

### Recommended Practices (R-Series)

- **R01**: Group related stats under one header semantics
- **R02**: Provide step counts for multi-step wizards in hint ("Step 2 of 5")
- **R03**: Provide `semanticFormatterCallback` for sliders requiring custom string
- **R04**: Use tooltips for frequently reused icon actions (refresh, settings)
- **R05**: Use `header: true` for list section titles

---

## 13. References

### Flutter Documentation

- [Flutter Accessibility Guide](https://docs.flutter.dev/development/accessibility-and-localization/accessibility)
- [Semantics API Documentation](https://api.flutter.dev/flutter/widgets/Semantics-class.html)
- [SemanticsProperties](https://api.flutter.dev/flutter/semantics/SemanticsProperties-class.html)

### Web Content Accessibility Guidelines (WCAG)

- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [WCAG 2.1 Level A & AA Success Criteria](https://www.w3.org/WAI/WCAG21/Understanding/)

### Custom Lint Framework

- [custom_lint Package](https://pub.dev/packages/custom_lint)
- [custom_lint_builder API](https://pub.dev/documentation/custom_lint_builder/latest/)
- [analyzer Package](https://pub.dev/packages/analyzer)

### Screen Reader Testing

- [Android TalkBack Guide](https://support.google.com/accessibility/android/answer/6283677)
- [iOS VoiceOver Guide](https://support.apple.com/guide/iphone/turn-on-and-practice-voiceover-iph3e2e415f/ios)

---

## 14. Contributing

### Proposing New Rules

1. Open an issue describing the accessibility problem
2. Provide examples of violations and correct patterns
3. Reference WCAG success criteria if applicable
4. Discuss feasibility of automated detection
5. Submit PR with rule implementation + tests + documentation update

### Updating This Document

- **Process**: PR + review from at least one maintainer
- **Format**: Keep examples concise, use code blocks for patterns
- **Versioning**: Update version number and date at top
- **Cross-references**: Link to related rules and Flutter docs

---

## 15. Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-01 | Initial comprehensive reference based on 9 implemented rules |

---

**Maintained by:** flutter_a11y_lints contributors  
**License:** See repository LICENSE file  
**Feedback:** Open issues on GitHub repository
