# 📄 Known Widget Semantics Generation Pipeline

**Location:** `tool/semantics_generator`  
**Purpose:** Automatically generate and update the `KnownWidgetSemantics` table that the linter uses to understand default semantics of core Flutter widgets.  
**Usage:** Run whenever you upgrade the Flutter SDK version you support.

---

## 1. What This Pipeline Does

This pipeline runs **offline** (only when maintaining the linter), not during linting.

It:

1. Instantiates a curated set of Flutter widgets in a **headless test environment** (`flutter_test`)
2. Extracts their runtime **`SemanticsNode`** data (flags + actions)
3. Dumps that info into a JSON file
4. Generates a Dart source file: `lib/src/utils/known_widget_semantics.dart`

This becomes the single source of truth for the linter's understanding of built-in widget semantics.

**Key Advantage:** Zero manual guesswork about Flutter's semantic behavior. The data comes directly from Flutter's runtime.

---

## 2. Directory Layout

```
root/
 ├─ tool/
 │   └─ semantics_generator/
 │        ├─ widget_catalogue.dart          # Which widgets to test + how to build them
 │        ├─ extract_semantics_test.dart    # flutter_test-based extractor
 │        ├─ semantics_dump.json            # Runtime semantics output (generated)
 │        └─ generate_source.dart           # JSON → Dart codegen
 │
 └─ lib/
     └─ src/
         └─ utils/
              ├─ widget_semantics_info.dart     # Model type
              └─ known_widget_semantics.dart    # GENERATED; used by linter
```

---

## 3. Core Data Types

### 3.1 `WidgetSemanticsInfo`

**File:** `lib/src/utils/widget_semantics_info.dart`

```dart
import '../types/semantic_role.dart';

/// Information about a widget's default semantic behavior
class WidgetSemanticsInfo {
  /// The semantic role this widget represents
  final SemanticRole role;
  
  /// Whether the widget is interactive by default
  final bool isInteractive;
  
  /// Whether the widget merges its children's semantics
  final bool mergesChildren;
  
  /// Whether the widget manages its own semantics completely
  final bool semanticsManaged;
  
  /// Whether the widget has a tooltip parameter
  final bool hasTooltipParam;
  
  /// Whether the widget has a semanticLabel parameter
  final bool hasSemanticLabelParam;

  const WidgetSemanticsInfo({
    required this.role,
    this.isInteractive = false,
    this.mergesChildren = false,
    this.semanticsManaged = false,
    this.hasTooltipParam = false,
    this.hasSemanticLabelParam = false,
  });

  factory WidgetSemanticsInfo.unknown() =>
      const WidgetSemanticsInfo(role: SemanticRole.unknown);
}
```

### 3.2 `SemanticRole`

**File:** `lib/src/types/semantic_role.dart`

```dart
/// Semantic roles for widgets
enum SemanticRole {
  button,       // Interactive button
  toggle,       // Switch, Checkbox, Radio
  image,        // Image widget
  text,         // Static text
  input,        // TextField, TextFormField
  slider,       // Slider, RangeSlider
  header,       // Header/title
  listItem,     // ListTile, etc.
  group,        // Container/grouping
  link,         // Link/navigation
  tab,          // Tab
  unknown,      // Unknown or custom
}
```

---

## 4. Component 1 — Widget Catalogue

**File:** `tool/semantics_generator/widget_catalogue.dart`  
**Responsibility:** Define a canonical set of widget constructors used for semantics extraction.

This is the **only** place you need to modify when adding/removing widgets from the semantics map.

### 4.1 Structure

Each entry specifies:
- A human-readable name (usually the widget class name)
- The `Type` of the widget
- A zero-arg builder that returns a valid instance (all required params given)

### 4.2 Example Implementation

```dart
import 'package:flutter/material.dart';

typedef WidgetBuilderFactory = Widget Function();

class WidgetCatalogueEntry {
  final String name;
  final Type type;
  final WidgetBuilderFactory builder;

  const WidgetCatalogueEntry(this.name, this.type, this.builder);
}

final List<WidgetCatalogueEntry> widgetCatalogue = [
  // ============================================================
  // Buttons & Interactive Controls
  // ============================================================
  
  WidgetCatalogueEntry(
    'IconButton',
    IconButton,
    () => IconButton(
      onPressed: () {},
      icon: const Icon(Icons.add),
      tooltip: 'Test',
    ),
  ),
  
  WidgetCatalogueEntry(
    'ElevatedButton',
    ElevatedButton,
    () => ElevatedButton(
      onPressed: () {},
      child: const Text('Button'),
    ),
  ),
  
  WidgetCatalogueEntry(
    'TextButton',
    TextButton,
    () => TextButton(
      onPressed: () {},
      child: const Text('Button'),
    ),
  ),
  
  WidgetCatalogueEntry(
    'OutlinedButton',
    OutlinedButton,
    () => OutlinedButton(
      onPressed: () {},
      child: const Text('Button'),
    ),
  ),
  
  WidgetCatalogueEntry(
    'FilledButton',
    FilledButton,
    () => FilledButton(
      onPressed: () {},
      child: const Text('Button'),
    ),
  ),
  
  WidgetCatalogueEntry(
    'FloatingActionButton',
    FloatingActionButton,
    () => FloatingActionButton(
      onPressed: () {},
      child: const Icon(Icons.add),
    ),
  ),

  // ============================================================
  // Toggles
  // ============================================================
  
  WidgetCatalogueEntry(
    'Switch',
    Switch,
    () => Switch(
      value: true,
      onChanged: (_) {},
    ),
  ),
  
  WidgetCatalogueEntry(
    'Checkbox',
    Checkbox,
    () => Checkbox(
      value: true,
      onChanged: (_) {},
    ),
  ),
  
  WidgetCatalogueEntry(
    'Radio',
    Radio,
    () => Radio<int>(
      value: 1,
      groupValue: 1,
      onChanged: (_) {},
    ),
  ),
  
  WidgetCatalogueEntry(
    'SwitchListTile',
    SwitchListTile,
    () => SwitchListTile(
      value: true,
      onChanged: (_) {},
      title: const Text('Switch'),
    ),
  ),
  
  WidgetCatalogueEntry(
    'CheckboxListTile',
    CheckboxListTile,
    () => CheckboxListTile(
      value: true,
      onChanged: (_) {},
      title: const Text('Checkbox'),
    ),
  ),
  
  WidgetCatalogueEntry(
    'RadioListTile',
    RadioListTile,
    () => RadioListTile<int>(
      value: 1,
      groupValue: 1,
      onChanged: (_) {},
      title: const Text('Radio'),
    ),
  ),

  // ============================================================
  // Input Fields
  // ============================================================
  
  WidgetCatalogueEntry(
    'TextField',
    TextField,
    () => const TextField(
      decoration: InputDecoration(labelText: 'Input'),
    ),
  ),
  
  WidgetCatalogueEntry(
    'TextFormField',
    TextFormField,
    () => const TextFormField(
      decoration: InputDecoration(labelText: 'Form Input'),
    ),
  ),

  // ============================================================
  // Sliders
  // ============================================================
  
  WidgetCatalogueEntry(
    'Slider',
    Slider,
    () => Slider(
      value: 0.5,
      onChanged: (_) {},
    ),
  ),

  // ============================================================
  // Structure & Layout
  // ============================================================
  
  WidgetCatalogueEntry(
    'ListTile',
    ListTile,
    () => const ListTile(
      title: Text('Title'),
      subtitle: Text('Subtitle'),
    ),
  ),
  
  WidgetCatalogueEntry(
    'Card',
    Card,
    () => const Card(
      child: Text('Card content'),
    ),
  ),

  // ============================================================
  // Images & Icons
  // ============================================================
  
  WidgetCatalogueEntry(
    'Image',
    Image,
    () => Image.network(
      'https://example.com/image.png',
      semanticLabel: 'Example image',
    ),
  ),
  
  WidgetCatalogueEntry(
    'Icon',
    Icon,
    () => const Icon(Icons.home),
  ),
  
  WidgetCatalogueEntry(
    'CircleAvatar',
    CircleAvatar,
    () => const CircleAvatar(
      child: Text('A'),
    ),
  ),

  // ============================================================
  // Text
  // ============================================================
  
  WidgetCatalogueEntry(
    'Text',
    Text,
    () => const Text('Sample text'),
  ),

  // ============================================================
  // Semantic Containers
  // ============================================================
  
  WidgetCatalogueEntry(
    'Semantics',
    Semantics,
    () => const Semantics(
      label: 'Test label',
      child: Text('Content'),
    ),
  ),
  
  WidgetCatalogueEntry(
    'MergeSemantics',
    MergeSemantics,
    () => const MergeSemantics(
      child: Row(
        children: [
          Icon(Icons.star),
          Text('Merged'),
        ],
      ),
    ),
  ),
  
  WidgetCatalogueEntry(
    'ExcludeSemantics',
    ExcludeSemantics,
    () => const ExcludeSemantics(
      child: Icon(Icons.decorative),
    ),
  ),
  
  WidgetCatalogueEntry(
    'BlockSemantics',
    BlockSemantics,
    () => const BlockSemantics(
      child: Text('Blocked'),
    ),
  ),

  // ============================================================
  // Layout Containers
  // ============================================================
  
  WidgetCatalogueEntry(
    'Row',
    Row,
    () => const Row(
      children: [Text('A'), Text('B')],
    ),
  ),
  
  WidgetCatalogueEntry(
    'Column',
    Column,
    () => const Column(
      children: [Text('A'), Text('B')],
    ),
  ),
  
  WidgetCatalogueEntry(
    'Wrap',
    Wrap,
    () => const Wrap(
      children: [Text('A'), Text('B')],
    ),
  ),
];
```

### 4.3 Guidelines for Widget Selection

**Choose configurations that reveal semantics:**
- **Buttons:** `onPressed` should be non-null to show interactivity
- **Toggles:** Include both `value` and `onChanged`
- **ListTile:** Include title/subtitle to show merging behavior
- **Image:** Use `semanticLabel` to demonstrate label extraction

**Avoid:**
- Overly complex widget trees
- Custom widgets (focus on Flutter built-ins)
- Disabled states (use enabled state to capture full semantics)

---

## 5. Component 2 — Semantics Extractor

**File:** `tool/semantics_generator/extract_semantics_test.dart`  
**Responsibility:** Run via `flutter test` to extract runtime semantics data.

### 5.1 Implementation

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_catalogue.dart';

void main() {
  testWidgets('Extract widget semantics to JSON', (WidgetTester tester) async {
    final extractedData = <String, Map<String, dynamic>>{};

    for (final entry in widgetCatalogue) {
      final name = entry.name;
      final type = entry.type;
      final builder = entry.builder;

      // Build minimal app with the widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (_) => builder(),
            ),
          ),
        ),
      );

      // Enable semantics
      final handle = tester.ensureSemantics();

      // Find the widget
      final finder = find.byType(type);
      expect(finder, findsOneWidget, reason: 'Could not find widget $name');

      // Get render object and semantics
      final element = finder.evaluate().first;
      final renderObject = element.renderObject;
      final rootSemantics = renderObject?.debugSemantics;
      final node = _findRelevantSemanticsNode(rootSemantics);

      if (node != null) {
        final data = node.getSemanticsData();
        
        // Extract semantic flags and actions
        extractedData[name] = {
          // Flags
          'isButton': data.hasFlag(SemanticsFlag.isButton),
          'isImage': data.hasFlag(SemanticsFlag.isImage),
          'isToggled': data.hasFlag(SemanticsFlag.isToggled),
          'isChecked': data.hasFlag(SemanticsFlag.isChecked),
          'isLink': data.hasFlag(SemanticsFlag.isLink),
          'isSlider': data.hasFlag(SemanticsFlag.isSlider),
          'isTextField': data.hasFlag(SemanticsFlag.isTextField),
          'isHeader': data.hasFlag(SemanticsFlag.namesRoute) ||
              data.hasFlag(SemanticsFlag.isHeader),
          'isFocusable': data.hasFlag(SemanticsFlag.isFocusable),
          'isInMutuallyExclusiveGroup': 
              data.hasFlag(SemanticsFlag.isInMutuallyExclusiveGroup),
          
          // Actions (interactivity)
          'hasTap': data.hasAction(SemanticsAction.tap),
          'hasLongPress': data.hasAction(SemanticsAction.longPress),
          'hasIncrease': data.hasAction(SemanticsAction.increase),
          'hasDecrease': data.hasAction(SemanticsAction.decrease),
          
          // Structure
          'hasChildren': node.mergeAllDescendantsIntoThisNode || node.childrenCount > 0,
          'childCount': node.childrenCount,
          'mergesDescendants': node.mergeAllDescendantsIntoThisNode,
          
          // Content
          'label': data.label,
          'hint': data.hint,
          'value': data.value,
        };
      } else {
        // No semantics found - record as unknown
        extractedData[name] = {
          'isButton': false,
          'isImage': false,
          'isToggled': false,
          'isChecked': false,
          'isLink': false,
          'isSlider': false,
          'isTextField': false,
          'isHeader': false,
          'isFocusable': false,
          'hasTap': false,
          'hasChildren': false,
          'childCount': 0,
        };
      }

      // Clean up
      handle.dispose();
      await tester.pumpAndSettle();
    }

    // Write to JSON file
    final file = File('tool/semantics_generator/semantics_dump.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(extractedData),
    );
    
    print('✓ Extracted semantics for ${extractedData.length} widgets');
    print('✓ Written to ${file.path}');
  });
}

/// Find the most relevant semantics node in the tree
SemanticsNode? _findRelevantSemanticsNode(SemanticsNode? root) {
  if (root == null) return null;

  // BFS through semantics subtree to find first "interesting" node
  final queue = <SemanticsNode>[root];

  while (queue.isNotEmpty) {
    final current = queue.removeAt(0);
    final data = current.getSemanticsData();

    // Check for interesting flags or actions
    final hasInterestingFlag =
        data.hasFlag(SemanticsFlag.isButton) ||
        data.hasFlag(SemanticsFlag.isImage) ||
        data.hasFlag(SemanticsFlag.isTextField) ||
        data.hasFlag(SemanticsFlag.isLink) ||
        data.hasFlag(SemanticsFlag.isSlider) ||
        data.hasFlag(SemanticsFlag.isToggled) ||
        data.hasFlag(SemanticsFlag.isChecked) ||
        data.hasAction(SemanticsAction.tap) ||
        data.hasAction(SemanticsAction.longPress);

    if (hasInterestingFlag) {
      return current;
    }

    // Add children to queue
    current.visitChildren((child) {
      queue.add(child);
      return true;
    });
  }

  // If nothing interesting found, return root
  return root;
}
```

### 5.2 Output Format

The test generates `semantics_dump.json`:

```json
{
  "IconButton": {
    "isButton": true,
    "isImage": false,
    "isToggled": false,
    "hasTap": true,
    "hasChildren": false,
    "childCount": 0,
    "label": "Test"
  },
  "Switch": {
    "isButton": false,
    "isToggled": true,
    "hasTap": true,
    "hasChildren": false
  }
}
```

---

## 6. Component 3 — Code Generator

**File:** `tool/semantics_generator/generate_source.dart`  
**Responsibility:** Read `semantics_dump.json` and generate `known_widget_semantics.dart`.

### 6.1 Mapping Rules

**Role Assignment:**
- `isButton: true` → `SemanticRole.button`
- `isImage: true` → `SemanticRole.image`
- `isToggled: true` OR `isChecked: true` → `SemanticRole.toggle`
- `isTextField: true` → `SemanticRole.input`
- `isSlider: true` → `SemanticRole.slider`
- `isHeader: true` → `SemanticRole.header`
- Otherwise → `SemanticRole.group`

**Interactivity:**
- `hasTap: true` OR `hasLongPress: true` → `isInteractive: true`

**Children Merging:**
- `mergesDescendants: true` → `mergesChildren: true`
- Special case for ListTile family → `mergesChildren: true` (manual override)

**Semantics Managed:**
- Set `true` for Material widgets that handle their own semantics
- Manual list: ListTile, CheckboxListTile, SwitchListTile, RadioListTile, etc.

### 6.2 Implementation

```dart
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

void main(List<String> args) async {
  // Locate files
  final scriptDir = p.dirname(Platform.script.toFilePath());
  final repoRoot = p.normalize(p.join(scriptDir, '../..'));
  final dumpFile = File(p.join(repoRoot, 'tool/semantics_generator/semantics_dump.json'));
  final outFile = File(p.join(repoRoot, 'lib/src/utils/known_widget_semantics.dart'));

  // Check dump file exists
  if (!dumpFile.existsSync()) {
    stderr.writeln('ERROR: semantics_dump.json not found.');
    stderr.writeln('Run the extractor test first:');
    stderr.writeln('  flutter test tool/semantics_generator/extract_semantics_test.dart');
    exit(1);
  }

  // Load JSON data
  final json = jsonDecode(await dumpFile.readAsString()) as Map<String, dynamic>;
  
  print('Generating known_widget_semantics.dart...');
  print('Processing ${json.length} widgets');

  // Generate Dart source
  final buffer = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND')
    ..writeln('// Generated by tool/semantics_generator/generate_source.dart')
    ..writeln('// From runtime Flutter semantics extraction')
    ..writeln('//')
    ..writeln('// To regenerate: ')
    ..writeln('//   1. flutter test tool/semantics_generator/extract_semantics_test.dart')
    ..writeln('//   2. dart tool/semantics_generator/generate_source.dart')
    ..writeln()
    ..writeln("import '../types/semantic_role.dart';")
    ..writeln("import 'widget_semantics_info.dart';")
    ..writeln()
    ..writeln('class KnownWidgetSemantics {')
    ..writeln('  static const Map<String, WidgetSemanticsInfo> widgets = {');

  // Process each widget
  json.forEach((name, value) {
    final data = value as Map<String, dynamic>;
    
    // Extract flags
    final isButton = data['isButton'] == true;
    final isImage = data['isImage'] == true;
    final isToggled = data['isToggled'] == true || data['isChecked'] == true;
    final isTextField = data['isTextField'] == true;
    final isSlider = data['isSlider'] == true;
    final isHeader = data['isHeader'] == true;
    final hasTap = data['hasTap'] == true || data['hasLongPress'] == true;
    final mergesDescendants = data['mergesDescendants'] == true;

    // Determine role
    final role = _determineRole(
      isButton: isButton,
      isImage: isImage,
      isToggled: isToggled,
      isTextField: isTextField,
      isSlider: isSlider,
      isHeader: isHeader,
    );

    // Determine properties
    final isInteractive = hasTap;
    final mergesChildren = mergesDescendants || _shouldMergeChildren(name);
    final semanticsManaged = _isSemanticsManaged(name);
    final hasTooltipParam = _hasTooltipParam(name);
    final hasSemanticLabelParam = _hasSemanticLabelParam(name);

    // Write entry
    buffer.writeln("    '$name': WidgetSemanticsInfo(");
    buffer.writeln('      role: $role,');
    buffer.writeln('      isInteractive: $isInteractive,');
    buffer.writeln('      mergesChildren: $mergesChildren,');
    buffer.writeln('      semanticsManaged: $semanticsManaged,');
    buffer.writeln('      hasTooltipParam: $hasTooltipParam,');
    buffer.writeln('      hasSemanticLabelParam: $hasSemanticLabelParam,');
    buffer.writeln('    ),');
  });

  buffer
    ..writeln('  };')
    ..writeln()
    ..writeln('  /// Lookup semantics info for a widget by name')
    ..writeln('  static WidgetSemanticsInfo? lookup(String? widgetName) {')
    ..writeln('    if (widgetName == null) return null;')
    ..writeln('    return widgets[widgetName];')
    ..writeln('  }')
    ..writeln('}');

  // Write to file
  await outFile.writeAsString(buffer.toString());
  
  print('✓ Generated ${outFile.path}');
  print('✓ ${json.length} widgets mapped');
}

String _determineRole({
  required bool isButton,
  required bool isImage,
  required bool isToggled,
  required bool isTextField,
  required bool isSlider,
  required bool isHeader,
}) {
  if (isButton) return 'SemanticRole.button';
  if (isImage) return 'SemanticRole.image';
  if (isToggled) return 'SemanticRole.toggle';
  if (isTextField) return 'SemanticRole.input';
  if (isSlider) return 'SemanticRole.slider';
  if (isHeader) return 'SemanticRole.header';
  return 'SemanticRole.group';
}

bool _shouldMergeChildren(String widgetName) {
  // Widgets known to merge children semantics
  const mergingWidgets = {
    'ListTile',
    'CheckboxListTile',
    'SwitchListTile',
    'RadioListTile',
    'ExpansionTile',
    'Card',
  };
  return mergingWidgets.contains(widgetName);
}

bool _isSemanticsManaged(String widgetName) {
  // Widgets that fully manage their own semantics
  const managedWidgets = {
    'IconButton',
    'ElevatedButton',
    'TextButton',
    'OutlinedButton',
    'FilledButton',
    'FloatingActionButton',
    'Switch',
    'Checkbox',
    'Radio',
    'Slider',
    'TextField',
    'TextFormField',
    'ListTile',
    'CheckboxListTile',
    'SwitchListTile',
    'RadioListTile',
    'Semantics',
    'MergeSemantics',
    'ExcludeSemantics',
    'BlockSemantics',
  };
  return managedWidgets.contains(widgetName);
}

bool _hasTooltipParam(String widgetName) {
  // Widgets with tooltip parameter
  const tooltipWidgets = {
    'IconButton',
    'FloatingActionButton',
  };
  return tooltipWidgets.contains(widgetName);
}

bool _hasSemanticLabelParam(String widgetName) {
  // Widgets with semanticLabel parameter
  const semanticLabelWidgets = {
    'Image',
    'CircleAvatar',
  };
  return semanticLabelWidgets.contains(widgetName);
}
```

---

## 7. Running the Pipeline on a New Flutter Release

### Quick Reference

```bash
# Step 1: Update Flutter SDK (if needed)
flutter upgrade

# Step 2: Update widget catalogue (if new widgets)
# Edit: tool/semantics_generator/widget_catalogue.dart

# Step 3: Extract semantics
flutter test tool/semantics_generator/extract_semantics_test.dart

# Step 4: Generate source code
dart tool/semantics_generator/generate_source.dart

# Step 5: Format generated code
dart format lib/src/utils/known_widget_semantics.dart

# Step 6: Verify with tests
dart test

# Step 7: Commit changes
git add tool/semantics_generator/ lib/src/utils/known_widget_semantics.dart
git commit -m "chore: regenerate known widget semantics for Flutter X.Y.Z"
```

### Detailed Steps

#### Step 1 — Update Flutter SDK

Ensure your Flutter installation points to the desired version:

```bash
flutter --version
# Flutter 3.XX.X • channel stable
```

#### Step 2 — Update Widget Catalogue (If Needed)

Check Flutter release notes for new widgets. Common additions:
- New Material Design 3 widgets
- New form controls
- New navigation widgets
- Variant constructors (e.g., `FilledButton.tonal`)

Add entries to `tool/semantics_generator/widget_catalogue.dart`.

#### Step 3 — Run the Extractor

```bash
flutter test tool/semantics_generator/extract_semantics_test.dart
```

**Expected output:**
```
✓ Extracted semantics for 45 widgets
✓ Written to tool/semantics_generator/semantics_dump.json
```

**Troubleshooting:**
- If test fails: Check widget constructors in catalogue for missing required parameters
- If widget not found: Verify import statements and widget type

#### Step 4 — Run the Code Generator

```bash
dart tool/semantics_generator/generate_source.dart
```

**Expected output:**
```
Generating known_widget_semantics.dart...
Processing 45 widgets
✓ Generated lib/src/utils/known_widget_semantics.dart
✓ 45 widgets mapped
```

#### Step 5 — Format Generated Code

```bash
dart format lib/src/utils/known_widget_semantics.dart
```

#### Step 6 — Run Linter Tests

```bash
dart test
```

**Check for:**
- No unexpected test failures
- No breaking changes in widget semantics
- All existing rules still work correctly

If tests fail:
1. Review changes in `semantics_dump.json`
2. Check if Flutter changed widget semantics
3. Update rules if necessary
4. Document breaking changes

#### Step 7 — Commit Changes

```bash
git add tool/semantics_generator/semantics_dump.json
git add lib/src/utils/known_widget_semantics.dart
git commit -m "chore: regenerate known widget semantics for Flutter 3.XX.X"
```

**Commit message template:**
```
chore: regenerate known widget semantics for Flutter 3.XX.X

- Added N new widgets: WidgetA, WidgetB
- Updated semantics for: WidgetC (changed from X to Y)
- Removed deprecated: WidgetD

Extraction date: YYYY-MM-DD
Flutter version: 3.XX.X stable
```

---

## 8. Limitations & Considerations

### Current Limitations

⚠️ **Single Configuration Per Widget**
- Pipeline captures one representative configuration
- May not cover all possible widget states or variants
- Example: Button with/without icon may have different semantics

⚠️ **Static Configuration Only**
- Uses dummy/test data for labels and values
- Cannot capture localized content behavior
- Cannot test conditional semantics

⚠️ **No Layout Context**
- Cannot determine if semantics change based on parent constraints
- Cannot detect size-dependent behavior
- Cannot capture responsive semantics

⚠️ **Manual Overrides Required**
- Some widgets need manual `semanticsManaged` flags
- Custom parameter detection (tooltip, semanticLabel) is hardcoded
- Edge cases may need special handling

### Best Practices

✅ **Keep Catalogue Focused**
- Only include Flutter framework widgets
- One entry per widget type (avoid excessive variants)
- Use representative configurations that expose semantics

✅ **Document Extraction Context**
- Note Flutter version in commit messages
- Keep semantics_dump.json in version control
- Track changes between Flutter versions

✅ **Validate After Generation**
- Run full test suite
- Spot-check generated mappings
- Review diff before committing

✅ **Handle Flutter Breaking Changes**
- Monitor Flutter release notes for semantic changes
- Update test configurations if widget APIs change
- Document any manual interventions needed

---

## 9. Maintenance Workflow

### Regular Maintenance

**When:** Every Flutter stable release (quarterly)

1. Update Flutter SDK
2. Review release notes for new/changed widgets
3. Update catalogue if needed
4. Run pipeline
5. Test and commit

### On-Demand Updates

**When:** Adding support for new widget types

1. Add widget to catalogue
2. Run extraction
3. Generate source
4. Add tests for new widget
5. Commit

### Troubleshooting

**Problem:** Widget not found during extraction

**Solution:** 
- Verify widget import in catalogue
- Check widget constructor parameters
- Ensure widget can render in test environment

**Problem:** Unexpected semantic flags

**Solution:**
- Review Flutter source code for widget
- Check if wrapper widgets affect semantics
- May need manual override in generator

**Problem:** Generated code has linting errors

**Solution:**
- Run `dart format` on generated file
- Check template in `generate_source.dart`
- Verify enum values match type definitions

---

## 10. Future Enhancements

### Potential Improvements

1. **Multi-Configuration Extraction**
   - Test widgets in multiple states (enabled/disabled, selected/unselected)
   - Capture variant constructors separately
   - Handle platform-specific widgets (Material vs Cupertino)

2. **Automated Override Detection**
   - Analyze widget source code for parameter types
   - Auto-detect tooltip/semanticLabel parameters
   - Reduce manual hardcoding

3. **Diff Reporting**
   - Compare semantics between Flutter versions
   - Highlight breaking changes
   - Generate migration reports

4. **Integration Testing**
   - Test actual screen reader announcements
   - Validate against TalkBack/VoiceOver
   - Ensure mappings match real user experience

5. **Custom Widget Support**
   - Allow projects to define their own catalogues
   - Generate project-specific semantic mappings
   - Support design system widgets

---

## 11. Integration with Linter

The generated `known_widget_semantics.dart` is used by the linter's IR builder:

```dart
// In semantic IR builder
final knownSemantics = KnownWidgetSemantics.lookup(widgetName);

if (knownSemantics != null) {
  // Use known semantics to build IR node
  final node = SemanticNodeIR(
    role: knownSemantics.role,
    isInteractive: knownSemantics.isInteractive,
    // ... etc
  );
}
```

This provides the foundation for:
- Accurate semantic role assignment
- Interactivity detection
- Semantic merging behavior
- Label extraction strategies

---

## 12. Appendix: Example Output

### Sample `semantics_dump.json` Entry

```json
{
  "IconButton": {
    "isButton": true,
    "isImage": false,
    "isToggled": false,
    "isChecked": false,
    "isLink": false,
    "isSlider": false,
    "isTextField": false,
    "isHeader": false,
    "isFocusable": true,
    "hasTap": true,
    "hasLongPress": false,
    "hasIncrease": false,
    "hasDecrease": false,
    "hasChildren": false,
    "childCount": 0,
    "mergesDescendants": false,
    "label": "Test",
    "hint": "",
    "value": ""
  }
}
```

### Sample Generated Code

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND

import '../types/semantic_role.dart';
import 'widget_semantics_info.dart';

class KnownWidgetSemantics {
  static const Map<String, WidgetSemanticsInfo> widgets = {
    'IconButton': WidgetSemanticsInfo(
      role: SemanticRole.button,
      isInteractive: true,
      mergesChildren: false,
      semanticsManaged: true,
      hasTooltipParam: true,
      hasSemanticLabelParam: false,
    ),
    'Switch': WidgetSemanticsInfo(
      role: SemanticRole.toggle,
      isInteractive: true,
      mergesChildren: false,
      semanticsManaged: true,
      hasTooltipParam: false,
      hasSemanticLabelParam: false,
    ),
    // ... more entries
  };

  static WidgetSemanticsInfo? lookup(String? widgetName) {
    if (widgetName == null) return null;
    return widgets[widgetName];
  }
}
```

---

**Document Version:** 1.0  
**Last Updated:** December 2025  
**Maintainer:** Flutter A11y Lints Team
