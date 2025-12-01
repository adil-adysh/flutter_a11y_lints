# 📘 Flutter A11y Linter — Complete Design Document

### *Compiler-Inspired Architecture for High-Accuracy Accessibility Analysis*

**Version 1.0 — December 2025**

---

## 0. Purpose of This Document

This design document defines:

* The **architecture** of the linter
* The **Semantic IR** (semantic intermediate representation)
* The **Heuristic Engine** (signal-based, low-false-positive)
* The **Policy Engine** (turns IR into a11y rule enforcement)
* The **KnownWidgetSemantics** model
* The **Automated Semantics Extraction Pipeline**
* Integration points for developers and coding agents

This document is your *source of truth* for implementing the Flutter accessibility linter with a compiler-style architecture.

---

## 1. High-Level Architecture

The linter is designed like a compiler with multiple transformation stages:

```
AST → Semantic IR → Heuristic Engine → Policy Engine → Diagnostics
```

### Stage 1: AST Analysis

* Built using the Dart analyzer + custom_lint framework
* Locate widgets (InstanceCreationExpressions, build methods, builder closures)
* Detect parameters, widget types, children, callbacks
* Extract literal values and expressions

### Stage 2: Semantic IR Construction

A static, approximate semantics tree predicting what screen readers will perceive:
* Widget semantic roles (button, toggle, image, text, etc.)
* Labels and descriptions
* Interactive states
* Focus behavior
* Semantic transformations (merge, exclude, replace)

### Stage 3: Heuristic Engine

A multi-signal, confidence-scoring system to avoid false positives:
* Extract boolean facts (signals)
* Apply negative guards
* Compute confidence scores
* Make safe decisions about ambiguous patterns

### Stage 4: Policy Engine

A rule engine that enforces accessibility policies over the IR tree:
* Traverses semantic tree
* Applies policy rules
* Generates diagnostics with context

### Stage 5: Diagnostics Output

* Maps IR violations back to AST locations
* Reports through custom_lint reporter
* Provides actionable fix suggestions

**Key Principle:** Everything is deterministic, stateless, repeatable, and testable.

---

## 2. Semantic IR Design

The Semantic IR is a tree that represents estimated semantics for a widget subtree. It approximates what assistive technologies will perceive at runtime.

### 2.1 Node Model

```dart
class SemanticNodeIR {
  /// Unique identifier for diagnostics and debugging
  final String id;
  
  /// Semantic role (button, toggle, image, text, etc.)
  final SemanticRole role;
  
  /// What screen reader will likely announce
  final String? label;
  
  /// Additional description/hint text
  final String? hint;
  
  /// Current value (for sliders, inputs, toggles)
  final String? value;

  // Interactive properties
  final bool isInteractive;        // Has onTap/onPressed/etc.
  final bool isFocusable;          // Can receive focus
  final bool isDisabled;           // onPressed == null or enabled: false

  // Semantic transformations
  final bool isExcluded;           // ExcludeSemantics or excludeFromSemantics
  final bool isMerged;             // MergeSemantics applied
  final bool isReplacement;        // Semantics(label) overriding children
  final bool isBlocking;           // BlockSemantics applied
  
  // Specific widget properties
  final bool isDecorative;         // Icons/images that are decorative
  final bool isToggle;             // Switch/checkbox/radio/toggle-like
  final bool? toggled;             // Toggle state if statically known
  
  // Context
  final bool isInList;             // Inside ListView/GridView
  final bool isInBuilder;          // Inside builder closure
  final String? builderItemVar;    // Variable name for list items

  /// Child semantic nodes
  final List<SemanticNodeIR> children;

  /// Reference to original AST node for error reporting
  final AstNode sourceNode;
  
  /// Confidence in this semantic interpretation (0-100)
  final int confidence;

  const SemanticNodeIR({
    required this.id,
    required this.role,
    required this.sourceNode,
    this.label,
    this.hint,
    this.value,
    this.isInteractive = false,
    this.isFocusable = false,
    this.isDisabled = false,
    this.isExcluded = false,
    this.isMerged = false,
    this.isReplacement = false,
    this.isBlocking = false,
    this.isDecorative = false,
    this.isToggle = false,
    this.toggled,
    this.isInList = false,
    this.isInBuilder = false,
    this.builderItemVar,
    this.children = const [],
    this.confidence = 100,
  });
}
```

### 2.2 Semantic Roles

```dart
enum SemanticRole {
  /// Interactive button (IconButton, ElevatedButton, etc.)
  button,
  
  /// Toggle control (Switch, Checkbox, Radio)
  toggle,
  
  /// Image (decorative or informative)
  image,
  
  /// Static text content
  text,
  
  /// Input field (TextField, TextFormField)
  input,
  
  /// Slider or range control
  slider,
  
  /// Header/title element
  header,
  
  /// List item
  listItem,
  
  /// Grouping/container element
  group,
  
  /// Link/navigation element
  link,
  
  /// Tab in tab bar
  tab,
  
  /// Unknown or custom widget
  unknown,
}
```

### 2.3 Semantic Tree Container

```dart
class SemanticTreeIR {
  /// Root semantic nodes
  final List<SemanticNodeIR> roots;
  
  /// Configuration used to build this tree
  final SemanticIRConfig config;
  
  /// Source file path
  final String filePath;

  const SemanticTreeIR({
    required this.roots,
    required this.config,
    required this.filePath,
  });
  
  /// Get all nodes in tree (depth-first traversal)
  List<SemanticNodeIR> getAllNodes() {
    final nodes = <SemanticNodeIR>[];
    void visit(SemanticNodeIR node) {
      nodes.add(node);
      for (final child in node.children) {
        visit(child);
      }
    }
    for (final root in roots) {
      visit(root);
    }
    return nodes;
  }
  
  /// Find nodes matching predicate
  List<SemanticNodeIR> findNodes(bool Function(SemanticNodeIR) predicate) {
    return getAllNodes().where(predicate).toList();
  }
}
```

### 2.4 Configuration

```dart
class SemanticIRConfig {
  /// Enable heuristic analysis
  final bool enableHeuristics;
  
  /// Include low-confidence nodes
  final bool includeLowConfidence;
  
  /// Custom widget semantic mappings
  final Map<String, WidgetSemanticsInfo> customWidgets;
  
  /// Safe components that don't need analysis
  final Set<String> safeComponents;

  const SemanticIRConfig({
    this.enableHeuristics = true,
    this.includeLowConfidence = false,
    this.customWidgets = const {},
    this.safeComponents = const {},
  });
}
```

---

## 3. Building the Semantic IR

The IR construction process transforms AST into semantic understanding.

### 3.1 Inputs

1. **AST nodes** — Widget instances from analyzer
2. **KnownWidgetSemantics** — Pre-built semantic information table
3. **Heuristic signals** — Contextual analysis (optional)
4. **Configuration** — User settings and custom mappings

### 3.2 Construction Pipeline

```dart
class SemanticIRBuilder {
  final KnownWidgetSemantics knownSemantics;
  final SemanticIRConfig config;
  
  SemanticTreeIR buildFromAST(CompilationUnit unit, String filePath) {
    final roots = <SemanticNodeIR>[];
    
    // Find all top-level build methods and builders
    for (final declaration in unit.declarations) {
      if (declaration is ClassDeclaration) {
        for (final member in declaration.members) {
          if (member is MethodDeclaration && member.name.lexeme == 'build') {
            final semanticNode = _buildNode(member.body);
            if (semanticNode != null) {
              roots.add(semanticNode);
            }
          }
        }
      }
    }
    
    return SemanticTreeIR(
      roots: roots,
      config: config,
      filePath: filePath,
    );
  }
  
  SemanticNodeIR? _buildNode(AstNode astNode) {
    if (astNode is! InstanceCreationExpression) return null;
    
    // Step 1: Resolve widget type
    final widgetType = astNode.staticType;
    final semanticsInfo = knownSemantics.lookup(widgetType);
    
    // Step 2: Extract semantic properties
    final label = _extractLabel(astNode, semanticsInfo);
    final isInteractive = _checkInteractivity(astNode, semanticsInfo);
    final role = semanticsInfo.role;
    
    // Step 3: Extract semantic modifiers
    final modifiers = _extractModifiers(astNode);
    
    // Step 4: Build children
    final children = _buildChildren(astNode);
    
    // Step 5: Apply transformations
    final transformed = _applyTransformations(
      role: role,
      label: label,
      isInteractive: isInteractive,
      modifiers: modifiers,
      children: children,
      sourceNode: astNode,
    );
    
    return transformed;
  }
}
```

### 3.3 Label Extraction Strategy

Labels are extracted in priority order:

1. **Explicit Semantics.label** — Highest priority
2. **tooltip parameter** — For IconButton, etc.
3. **semanticLabel parameter** — For Image, etc.
4. **Text child content** — For buttons with text
5. **aria-label equivalent** — Custom properties
6. **Inferred from context** — Heuristic (low confidence)

```dart
String? _extractLabel(
  InstanceCreationExpression node,
  WidgetSemanticsInfo info,
) {
  // Check explicit Semantics wrapper
  final semanticsParent = _findSemanticsAncestor(node);
  if (semanticsParent != null) {
    final explicitLabel = getStringLiteralArg(semanticsParent, 'label');
    if (explicitLabel != null) return explicitLabel;
  }
  
  // Check tooltip parameter
  if (info.hasTooltipParam) {
    final tooltip = getStringLiteralArg(node, 'tooltip');
    if (tooltip != null) return tooltip;
  }
  
  // Check semanticLabel parameter
  if (info.hasSemanticLabelParam) {
    final semanticLabel = getStringLiteralArg(node, 'semanticLabel');
    if (semanticLabel != null) return semanticLabel;
  }
  
  // Check for Text child
  final textChild = _findTextChild(node);
  if (textChild != null) {
    return getStringLiteralArg(textChild, 'data');
  }
  
  return null;
}
```

### 3.4 Semantic Transformations

Apply Flutter's semantic transformation rules:

#### MergeSemantics

```dart
SemanticNodeIR _applyMergeSemantics(SemanticNodeIR node) {
  if (!node.isMerged) return node;
  
  // Combine all child labels into parent
  final childLabels = node.children
      .where((child) => !child.isExcluded)
      .map((child) => child.label)
      .where((label) => label != null && label.isNotEmpty)
      .join(' ');
  
  return node.copyWith(
    label: childLabels,
    children: [], // Children semantically absorbed
  );
}
```

#### ExcludeSemantics

```dart
SemanticNodeIR _applyExcludeSemantics(SemanticNodeIR node) {
  if (!node.isExcluded) return node;
  
  // Remove this node and all descendants from semantic tree
  return node.copyWith(
    label: null,
    children: [],
    isExcluded: true,
  );
}
```

#### Replacement Semantics

```dart
SemanticNodeIR _applyReplacementSemantics(SemanticNodeIR node) {
  if (!node.isReplacement) return node;
  
  // Parent label replaces all child semantics
  return node.copyWith(
    children: node.children.map((child) => 
      child.copyWith(isExcluded: true)
    ).toList(),
  );
}
```

---

## 4. KnownWidgetSemantics

A static mapping of Flutter's built-in widgets to their default semantic behavior.

### 4.1 Widget Semantics Information Model

```dart
class WidgetSemanticsInfo {
  /// Semantic role of this widget
  final SemanticRole role;
  
  /// Whether widget is interactive by default
  final bool isInteractive;
  
  /// Whether widget merges children semantics
  final bool mergesChildren;
  
  /// Whether widget manages its own semantics completely
  final bool semanticsManaged;
  
  /// Whether widget has tooltip parameter
  final bool hasTooltipParam;
  
  /// Whether widget has semanticLabel parameter
  final bool hasSemanticLabelParam;
  
  /// Whether widget is focusable
  final bool isFocusable;
  
  /// Additional semantic flags
  final Set<String> flags;

  const WidgetSemanticsInfo({
    required this.role,
    this.isInteractive = false,
    this.mergesChildren = false,
    this.semanticsManaged = false,
    this.hasTooltipParam = false,
    this.hasSemanticLabelParam = false,
    this.isFocusable = false,
    this.flags = const {},
  });

  factory WidgetSemanticsInfo.unknown() =>
      const WidgetSemanticsInfo(role: SemanticRole.unknown);
}
```

### 4.2 Example Entries

```dart
class KnownWidgetSemantics {
  static const Map<String, WidgetSemanticsInfo> _builtInSemantics = {
    // Buttons
    'IconButton': WidgetSemanticsInfo(
      role: SemanticRole.button,
      isInteractive: true,
      isFocusable: true,
      semanticsManaged: true,
      hasTooltipParam: true,
    ),
    
    'ElevatedButton': WidgetSemanticsInfo(
      role: SemanticRole.button,
      isInteractive: true,
      isFocusable: true,
      semanticsManaged: true,
    ),
    
    'TextButton': WidgetSemanticsInfo(
      role: SemanticRole.button,
      isInteractive: true,
      isFocusable: true,
      semanticsManaged: true,
    ),
    
    // Toggles
    'Switch': WidgetSemanticsInfo(
      role: SemanticRole.toggle,
      isInteractive: true,
      isFocusable: true,
      semanticsManaged: true,
      flags: {'toggle'},
    ),
    
    'Checkbox': WidgetSemanticsInfo(
      role: SemanticRole.toggle,
      isInteractive: true,
      isFocusable: true,
      semanticsManaged: true,
      flags: {'checked'},
    ),
    
    // Images
    'Image': WidgetSemanticsInfo(
      role: SemanticRole.image,
      hasSemanticLabelParam: true,
      flags: {'excludeFromSemantics'},
    ),
    
    // Text
    'Text': WidgetSemanticsInfo(
      role: SemanticRole.text,
    ),
    
    // Input
    'TextField': WidgetSemanticsInfo(
      role: SemanticRole.input,
      isInteractive: true,
      isFocusable: true,
      semanticsManaged: true,
    ),
    
    // Semantic Modifiers
    'Semantics': WidgetSemanticsInfo(
      role: SemanticRole.group,
      semanticsManaged: true,
      flags: {'semantics-container'},
    ),
    
    'MergeSemantics': WidgetSemanticsInfo(
      role: SemanticRole.group,
      mergesChildren: true,
    ),
    
    'ExcludeSemantics': WidgetSemanticsInfo(
      role: SemanticRole.group,
      flags: {'excludes-children'},
    ),
    
    'BlockSemantics': WidgetSemanticsInfo(
      role: SemanticRole.group,
      flags: {'blocks-background'},
    ),
    
    // List widgets
    'ListTile': WidgetSemanticsInfo(
      role: SemanticRole.listItem,
      isInteractive: true,
      isFocusable: true,
      mergesChildren: true,
      semanticsManaged: true,
    ),
    
    // Containers
    'Row': WidgetSemanticsInfo(
      role: SemanticRole.group,
    ),
    
    'Column': WidgetSemanticsInfo(
      role: SemanticRole.group,
    ),
  };
  
  WidgetSemanticsInfo lookup(DartType? type) {
    if (type == null) return WidgetSemanticsInfo.unknown();
    
    final className = type.element?.name;
    if (className == null) return WidgetSemanticsInfo.unknown();
    
    return _builtInSemantics[className] ?? WidgetSemanticsInfo.unknown();
  }
}
```

---

## 5. Automated Semantics Extraction Pipeline

To avoid manually maintaining KnownWidgetSemantics, build it automatically from Flutter's runtime behavior.

### 5.1 Pipeline Overview

```
Widget Catalogue → Runtime Extraction → Data Mapping → Code Generation
```

**Advantages:**
* Zero manual guesswork
* Fully syncs with Flutter internals
* Detects changes in new Flutter releases
* High accuracy for roles, interactivity, and merging behavior

### 5.2 Step 1: Widget Catalogue

Define minimal representative instances of each widget:

```dart
// tools/semantics_extractor/widget_catalogue.dart

class WidgetCatalogue {
  static const entries = [
    WidgetCatalogueEntry(
      name: 'IconButton',
      constructor: '''
        IconButton(
          icon: Icon(Icons.add),
          onPressed: () {},
          tooltip: 'Add',
        )
      ''',
    ),
    
    WidgetCatalogueEntry(
      name: 'ElevatedButton',
      constructor: '''
        ElevatedButton(
          onPressed: () {},
          child: Text('Submit'),
        )
      ''',
    ),
    
    WidgetCatalogueEntry(
      name: 'Switch',
      constructor: '''
        Switch(
          value: true,
          onChanged: (v) {},
        )
      ''',
    ),
    
    // ... more widgets
  ];
}

class WidgetCatalogueEntry {
  final String name;
  final String constructor;
  
  const WidgetCatalogueEntry({
    required this.name,
    required this.constructor,
  });
}
```

### 5.3 Step 2: Runtime Extraction

Use Flutter's test framework to extract runtime semantics:

```dart
// tools/semantics_extractor/extract_semantics_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'dart:io';

void main() {
  testWidgets('Extract semantics for all widgets', (tester) async {
    final results = <String, Map<String, dynamic>>{};
    
    for (final entry in WidgetCatalogue.entries) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _buildWidget(entry.constructor),
          ),
        ),
      );
      
      // Extract semantics
      final semantics = tester.getSemantics(find.byType(entry.name));
      
      results[entry.name] = {
        'hasButton': semantics.hasFlag(SemanticsFlag.isButton),
        'hasToggled': semantics.hasFlag(SemanticsFlag.hasToggledState),
        'hasChecked': semantics.hasFlag(SemanticsFlag.hasCheckedState),
        'isFocusable': semantics.hasFlag(SemanticsFlag.isFocusable),
        'isTextField': semantics.hasFlag(SemanticsFlag.isTextField),
        'isImage': semantics.hasFlag(SemanticsFlag.isImage),
        'isHeader': semantics.hasFlag(SemanticsFlag.isHeader),
        'hasAction': semantics.hasAction(SemanticsAction.tap),
        'label': semantics.label,
        'hint': semantics.hint,
        'value': semantics.value,
      };
    }
    
    // Write to JSON
    final file = File('semantics_dump.json');
    await file.writeAsString(
      JsonEncoder.withIndent('  ').convert(results),
    );
  });
}
```

### 5.4 Step 3: Data Mapping

Map runtime flags to semantic roles:

```dart
// tools/semantics_extractor/generate_source.dart

SemanticRole mapToRole(Map<String, dynamic> flags) {
  if (flags['hasButton'] == true) return SemanticRole.button;
  if (flags['hasToggled'] == true || flags['hasChecked'] == true) {
    return SemanticRole.toggle;
  }
  if (flags['isTextField'] == true) return SemanticRole.input;
  if (flags['isImage'] == true) return SemanticRole.image;
  if (flags['isHeader'] == true) return SemanticRole.header;
  
  return SemanticRole.unknown;
}

bool isInteractive(Map<String, dynamic> flags) {
  return flags['hasAction'] == true;
}

bool isFocusable(Map<String, dynamic> flags) {
  return flags['isFocusable'] == true;
}
```

### 5.5 Step 4: Code Generation

Generate Dart source file:

```dart
void generateKnownWidgetSemantics(Map<String, Map<String, dynamic>> data) {
  final buffer = StringBuffer();
  
  buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
  buffer.writeln('// Generated from Flutter runtime semantics extraction');
  buffer.writeln();
  buffer.writeln('class KnownWidgetSemantics {');
  buffer.writeln('  static const Map<String, WidgetSemanticsInfo> _builtInSemantics = {');
  
  for (final entry in data.entries) {
    final name = entry.key;
    final flags = entry.value;
    final role = mapToRole(flags);
    
    buffer.writeln("    '$name': WidgetSemanticsInfo(");
    buffer.writeln("      role: SemanticRole.$role,");
    buffer.writeln("      isInteractive: ${isInteractive(flags)},");
    buffer.writeln("      isFocusable: ${isFocusable(flags)},");
    buffer.writeln("    ),");
  }
  
  buffer.writeln('  };');
  buffer.writeln('}');
  
  File('lib/src/ir/known_widget_semantics.g.dart')
      .writeAsStringSync(buffer.toString());
}
```

### 5.6 Build Command

```bash
# Run extraction
flutter test tools/semantics_extractor/extract_semantics_test.dart

# Generate source
dart run tools/semantics_extractor/generate_source.dart

# Format generated code
dart format lib/src/ir/known_widget_semantics.g.dart
```

---

## 6. Heuristic Engine Design

Heuristics handle rules that cannot be perfectly determined statically.

### 6.1 Core Concepts

#### Signal

A **signal** is a boolean fact extracted from AST or IR:

```dart
class Signal {
  final String name;
  final bool value;
  final String description;
  
  const Signal(this.name, this.value, this.description);
  
  @override
  String toString() => '$name: $value ($description)';
}
```

#### Guard

A **guard** is a negative condition that cancels warnings:

```dart
class Guard {
  final String name;
  final bool applies;
  final String reason;
  
  const Guard(this.name, this.applies, this.reason);
  
  @override
  String toString() => '$name applies: $applies ($reason)';
}
```

#### Heuristic Decision

```dart
class HeuristicDecision {
  final bool shouldReport;
  final int confidence;
  final List<Signal> signals;
  final List<Guard> guards;
  final String reasoning;
  
  const HeuristicDecision({
    required this.shouldReport,
    required this.confidence,
    this.signals = const [],
    this.guards = const [],
    this.reasoning = '',
  });
  
  factory HeuristicDecision.lint({
    int confidence = 3,
    List<Signal> signals = const [],
    String reasoning = '',
  }) => HeuristicDecision(
    shouldReport: true,
    confidence: confidence,
    signals: signals,
    reasoning: reasoning,
  );
  
  factory HeuristicDecision.noLint({
    List<Guard> guards = const [],
    String reasoning = '',
  }) => HeuristicDecision(
    shouldReport: false,
    confidence: 0,
    guards: guards,
    reasoning: reasoning,
  );
}
```

### 6.2 Signal Extractor

```dart
class SignalExtractor {
  // Structural signals
  static Signal parentIsInteractive(SemanticNodeIR node) {
    // Check if parent node is interactive
    return Signal(
      'parentIsInteractive',
      node.isInteractive,
      'Parent widget has interactive callback',
    );
  }
  
  static Signal hasIconAndTextChildren(SemanticNodeIR node) {
    final hasIcon = node.children.any((c) => c.role == SemanticRole.image);
    final hasText = node.children.any((c) => c.role == SemanticRole.text);
    return Signal(
      'hasIconAndTextChildren',
      hasIcon && hasText,
      'Contains both icon and text elements',
    );
  }
  
  static Signal insideBuilderContext(SemanticNodeIR node) {
    return Signal(
      'insideBuilderContext',
      node.isInBuilder,
      'Widget is inside ListView.builder or similar',
    );
  }
  
  // Content signals
  static Signal tooltipIsLiteral(SemanticNodeIR node) {
    // Check if label comes from literal string
    return Signal(
      'tooltipIsLiteral',
      node.label != null && !_isExpression(node.sourceNode),
      'Label is a literal string, not expression',
    );
  }
  
  static Signal hasGenericTooltip(SemanticNodeIR node) {
    const genericWords = ['delete', 'edit', 'more', 'close', 'menu'];
    final label = node.label?.toLowerCase() ?? '';
    return Signal(
      'hasGenericTooltip',
      genericWords.any((word) => label == word),
      'Label is generic (delete, edit, etc.)',
    );
  }
  
  static Signal hasItemVariable(SemanticNodeIR node) {
    return Signal(
      'hasItemVariable',
      node.builderItemVar != null,
      'Builder has item variable available',
    );
  }
  
  // Semantic signals
  static Signal hasSemanticsOverride(SemanticNodeIR node) {
    return Signal(
      'hasSemanticsOverride',
      node.isReplacement,
      'Has custom Semantics wrapper',
    );
  }
  
  static Signal childrenNotExcluded(SemanticNodeIR node) {
    final hasUncludedChildren = node.children.any((c) => !c.isExcluded);
    return Signal(
      'childrenNotExcluded',
      hasUncludedChildren,
      'Children are not excluded from semantics',
    );
  }
}
```

### 6.3 Guard Checker

```dart
class GuardChecker {
  // Configuration guards
  static Guard isInSafeComponent(
    SemanticNodeIR node,
    SemanticIRConfig config,
  ) {
    final widgetName = _getWidgetName(node.sourceNode);
    final isSafe = config.safeComponents.contains(widgetName);
    return Guard(
      'isInSafeComponent',
      isSafe,
      'Widget is in user-defined safe components list',
    );
  }
  
  // Semantic guards
  static Guard hasProperSemantics(SemanticNodeIR node) {
    final hasLabel = node.label != null && node.label!.isNotEmpty;
    final isManaged = !node.children.any((c) => !c.isExcluded);
    return Guard(
      'hasProperSemantics',
      hasLabel && isManaged,
      'Widget already has proper semantic configuration',
    );
  }
  
  // Localization guards
  static Guard usesLocalization(Expression? expr) {
    if (expr == null) return Guard('usesLocalization', false, 'No expression');
    
    final isLocalized = _detectLocalizationPattern(expr);
    return Guard(
      'usesLocalization',
      isLocalized,
      'Uses localization (context.l10n, S.of, tr, etc.)',
    );
  }
  
  static Guard isGeneratedCode(String filePath) {
    final isGenerated = filePath.endsWith('.g.dart') ||
                       filePath.endsWith('.freezed.dart') ||
                       filePath.contains('/generated/');
    return Guard(
      'isGeneratedCode',
      isGenerated,
      'File is generated code',
    );
  }
  
  // Structural guards
  static Guard hasComplexLayout(SemanticNodeIR node) {
    // Check for Expanded, Flexible, Positioned, etc.
    return Guard(
      'hasComplexLayout',
      false, // TODO: implement
      'Widget has complex layout that may affect semantics',
    );
  }
}
```

### 6.4 Confidence Evaluator

```dart
class ConfidenceEvaluator {
  /// Evaluate whether to report based on signals and guards
  static HeuristicDecision evaluate({
    required List<Signal> signals,
    required List<Guard> guards,
    required int threshold,
  }) {
    // Apply guards first - any guard can cancel
    for (final guard in guards) {
      if (guard.applies) {
        return HeuristicDecision.noLint(
          guards: guards,
          reasoning: 'Cancelled by guard: ${guard.reason}',
        );
      }
    }
    
    // Count positive signals
    final positiveSignals = signals.where((s) => s.value).toList();
    final score = positiveSignals.length;
    
    if (score >= threshold) {
      return HeuristicDecision.lint(
        confidence: score,
        signals: positiveSignals,
        reasoning: 'Confidence threshold met: $score >= $threshold',
      );
    }
    
    return HeuristicDecision.noLint(
      reasoning: 'Confidence too low: $score < $threshold',
    );
  }
  
  /// Evaluate with custom scoring
  static HeuristicDecision evaluateWeighted({
    required Map<Signal, int> weightedSignals,
    required List<Guard> guards,
    required int threshold,
  }) {
    // Apply guards
    for (final guard in guards) {
      if (guard.applies) {
        return HeuristicDecision.noLint(
          guards: guards,
          reasoning: 'Cancelled by guard: ${guard.reason}',
        );
      }
    }
    
    // Calculate weighted score
    var score = 0;
    final positiveSignals = <Signal>[];
    
    for (final entry in weightedSignals.entries) {
      if (entry.key.value) {
        score += entry.value;
        positiveSignals.add(entry.key);
      }
    }
    
    if (score >= threshold) {
      return HeuristicDecision.lint(
        confidence: score,
        signals: positiveSignals,
        reasoning: 'Weighted confidence met: $score >= $threshold',
      );
    }
    
    return HeuristicDecision.noLint(
      reasoning: 'Weighted confidence too low: $score < $threshold',
    );
  }
}
```

### 6.5 Example Heuristic: Contextual Button Labels

```dart
class ContextualLabelHeuristic {
  static HeuristicDecision evaluate(
    SemanticNodeIR node,
    SemanticIRConfig config,
  ) {
    // Extract signals
    final signals = [
      SignalExtractor.insideBuilderContext(node),
      SignalExtractor.hasItemVariable(node),
      SignalExtractor.tooltipIsLiteral(node),
      SignalExtractor.hasGenericTooltip(node),
    ];
    
    // Extract guards
    final guards = [
      GuardChecker.isInSafeComponent(node, config),
      GuardChecker.hasProperSemantics(node),
      GuardChecker.usesLocalization(_getLabelExpression(node)),
    ];
    
    // Evaluate
    return ConfidenceEvaluator.evaluate(
      signals: signals,
      guards: guards,
      threshold: 3, // Need at least 3 positive signals
    );
  }
}
```

---

## 7. Policy Engine

The policy engine inspects the Semantic IR and enforces accessibility policies.

### 7.1 Policy Rule Interface

```dart
abstract class PolicyRule {
  /// Rule identifier
  String get id;
  
  /// Human-readable name
  String get name;
  
  /// Severity level
  ErrorSeverity get severity;
  
  /// Check a single semantic node
  List<Diagnostic> checkNode(
    SemanticNodeIR node,
    SemanticContext ctx,
  );
}
```

### 7.2 Semantic Context

```dart
class SemanticContext {
  /// Full semantic tree
  final SemanticTreeIR tree;
  
  /// Ancestor chain
  final List<SemanticNodeIR> ancestors;
  
  /// Current depth
  final int depth;
  
  const SemanticContext({
    required this.tree,
    this.ancestors = const [],
    this.depth = 0,
  });
  
  factory SemanticContext.root(SemanticTreeIR tree) =>
      SemanticContext(tree: tree);
  
  SemanticContext forChild(SemanticNodeIR parent) =>
      SemanticContext(
        tree: tree,
        ancestors: [...ancestors, parent],
        depth: depth + 1,
      );
  
  SemanticNodeIR? get parent => ancestors.isNotEmpty ? ancestors.last : null;
  
  bool get hasListItemAncestor =>
      ancestors.any((a) => a.role == SemanticRole.listItem);
  
  String? get listItemTitle {
    final listItem = ancestors.reversed
        .firstWhere((a) => a.role == SemanticRole.listItem, orElse: () => null);
    return listItem?.label;
  }
}
```

### 7.3 Diagnostic Model

```dart
class Diagnostic {
  final String ruleId;
  final String message;
  final String? correction;
  final ErrorSeverity severity;
  final AstNode sourceNode;
  final Map<String, dynamic> metadata;
  
  const Diagnostic({
    required this.ruleId,
    required this.message,
    required this.sourceNode,
    this.correction,
    this.severity = ErrorSeverity.WARNING,
    this.metadata = const {},
  });
}
```

### 7.4 Policy Engine Implementation

```dart
class PolicyEngine {
  final List<PolicyRule> rules;
  final SemanticIRConfig config;
  
  const PolicyEngine({
    required this.rules,
    required this.config,
  });

  List<Diagnostic> run(SemanticTreeIR tree) {
    final diagnostics = <Diagnostic>[];

    void visitNode(SemanticNodeIR node, SemanticContext ctx) {
      // Apply all rules to this node
      for (final rule in rules) {
        try {
          final ruleDiagnostics = rule.checkNode(node, ctx);
          diagnostics.addAll(ruleDiagnostics);
        } catch (e, stack) {
          // Log error but continue with other rules
          print('Error in rule ${rule.id}: $e\n$stack');
        }
      }
      
      // Recursively visit children
      for (final child in node.children) {
        visitNode(child, ctx.forChild(node));
      }
    }

    // Visit all root nodes
    for (final root in tree.roots) {
      visitNode(root, SemanticContext.root(tree));
    }

    return diagnostics;
  }
}
```

### 7.5 Example Policy Rules

#### Policy A01: Interactive Controls Must Have Labels

```dart
class InteractiveControlsLabelPolicy extends PolicyRule {
  @override
  String get id => 'flutter_a11y_label_non_text_controls';
  
  @override
  String get name => 'Interactive controls must have labels';
  
  @override
  ErrorSeverity get severity => ErrorSeverity.WARNING;

  @override
  List<Diagnostic> checkNode(SemanticNodeIR node, SemanticContext ctx) {
    // Only check interactive buttons and toggles
    if (!node.isInteractive) return [];
    if (node.role != SemanticRole.button && node.role != SemanticRole.toggle) {
      return [];
    }
    
    // Check if has label
    final hasLabel = node.label != null && node.label!.isNotEmpty;
    
    // Check if has text child (implicit label)
    final hasTextChild = node.children.any((c) => c.role == SemanticRole.text);
    
    if (!hasLabel && !hasTextChild) {
      return [
        Diagnostic(
          ruleId: id,
          message: 'Interactive ${node.role.name} widgets must have an accessible label',
          correction: 'Add a tooltip parameter or Semantics label',
          severity: severity,
          sourceNode: node.sourceNode,
        ),
      ];
    }
    
    return [];
  }
}
```

#### Policy A03: Decorative Images Must Be Excluded

```dart
class DecorativeImagesPolicy extends PolicyRule {
  @override
  String get id => 'flutter_a11y_decorative_images_excluded';
  
  @override
  String get name => 'Decorative images must be excluded from semantics';
  
  @override
  ErrorSeverity get severity => ErrorSeverity.WARNING;

  @override
  List<Diagnostic> checkNode(SemanticNodeIR node, SemanticContext ctx) {
    // Only check images
    if (node.role != SemanticRole.image) return [];
    
    // Check if decorative
    if (!node.isDecorative) return [];
    
    // Check if excluded
    if (node.isExcluded) return [];
    
    return [
      Diagnostic(
        ruleId: id,
        message: 'Decorative images should be excluded from semantics',
        correction: 'Add excludeFromSemantics: true to the Image',
        severity: severity,
        sourceNode: node.sourceNode,
      ),
    ];
  }
}
```

#### Policy A06: Composite Controls Must Be Merged (Heuristic)

```dart
class CompositeControlsPolicy extends PolicyRule {
  @override
  String get id => 'flutter_a11y_merge_composite_values';
  
  @override
  String get name => 'Multi-part controls should be merged';
  
  @override
  ErrorSeverity get severity => ErrorSeverity.INFO; // Heuristic

  @override
  List<Diagnostic> checkNode(SemanticNodeIR node, SemanticContext ctx) {
    // Only check interactive groups
    if (node.role != SemanticRole.group) return [];
    if (!node.isInteractive) return [];
    
    // Check if has icon + text pattern
    final hasIcon = node.children.any((c) => c.role == SemanticRole.image);
    final hasText = node.children.any((c) => c.role == SemanticRole.text);
    
    if (!hasIcon || !hasText) return [];
    
    // Already merged? Skip
    if (node.isMerged) return [];
    
    // Already has replacement semantics? Skip
    if (node.isReplacement) return [];
    
    // Use heuristics to decide
    final signals = [
      Signal('hasIconAndText', true, 'Has both icon and text'),
      Signal('isInteractive', node.isInteractive, 'Parent is interactive'),
    ];
    
    final guards = [
      Guard('isMerged', node.isMerged, 'Already merged'),
      Guard('isReplacement', node.isReplacement, 'Has replacement'),
    ];
    
    final decision = ConfidenceEvaluator.evaluate(
      signals: signals,
      guards: guards,
      threshold: 2,
    );
    
    if (decision.shouldReport) {
      return [
        Diagnostic(
          ruleId: id,
          message: 'Consider wrapping this multi-part control with MergeSemantics',
          correction: 'Wrap with MergeSemantics to combine icon and text into single announcement',
          severity: severity,
          sourceNode: node.sourceNode,
          metadata: {
            'confidence': decision.confidence,
            'reasoning': decision.reasoning,
          },
        ),
      ];
    }
    
    return [];
  }
}
```

#### Policy A07: Replacement Semantics Must Exclude Children

```dart
class ReplacementSemanticsPolicy extends PolicyRule {
  @override
  String get id => 'flutter_a11y_replace_semantics_cleanly';
  
  @override
  String get name => 'Replacement semantics must exclude children';
  
  @override
  ErrorSeverity get severity => ErrorSeverity.INFO; // Heuristic

  @override
  List<Diagnostic> checkNode(SemanticNodeIR node, SemanticContext ctx) {
    // Only check nodes with custom labels
    if (node.label == null || node.label!.isEmpty) return [];
    
    // Check if children have speakable content
    final hasUncludedChildren = node.children.any((c) => 
      !c.isExcluded && 
      (c.label != null || c.role == SemanticRole.text)
    );
    
    if (!hasUncludedChildren) return [];
    
    // This is potentially a double-announcement issue
    return [
      Diagnostic(
        ruleId: id,
        message: 'Custom semantic label may cause double announcements',
        correction: 'Wrap children with ExcludeSemantics to prevent duplicate reading',
        severity: severity,
        sourceNode: node.sourceNode,
      ),
    ];
  }
}
```

#### Policy A23: Contextual Button Labels (Advanced Heuristic)

```dart
class ContextualButtonLabelsPolicy extends PolicyRule {
  @override
  String get id => 'flutter_a11y_contextual_button_labels';
  
  @override
  String get name => 'Buttons in lists should have contextual labels';
  
  @override
  ErrorSeverity get severity => ErrorSeverity.INFO;

  @override
  List<Diagnostic> checkNode(SemanticNodeIR node, SemanticContext ctx) {
    // Only check buttons
    if (node.role != SemanticRole.button) return [];
    
    // Only in list contexts
    if (!ctx.hasListItemAncestor) return [];
    
    // Extract signals
    final signals = [
      Signal('inListContext', ctx.hasListItemAncestor, 'Inside list item'),
      Signal('hasGenericLabel', _isGenericLabel(node.label), 'Label is generic'),
      Signal('hasItemTitle', ctx.listItemTitle != null, 'List item has title'),
      Signal('labelIsLiteral', node.confidence > 80, 'Label is literal string'),
    ];
    
    // Extract guards
    final guards = [
      Guard('labelIsExpression', node.confidence < 50, 'Label is expression/localized'),
      Guard('hasProperLabel', _hasContextInLabel(node.label, ctx.listItemTitle), 'Already contextual'),
    ];
    
    // Evaluate
    final decision = ConfidenceEvaluator.evaluate(
      signals: signals,
      guards: guards,
      threshold: 3,
    );
    
    if (decision.shouldReport) {
      final itemTitle = ctx.listItemTitle ?? 'item';
      return [
        Diagnostic(
          ruleId: id,
          message: 'Button label "${node.label}" should include context in list',
          correction: 'Consider using "${node.label} $itemTitle" or similar',
          severity: severity,
          sourceNode: node.sourceNode,
          metadata: {
            'confidence': decision.confidence,
            'itemTitle': itemTitle,
          },
        ),
      ];
    }
    
    return [];
  }
  
  bool _isGenericLabel(String? label) {
    if (label == null) return false;
    const generic = ['delete', 'edit', 'more', 'close', 'open', 'menu'];
    return generic.contains(label.toLowerCase());
  }
  
  bool _hasContextInLabel(String? label, String? itemTitle) {
    if (label == null || itemTitle == null) return false;
    return label.toLowerCase().contains(itemTitle.toLowerCase());
  }
}
```

---

## 8. Integration with Custom Lint

### 8.1 Rule Structure

Each lint rule integrates the IR pipeline:

```dart
class InteractiveControlsLabelRule extends DartLintRule {
  const InteractiveControlsLabelRule() : super(code: _code);

  static const _code = LintCode(
    name: 'flutter_a11y_label_non_text_controls',
    problemMessage: 'Interactive controls must have accessible labels',
    correctionMessage: 'Add a tooltip or Semantics label',
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.addPostRunCallback(() async {
      final unit = await resolver.getResolvedUnitResult();
      
      // Early exits
      if (!fileUsesFlutter(unit)) return;
      if (shouldIgnoreFile(unit.path)) return;
      
      // Build Semantic IR
      final config = loadConfig(context.configs);
      final irBuilder = SemanticIRBuilder(
        knownSemantics: KnownWidgetSemantics(),
        config: config,
      );
      final tree = irBuilder.buildFromAST(unit.unit, unit.path);
      
      // Run policy
      final policy = InteractiveControlsLabelPolicy();
      final diagnostics = policy.checkNode(tree.roots.first, SemanticContext.root(tree));
      
      // Report
      for (final diagnostic in diagnostics) {
        reporter.atNode(diagnostic.sourceNode).report(_code);
      }
    });
  }
}
```

### 8.2 Plugin Registration

```dart
class FlutterA11yLintsPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) {
    final config = loadConfig(configs);
    final rules = <LintRule>[];
    
    // High-confidence rules (always enabled)
    rules.addAll([
      const InteractiveControlsLabelRule(),
      const DecorativeImagesRule(),
      const InformativeImagesRule(),
      const NoRedundantButtonSemanticsRule(),
      const UseIconButtonTooltipRule(),
    ]);
    
    // Heuristic rules (expanded mode only)
    if (config.mode == LintMode.expanded) {
      rules.addAll([
        const CompositeControlsRule(),
        const ReplacementSemanticsRule(),
        const ContextualButtonLabelsRule(),
      ]);
    }
    
    return rules;
  }
}
```

---

## 9. Testing Strategy

### 9.1 IR Construction Tests

Test that AST correctly transforms to Semantic IR:

```dart
testWidgets('IconButton without tooltip creates button node with no label', (tester) async {
  final code = '''
    IconButton(
      icon: Icon(Icons.delete),
      onPressed: () {},
    )
  ''';
  
  final tree = buildIRFromCode(code);
  final node = tree.roots.first;
  
  expect(node.role, SemanticRole.button);
  expect(node.isInteractive, true);
  expect(node.label, null);
  expect(node.isFocusable, true);
});

testWidgets('IconButton with tooltip has label', (tester) async {
  final code = '''
    IconButton(
      icon: Icon(Icons.delete),
      onPressed: () {},
      tooltip: 'Delete item',
    )
  ''';
  
  final tree = buildIRFromCode(code);
  final node = tree.roots.first;
  
  expect(node.label, 'Delete item');
});
```

### 9.2 Policy Tests

Test that policies correctly identify violations:

```dart
test('InteractiveControlsLabelPolicy reports missing label', () {
  final node = SemanticNodeIR(
    id: 'test',
    role: SemanticRole.button,
    isInteractive: true,
    label: null,
    sourceNode: mockAstNode,
  );
  
  final policy = InteractiveControlsLabelPolicy();
  final diagnostics = policy.checkNode(node, mockContext);
  
  expect(diagnostics, hasLength(1));
  expect(diagnostics.first.ruleId, 'flutter_a11y_label_non_text_controls');
});

test('InteractiveControlsLabelPolicy accepts button with label', () {
  final node = SemanticNodeIR(
    id: 'test',
    role: SemanticRole.button,
    isInteractive: true,
    label: 'Delete',
    sourceNode: mockAstNode,
  );
  
  final policy = InteractiveControlsLabelPolicy();
  final diagnostics = policy.checkNode(node, mockContext);
  
  expect(diagnostics, isEmpty);
});
```

### 9.3 Integration Tests

Test complete pipeline with real Flutter code:

```dart
test('A01: warns on IconButton without tooltip', () async {
  final code = '''
    import 'package:flutter/material.dart';
    
    class MyWidget extends StatelessWidget {
      @override
      Widget build(BuildContext context) {
        return IconButton(
          icon: Icon(Icons.delete),
          onPressed: () {},
        );
      }
    }
  ''';
  
  final lints = await runLintOnCode(code);
  
  expect(lints, hasLength(1));
  expect(lints.first.code, 'flutter_a11y_label_non_text_controls');
});
```

### 9.4 Semantics Extraction Tests

Test that runtime extraction produces expected results:

```dart
testWidgets('IconButton has button flag', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: IconButton(
        icon: Icon(Icons.add),
        onPressed: () {},
        tooltip: 'Add',
      ),
    ),
  );
  
  final semantics = tester.getSemantics(find.byType(IconButton));
  
  expect(semantics.hasFlag(SemanticsFlag.isButton), true);
  expect(semantics.hasAction(SemanticsAction.tap), true);
  expect(semantics.label, 'Add');
});
```

---

## 10. Configuration System

### 10.1 Configuration Schema

```yaml
# analysis_options.yaml

flutter_a11y_lints:
  # Linting mode
  mode: conservative  # conservative | expanded
  
  # Ignore specific rules
  ignore_rules:
    - flutter_a11y_contextual_button_labels
    - flutter_a11y_merge_composite_values
  
  # Ignore specific file patterns
  ignore_paths:
    - lib/generated/**
    - lib/**/*.g.dart
    - lib/**/*.freezed.dart
  
  # Register custom widgets with semantic behavior
  custom_widgets:
    AppButton:
      role: button
      is_interactive: true
      semantics_managed: true
    AppListTile:
      role: list_item
      merges_children: true
      semantics_managed: true
  
  # Safe components that don't need linting
  safe_components:
    - DesignSystemButton
    - AccessibleCard
    - A11yImage
  
  # Override rule severities
  rule_severity_overrides:
    flutter_a11y_merge_composite_values: warning
    flutter_a11y_contextual_button_labels: info
  
  # Heuristic tuning
  heuristic_thresholds:
    contextual_labels: 4  # Confidence threshold
    composite_controls: 3
```

### 10.2 Configuration Loading

```dart
class A11yLintConfig {
  final LintMode mode;
  final Set<String> ignoreRules;
  final List<String> ignorePaths;
  final Map<String, WidgetSemanticsInfo> customWidgets;
  final Set<String> safeComponents;
  final Map<String, ErrorSeverity> severityOverrides;
  final Map<String, int> heuristicThresholds;
  
  const A11yLintConfig({
    this.mode = LintMode.conservative,
    this.ignoreRules = const {},
    this.ignorePaths = const [],
    this.customWidgets = const {},
    this.safeComponents = const {},
    this.severityOverrides = const {},
    this.heuristicThresholds = const {},
  });
  
  factory A11yLintConfig.fromYaml(Map<String, dynamic> yaml) {
    // Parse configuration
    return A11yLintConfig(
      mode: _parseMode(yaml['mode']),
      ignoreRules: Set.from(yaml['ignore_rules'] ?? []),
      ignorePaths: List.from(yaml['ignore_paths'] ?? []),
      customWidgets: _parseCustomWidgets(yaml['custom_widgets']),
      safeComponents: Set.from(yaml['safe_components'] ?? []),
      severityOverrides: _parseSeverityOverrides(yaml['rule_severity_overrides']),
      heuristicThresholds: _parseThresholds(yaml['heuristic_thresholds']),
    );
  }
}

enum LintMode {
  conservative,  // Only high-confidence rules
  expanded,      // All rules including heuristics
}
```

---

## 11. Strengths & Limitations

### 11.1 Strengths

✅ **Compiler-Like Architecture**
- Clear separation of concerns
- Deterministic and repeatable
- Easy to test and debug

✅ **High Accuracy**
- Runtime-derived widget semantics
- No manual guesswork about Flutter behavior
- Stays synchronized with Flutter releases

✅ **Low False Positives**
- Multi-signal heuristic system
- Configurable confidence thresholds
- Easy suppression mechanisms

✅ **Extensible Design**
- New policies easy to add
- IR abstraction layer
- Pluggable heuristic rules

✅ **Developer-Friendly**
- Clear error messages
- Actionable corrections
- Flexible configuration

### 11.2 Limitations

⚠️ **No Runtime Layout**
- Cannot determine actual widget sizes
- Cannot detect visual order mismatches
- Cannot see constraint-based behavior

⚠️ **Approximate IR**
- Based on static analysis only
- Cannot evaluate conditional expressions
- Cannot follow widget indirection

⚠️ **Heuristic Uncertainty**
- Some policies require guessing
- May miss edge cases
- Confidence scoring is approximate

⚠️ **Single Widget Configuration**
- Extractor assumes one instance per widget
- May miss variant behaviors
- Custom configurations not captured

⚠️ **Performance Overhead**
- IR construction adds processing time
- May be slow on very large files
- Requires caching strategies

---

## 12. Developer Workflow

### 12.1 Regular Development

1. **Write Flutter code**
2. **Linter runs automatically** in IDE
3. **Fix reported issues** or suppress false positives
4. **Commit clean code**

### 12.2 Updating Flutter Version

When Flutter releases new widgets or changes behavior:

1. **Update Flutter SDK**
2. **Update widget catalogue** (`tools/semantics_extractor/widget_catalogue.dart`)
3. **Run extractor:**
   ```bash
   flutter test tools/semantics_extractor/extract_semantics_test.dart
   ```
4. **Generate source:**
   ```bash
   dart run tools/semantics_extractor/generate_source.dart
   dart format lib/src/ir/known_widget_semantics.g.dart
   ```
5. **Run tests:**
   ```bash
   flutter test
   ```
6. **Release plugin update**

### 12.3 Adding New Rules

1. **Define policy class** extending `PolicyRule`
2. **Implement `checkNode` method**
3. **Write tests** for policy
4. **Create lint rule** integrating policy
5. **Register in plugin**
6. **Document in rule reference**
7. **Add examples** to test app

---

## 13. Future Enhancements

### Potential Extensions

1. **Layout-Aware Analysis** (Experimental)
   - Limited layout inference
   - Size-based heuristics
   - Visual order detection

2. **Cross-File Analysis**
   - Component consistency checks
   - Design pattern validation
   - Global accessibility scoring

3. **Machine Learning Integration**
   - ML-based signal weighting
   - Pattern recognition
   - False positive prediction

4. **DevTools Integration**
   - Real-time semantic tree visualization
   - Interactive fix suggestions
   - Screen reader preview

5. **Auto-Fix Support**
   - Automated code transformations
   - Safe refactorings
   - Batch fixes

---

## 14. Summary

This Flutter accessibility linter represents a **modern static analysis system** built on:

✨ **Compiler-Inspired Architecture**
- Multi-stage transformation pipeline
- Clean separation of concerns
- Deterministic and testable

🌳 **Semantic IR**
- Approximates runtime accessibility tree
- Abstracts away AST complexity
- Enables sophisticated analysis

🎯 **Heuristic Engine**
- Signal-based detection
- Confidence scoring
- False positive prevention

📋 **Policy Engine**
- Rule-based enforcement
- Contextual analysis
- Extensible design

🔧 **Automated Extraction**
- Runtime-derived semantics
- Zero manual maintenance
- Stays current with Flutter

The system is engineered for **precision**, **predictability**, and **maintainability**, delivering practical accessibility enforcement for Flutter applications.

---

## 15. References

### Flutter Documentation
- [Flutter Accessibility Guide](https://docs.flutter.dev/development/accessibility-and-localization/accessibility)
- [Semantics API](https://api.flutter.dev/flutter/widgets/Semantics-class.html)
- [SemanticsProperties](https://api.flutter.dev/flutter/semantics/SemanticsProperties-class.html)

### Web Standards
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [ARIA Authoring Practices](https://www.w3.org/WAI/ARIA/apg/)

### Tools & Frameworks
- [custom_lint Package](https://pub.dev/packages/custom_lint)
- [analyzer Package](https://pub.dev/packages/analyzer)
- [flutter_test Package](https://api.flutter.dev/flutter/flutter_test/flutter_test-library.html)

---

**Document Version:** 1.0  
**Last Updated:** December 2025  
**Status:** Design Complete — Ready for Implementation
