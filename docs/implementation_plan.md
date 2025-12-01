# Flutter A11y Lints - Implementation Plan (Updated)

**Document Version:** 1.0  
**Last Updated:** December 1, 2025  
**Status:** In Progress - Foundation Complete

---

## Executive Summary

This document provides a comprehensive, phase-based implementation plan for the `flutter_a11y_lints` project. The plan is designed to guide development from the current state (foundation complete with 9 rules implemented) to a production-ready accessibility linter with both high-confidence and heuristic rules.

### Current Status Overview

✅ **Completed:**
- Core project structure
- Essential utilities (AST, type checking, Flutter detection)
- Plugin infrastructure
- 9 lint rules implemented (A01, A02, A03, A04, A05, A06, A07, A08, A21)
- Basic test framework with tests for all 9 rules

🚧 **In Progress:**
- Test coverage expansion
- Documentation refinement
- Configuration system enhancement

⏳ **Not Started:**
- Additional high-confidence rules (A11, A16, A18, A22, A24)
- Heuristic engine framework
- Advanced configuration system
- CI/CD pipeline
- Production release preparation

---

## Architecture Analysis

### Current Implementation Strengths

1. **Clean Modular Structure**
   - Rules are isolated in separate files
   - Shared utilities properly extracted
   - Clear separation of concerns

2. **Utility Foundation**
   - `ast_utils.dart`: Argument extraction, child detection
   - `type_utils.dart`: Widget type checking (IconButton, Material buttons, Image, Semantics)
   - `flutter_imports.dart`: Flutter package detection
   - `widget_context.dart`: Context utilities (present but not widely used yet)

3. **Rule Quality**
   - All rules follow consistent pattern
   - Proper error severity (WARNING)
   - Clear problem and correction messages
   - Async-safe implementation with `addPostRunCallback`

### Areas Needing Enhancement

1. **Utility Coverage**
   - Missing: Generated file detection
   - Missing: Configuration loader
   - Missing: Localization detection
   - Missing: Advanced AST traversal helpers

2. **Configuration**
   - No mode system (conservative/expanded)
   - No rule enable/disable mechanism
   - No ignore patterns support
   - No custom widget registration

3. **Testing**
   - Tests are basic (1-2 cases per rule)
   - Missing edge case coverage
   - No regression test framework
   - No performance benchmarks

4. **Documentation**
   - Comprehensive reference docs exist
   - Missing: User guide
   - Missing: Configuration guide
   - Missing: Contribution workflow

---

## Implementation Roadmap

### Timeline Overview

- **Phase 1-2:** Already Complete (Weeks 1-4)
- **Phase 3:** Current Focus (Weeks 5-6)
- **Phase 4:** Next Priority (Weeks 7-8)
- **Phase 5-6:** Medium Term (Weeks 9-14)
- **Phase 7-8:** Production Release (Weeks 15-20)
- **Phase 9-10:** Post-Release (Ongoing)

---

## Phase 1: Foundation & Infrastructure ✅ COMPLETE

### Completed Tasks

✅ **1.1 Project Structure**
- Folder organization complete
- Dependencies configured
- Package metadata ready

✅ **1.2 Core Utilities**
- AST utilities implemented
- Type checking functions
- Flutter detection
- Argument extraction helpers

✅ **1.3 Plugin Infrastructure**
- Plugin entry point created
- Rule registration system working
- Custom lint integration complete

✅ **1.4 Initial Test Framework**
- Test structure established
- Custom lint test runner configured
- 9 test files created

### Phase 1 Assessment
**Status:** ✅ Complete  
**Quality:** Good foundation, ready for expansion  
**Next Steps:** Enhance utilities and expand test coverage

---

## Phase 2: Initial Rules Implementation ✅ COMPLETE

### Completed Rules (9 total)

✅ **A01: Label Non-Text Controls**
- Detection: IconButton without tooltip
- Supports: Semantics wrapper detection
- Tests: Basic positive/negative cases

✅ **A02: Avoid Redundant Role Words**
- Detection: Keywords in tooltips/labels
- Keywords: button, btn, tab, selected, checkbox, switch
- Tests: String literal checking

✅ **A03: Decorative Images Excluded**
- Detection: Images in ListTile.leading
- Missing: Filename pattern detection (mentioned in docs)
- Tests: Basic image cases

✅ **A04: Informative Images Labeled**
- Detection: Interactive images without semanticLabel
- Checks: Tappable image contexts
- Tests: Various image scenarios

✅ **A05: No Redundant Button Semantics**
- Detection: Semantics(button: true) wrapping Material buttons
- Supports: All Material button types
- Tests: Button wrapping cases

✅ **A06: Merge Multi-Part Single Concept**
- Detection: Row/Wrap with Icon + Text
- Checks: MergeSemantics presence
- Status: Heuristic rule (should be INFO)
- Tests: Composite widget cases

✅ **A07: Replace Semantics Cleanly**
- Detection: Semantics with custom label
- Missing: ExcludeSemantics check (mentioned in docs)
- Status: Heuristic rule (should be INFO)
- Tests: Label replacement cases

✅ **A08: Block Semantics Only for True Modals**
- Detection: BlockSemantics usage
- Status: Heuristic rule (should be INFO)
- Tests: Modal context detection

✅ **A21: Use IconButton Tooltip Parameter**
- Detection: Tooltip widget wrapping IconButton
- Correction: Suggest tooltip parameter
- Tests: Wrapper detection

### Phase 2 Assessment
**Status:** ✅ Complete  
**Quality:** Rules implemented, some refinement needed  
**Issues Identified:**
1. Some rules marked WARNING should be INFO (A06, A07, A08)
2. Missing features mentioned in docs (filename patterns, ExcludeSemantics check)
3. Test coverage is minimal

---

## Phase 3: Testing & Quality Enhancement 🚧 IN PROGRESS

**Priority:** HIGH  
**Timeline:** Weeks 5-6  
**Current Status:** 20% complete

### Tasks

#### 3.1 Test Coverage Expansion (Week 5)
**Status:** Not Started

- [ ] **A01 Tests Enhancement**
  - Add custom widget wrapper cases
  - Test GestureDetector + Semantics patterns
  - Test InkWell scenarios
  - Add FloatingActionButton cases
  
- [ ] **A02 Tests Enhancement**
  - Test all keyword variations
  - Test localization expressions (should skip)
  - Test nested button scenarios
  - Add case sensitivity tests
  
- [ ] **A03 Tests Enhancement**
  - Add filename pattern tests (background, decoration, pattern)
  - Test CircleAvatar cases
  - Test excludeFromSemantics property
  - Add negative cases with semanticLabel
  
- [ ] **A04 Tests Enhancement**
  - Test multiple image contexts
  - Test Image.network, Image.file, Image.memory
  - Test backgroundImage patterns
  - Test Semantics wrapper detection
  
- [ ] **A05 Tests Enhancement**
  - Test each Material button type individually
  - Test nested Semantics wrappers
  - Test button: false (should not warn)
  - Test with additional semantic properties
  
- [ ] **A06 Tests Enhancement**
  - Test MergeSemantics presence (should not warn)
  - Test Row vs Column vs Wrap
  - Test multiple icons or texts
  - Test custom widgets
  
- [ ] **A07 Tests Enhancement**
  - Test ExcludeSemantics detection
  - Test multiple child scenarios
  - Test replacement patterns
  - Add false positive prevention tests
  
- [ ] **A08 Tests Enhancement**
  - Test dialog contexts
  - Test BottomSheet scenarios
  - Test SnackBar (should not warn about BlockSemantics absence)
  - Add context detection tests
  
- [ ] **A21 Tests Enhancement**
  - Test IconButton with existing tooltip
  - Test multiple wrapper levels
  - Test custom tooltip widgets
  - Add migration pattern tests

#### 3.2 Edge Case & Regression Tests (Week 5-6)
**Status:** Not Started

- [ ] Create regression test suite structure
- [ ] Test with localization patterns (`context.l10n`, `S.of(context)`)
- [ ] Test with custom design system wrappers
- [ ] Test with generated code patterns
- [ ] Test with builder contexts (ListView.builder, etc.)
- [ ] Test performance on large files (1000+ lines)
- [ ] Add tests for multi-file scenarios (what should NOT be detected)

#### 3.3 Rule Refinement (Week 6)
**Status:** Not Started

- [ ] **Severity Adjustment**
  - Change A06 to INFO (heuristic)
  - Change A07 to INFO (heuristic)
  - Change A08 to INFO (heuristic)
  - Document reasoning
  
- [ ] **A03 Enhancement**
  - Implement filename pattern detection
  - Add decorative keywords: background, bg, backdrop, decor, decorative, pattern, wallpaper, divider, separator
  
- [ ] **A07 Enhancement**
  - Add ExcludeSemantics checking
  - Improve child semantic detection

#### 3.4 Test Documentation (Week 6)
**Status:** Not Started

- [ ] Document test strategy
- [ ] Create test writing guidelines
- [ ] Add test examples for contributors
- [ ] Document edge cases and why they exist

### Phase 3 Deliverables

- [ ] 100+ total test cases across all rules
- [ ] Each rule has 10+ test scenarios
- [ ] Regression test framework established
- [ ] Performance benchmarks documented
- [ ] Test documentation complete

### Phase 3 Success Criteria

- All existing rules have comprehensive tests
- Zero known false positives in test suite
- Tests cover edge cases and custom patterns
- Performance < 30ms per file
- Test documentation enables contributors

---

## Phase 4: Utility Enhancement & Configuration System

**Priority:** HIGH  
**Timeline:** Weeks 7-8  
**Dependencies:** Phase 3 complete

### Tasks

#### 4.1 Enhanced Utilities (Week 7)

- [ ] **Ignore Patterns Module** (`utils/ignore_patterns.dart`)
  ```dart
  bool shouldIgnoreFile(String filePath);
  bool isGeneratedFile(String filePath);
  List<String> defaultIgnorePatterns = [
    '**/*.g.dart',
    '**/*.freezed.dart',
    '**/*.gen.dart',
    '**/generated/**',
  ];
  ```

- [ ] **Configuration Loader** (`utils/config_loader.dart`)
  ```dart
  class A11yLintConfig {
    final RuleMode mode;
    final List<String> ignoreRules;
    final List<String> ignorePaths;
    final List<String> additionalButtonClasses;
    final List<String> safeComponents;
  }
  
  A11yLintConfig loadConfig(CustomLintConfigs configs);
  ```

- [ ] **Localization Detection** (`utils/localization_utils.dart`)
  ```dart
  bool isLocalizationExpression(Expression expr);
  // Detects: context.l10n.*, S.of(context).*, tr(...)
  ```

- [ ] **Advanced AST Traversal** (`utils/widget_tree.dart` enhancement)
  ```dart
  T? findNearestAncestor<T>(AstNode node);
  List<T> findDescendants<T>(AstNode node);
  bool hasAncestorOfType<T>(AstNode node);
  ```

- [ ] **Text Analysis** (`utils/text_analysis.dart`)
  ```dart
  String normalizeText(String text);
  bool containsKeyword(String text, List<String> keywords);
  List<String> tokenize(String text);
  ```

#### 4.2 Configuration System (Week 7-8)

- [ ] **Define Configuration Schema**
  ```yaml
  flutter_a11y_lints:
    mode: conservative  # or expanded
    ignore_rules:
      - flutter_a11y_merge_composite_values
    ignore_paths:
      - lib/generated/**
      - lib/**/*.g.dart
    additional_button_classes:
      - CupertinoButton
      - AppPrimaryButton
    safe_components:
      - AppListTile
      - DesignSystemButton
    rule_severity_overrides:
      flutter_a11y_contextual_button_labels: warning
  ```

- [ ] **Implement Config Loading**
  - Parse `analysis_options.yaml`
  - Validate configuration
  - Provide defaults
  - Handle errors gracefully

- [ ] **Mode System**
  - Conservative mode: Only high-confidence rules (WARNING)
  - Expanded mode: All rules including heuristics (INFO)
  - Document mode differences

- [ ] **Integrate Config with Plugin**
  - Load config in plugin.dart
  - Filter rules based on config
  - Apply severity overrides
  - Respect ignore patterns

#### 4.3 Plugin Enhancement (Week 8)

- [ ] **Rule Categories**
  ```dart
  // High-confidence rules (conservative mode)
  final conservativeRules = <LintRule>[
    const LabelNonTextControls(),
    const DecorativeImagesExcluded(),
    const InformativeImagesLabeled(),
    const NoRedundantButtonSemantics(),
    const UseIconButtonTooltipParameter(),
  ];
  
  // Heuristic rules (expanded mode only)
  final heuristicRules = <LintRule>[
    const AvoidRedundantRoleWords(),
    const MergeMultiPartSingleConcept(),
    const ReplaceSemanticsCleanly(),
    const BlockSemanticsOnlyForTrueModals(),
  ];
  ```

- [ ] **Config-Driven Loading**
  ```dart
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) {
    final config = loadConfig(configs);
    final rules = <LintRule>[...conservativeRules];
    
    if (config.mode == RuleMode.expanded) {
      rules.addAll(heuristicRules);
    }
    
    return rules.where((rule) => 
      !config.ignoreRules.contains(rule.code.name)
    ).toList();
  }
  ```

#### 4.4 Documentation (Week 8)

- [ ] **Configuration Guide** (`docs/configuration.md`)
  - All configuration options explained
  - Examples for common scenarios
  - Mode selection guidance
  - Custom widget registration

- [ ] **User Guide** (`docs/user_guide.md`)
  - Installation instructions
  - Getting started
  - Understanding lint messages
  - Suppressing warnings
  - Best practices

### Phase 4 Deliverables

- [ ] Complete utility library
- [ ] Full configuration system
- [ ] Mode-based rule loading
- [ ] Ignore patterns working
- [ ] Configuration documentation
- [ ] User guide

### Phase 4 Success Criteria

- Configuration system fully functional
- All utilities tested
- Plugin respects all config options
- Documentation enables easy setup
- Custom widgets can be registered

---

## Phase 5: Additional High-Confidence Rules

**Priority:** MEDIUM  
**Timeline:** Weeks 9-11  
**Dependencies:** Phase 4 complete

### Remaining High-Confidence Rules

According to the design docs, these rules are missing:

#### 5.1 Rule A11: Minimum Tap Target Size (Week 9)

**Specification:**
- Detect SizedBox/Container with literal width/height < 44/48
- Only check interactive children
- Skip expressions, variables, theme-based constraints
- Do NOT attempt layout inference

**Implementation Tasks:**
- [ ] Create `a11_minimum_tap_target_size.dart`
- [ ] Detect SizedBox, Container, ConstrainedBox
- [ ] Check for literal numeric values < 44
- [ ] Verify interactive child
- [ ] Skip dynamic sizing
- [ ] Write 15+ test cases
- [ ] Add to plugin (conservative mode)

**Test Scenarios:**
- Literal sizes < 44 (should warn)
- Literal sizes >= 48 (should not warn)
- Variable-based sizing (should not warn)
- MediaQuery/LayoutBuilder (should not warn)
- Theme-based constraints (should not warn)
- Non-interactive widgets (should not warn)

#### 5.2 Rule A16: Toggle State via Semantics Flag (Week 9)

**Specification:**
- Detect toggle widgets (Switch, Checkbox, Radio, ToggleButtons)
- Check for state words in Semantics.label conditionals
- Suggest using `toggled`/`checked` properties

**Implementation Tasks:**
- [ ] Create `a16_toggle_state_via_semantics_flag.dart`
- [ ] Detect toggle widget types
- [ ] Check Semantics.label for state keywords
- [ ] Detect conditional label expressions
- [ ] Suggest semantic flags instead
- [ ] Write 12+ test cases
- [ ] Add to plugin (conservative mode)

**Detection Pattern:**
```dart
// BAD
Semantics(
  label: isOn ? 'On' : 'Off',
  child: Switch(value: isOn, onChanged: ...),
)

// GOOD
Semantics(
  toggled: isOn,
  child: Switch(value: isOn, onChanged: ...),
)
```

#### 5.3 Rule A18: Avoid Hidden Focus Traps (Week 10)

**Specification:**
- Detect Offstage(offstage: true) with focusable children
- Detect Visibility(visible: false) with focusable children
- Only check literal boolean values

**Implementation Tasks:**
- [ ] Create `a18_avoid_hidden_focus_traps.dart`
- [ ] Detect Offstage/Visibility widgets
- [ ] Check for literal true/false
- [ ] Identify focusable descendants (TextField, buttons, etc.)
- [ ] Write 10+ test cases
- [ ] Add to plugin (conservative mode)

**Focusable Widget Types:**
- TextField, TextFormField
- All button types
- GestureDetector with callbacks
- InkWell, InkResponse
- Custom focus widgets

#### 5.4 Rule A22: Respect Widget Semantic Boundaries (Week 10)

**Specification:**
- Detect MergeSemantics wrapping ListTile family
- These widgets have built-in semantic merging
- Wrapping breaks their behavior

**Implementation Tasks:**
- [ ] Create `a22_respect_widget_semantic_boundaries.dart`
- [ ] Detect MergeSemantics widgets
- [ ] Check child for ListTile, CheckboxListTile, SwitchListTile, RadioListTile
- [ ] Write 8+ test cases
- [ ] Add to plugin (conservative mode)

**ListTile Family:**
- ListTile
- CheckboxListTile
- SwitchListTile
- RadioListTile
- ExpansionTile (optional)

#### 5.5 Rule A24: Exclude Visual-Only Indicators (Week 11)

**Specification:**
- Detect Icons.drag_handle and Icons.drag_indicator
- Check for ExcludeSemantics wrapper
- Common in ListTile.leading

**Implementation Tasks:**
- [ ] Create `a24_exclude_visual_only_indicators.dart`
- [ ] Detect specific icon types
- [ ] Check for ExcludeSemantics ancestor
- [ ] Handle ListTile context
- [ ] Write 10+ test cases
- [ ] Add to plugin (conservative mode)

**Visual-Only Icons:**
- Icons.drag_handle
- Icons.drag_indicator
- Icons.more_vert (context-dependent)
- Icons.more_horiz (context-dependent)

### Phase 5 Deliverables

- [ ] 5 new high-confidence rules implemented
- [ ] 55+ new test cases
- [ ] All rules in conservative mode
- [ ] Documentation updated
- [ ] Examples in test app

### Phase 5 Success Criteria

- All high-confidence rules from spec implemented
- Zero false positives in tests
- Performance maintained (< 30ms per file)
- Documentation complete
- Ready for conservative mode release

---

## Phase 6: Heuristic Engine Framework

**Priority:** MEDIUM  
**Timeline:** Weeks 12-14  
**Dependencies:** Phase 5 complete

### Overview

Build the infrastructure for medium-confidence rules that require contextual signals and multi-factor evaluation.

### 6.1 Heuristic Engine Design (Week 12)

**Core Concepts:**

```dart
/// A boolean fact about an AST node
class Signal {
  final String name;
  final bool value;
  const Signal(this.name, this.value);
}

/// Negative conditions that suppress warnings
class Guard {
  final String name;
  final bool applies;
  const Guard(this.name, this.applies);
}

/// Result of heuristic evaluation
class HeuristicDecision {
  final bool shouldReport;
  final int confidence;
  final List<Signal> signals;
  final List<Guard> guards;
  
  const HeuristicDecision({
    required this.shouldReport,
    required this.confidence,
    this.signals = const [],
    this.guards = const [],
  });
  
  factory HeuristicDecision.lint([int confidence = 3]) =>
      HeuristicDecision(shouldReport: true, confidence: confidence);
      
  factory HeuristicDecision.noLint() =>
      const HeuristicDecision(shouldReport: false, confidence: 0);
}
```

**Implementation Tasks:**
- [ ] Create `utils/heuristic_engine.dart`
- [ ] Implement Signal class
- [ ] Implement Guard class
- [ ] Implement HeuristicDecision class
- [ ] Create base HeuristicRule class
- [ ] Document heuristic design patterns

### 6.2 Signal Extractors (Week 12-13)

**Common Signals:**

```dart
class SignalExtractor {
  // Structural signals
  static Signal parentIsInteractive(AstNode node);
  static Signal hasIconAndTextChildren(InstanceCreationExpression node);
  static Signal insideBuilderContext(AstNode node);
  
  // Semantic signals
  static Signal hasSemanticsAncestor(AstNode node);
  static Signal hasSemanticsOverride(AstNode node);
  static Signal usesSameCallback(InstanceCreationExpression node);
  
  // Content signals
  static Signal tooltipIsLiteral(InstanceCreationExpression node);
  static Signal hasGenericTooltip(String text);
  static Signal hasItemVariable(AstNode context);
  
  // Context signals
  static Signal isInSafeComponent(AstNode node, A11yLintConfig config);
  static Signal isLocalizedExpression(Expression expr);
}
```

**Implementation Tasks:**
- [ ] Create `utils/signal_extractor.dart`
- [ ] Implement all signal extractors
- [ ] Test each signal individually
- [ ] Document signal meanings
- [ ] Provide usage examples

### 6.3 Guard System (Week 13)

**Common Guards:**

```dart
class GuardChecker {
  // Configuration guards
  static Guard isInSafeComponent(AstNode node, A11yLintConfig config);
  static Guard matchesIgnorePattern(AstNode node, A11yLintConfig config);
  
  // Semantic guards
  static Guard hasExistingSemanticsWrapper(AstNode node);
  static Guard hasProperSemanticLabel(AstNode node);
  
  // Localization guards
  static Guard usesLocalization(Expression expr);
  static Guard isGeneratedCode(String filePath);
  
  // Structural guards
  static Guard hasComplexLayout(AstNode node);
  static Guard hasMultipleIndependentActions(AstNode node);
}
```

**Implementation Tasks:**
- [ ] Create `utils/guard_checker.dart`
- [ ] Implement all guard checks
- [ ] Test each guard
- [ ] Document guard purposes
- [ ] Provide guard combination examples

### 6.4 Confidence Scoring (Week 13-14)

**Scoring System:**

```dart
class ConfidenceEvaluator {
  /// Evaluate confidence based on signals and guards
  static HeuristicDecision evaluate({
    required List<Signal> signals,
    required List<Guard> guards,
    required int threshold,
  }) {
    // Apply guards first - any guard can cancel
    for (final guard in guards) {
      if (guard.applies) {
        return HeuristicDecision.noLint();
      }
    }
    
    // Count positive signals
    final score = signals.where((s) => s.value).length;
    
    if (score >= threshold) {
      return HeuristicDecision(
        shouldReport: true,
        confidence: score,
        signals: signals,
        guards: guards,
      );
    }
    
    return HeuristicDecision.noLint();
  }
}
```

**Implementation Tasks:**
- [ ] Create `utils/confidence_evaluator.dart`
- [ ] Implement scoring logic
- [ ] Support configurable thresholds
- [ ] Add confidence reporting
- [ ] Test various score combinations

### 6.5 Heuristic Rule Base Class (Week 14)

```dart
abstract class HeuristicLintRule extends DartLintRule {
  const HeuristicLintRule({required LintCode code}) : super(code: code);
  
  /// Extract signals for this rule
  List<Signal> extractSignals(AstNode node, A11yLintConfig config);
  
  /// Check guards for this rule
  List<Guard> checkGuards(AstNode node, A11yLintConfig config);
  
  /// Confidence threshold (default: 3)
  int get confidenceThreshold => 3;
  
  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final config = loadConfig(context.configs);
    
    context.addPostRunCallback(() async {
      final unit = await resolver.getResolvedUnitResult();
      if (!fileUsesFlutter(unit)) return;
      if (shouldIgnoreFile(unit.path, config)) return;
      
      registerVisitors(context, reporter, config);
    });
  }
  
  /// Subclasses register their specific visitors
  void registerVisitors(
    CustomLintContext context,
    ErrorReporter reporter,
    A11yLintConfig config,
  );
  
  /// Helper to evaluate and report
  void evaluateAndReport(
    AstNode node,
    ErrorReporter reporter,
    A11yLintConfig config,
  ) {
    final signals = extractSignals(node, config);
    final guards = checkGuards(node, config);
    
    final decision = ConfidenceEvaluator.evaluate(
      signals: signals,
      guards: guards,
      threshold: confidenceThreshold,
    );
    
    if (decision.shouldReport) {
      reporter.atNode(node).report(code);
    }
  }
}
```

**Implementation Tasks:**
- [ ] Create base class
- [ ] Document usage pattern
- [ ] Provide template
- [ ] Create example rule
- [ ] Test base functionality

### Phase 6 Deliverables

- [ ] Complete heuristic engine
- [ ] Signal extraction system
- [ ] Guard checking system
- [ ] Confidence evaluation
- [ ] Base class for heuristic rules
- [ ] Comprehensive documentation
- [ ] Example implementations

### Phase 6 Success Criteria

- Heuristic framework is reusable
- Clear pattern for new heuristic rules
- Guards prevent false positives
- Confidence scoring is tunable
- Documentation enables contributors
- Ready to migrate existing heuristic rules

---

## Phase 7: Heuristic Rule Migration & Enhancement

**Priority:** MEDIUM  
**Timeline:** Weeks 15-17  
**Dependencies:** Phase 6 complete

### 7.1 Migrate Existing Heuristic Rules (Week 15)

**Rules to Migrate:**
- A02: Avoid Redundant Role Words (change to INFO)
- A06: Merge Multi-Part Single Concept (change to INFO)
- A07: Replace Semantics Cleanly (change to INFO)
- A08: Block Semantics Only for True Modals (change to INFO)

**Migration Tasks for Each Rule:**

1. **A02 Migration**
   - [ ] Refactor to use HeuristicLintRule base
   - [ ] Define signals (isLiteral, hasKeyword, isInButtonContext)
   - [ ] Define guards (isLocalized, isInSafeComponent)
   - [ ] Set threshold: 2
   - [ ] Change severity to INFO
   - [ ] Update tests
   - [ ] Document heuristic nature

2. **A06 Migration**
   - [ ] Refactor to use HeuristicLintRule base
   - [ ] Define signals:
     - parentIsInteractive
     - hasIconAndTextChildren
     - usesSameCallback
   - [ ] Define guards:
     - hasMergeSemanticsAncestor
     - isInSafeComponent
     - hasComplexLayout
   - [ ] Set threshold: 3
   - [ ] Change severity to INFO
   - [ ] Update tests
   - [ ] Document pattern detection

3. **A07 Migration**
   - [ ] Refactor to use HeuristicLintRule base
   - [ ] Define signals:
     - hasCustomLabel
     - hasSemanticChildren
     - missingExcludeSemantics
   - [ ] Define guards:
     - hasExcludeSemantics
     - childrenHaveNoSemantics
   - [ ] Set threshold: 2
   - [ ] Change severity to INFO
   - [ ] Update tests
   - [ ] Add ExcludeSemantics detection

4. **A08 Migration**
   - [ ] Refactor to use HeuristicLintRule base
   - [ ] Define signals:
     - isBlockSemantics
     - isNotInModalContext
     - isInSnackbarContext
   - [ ] Define guards:
     - isInDialogBuilder
     - isInBottomSheet
     - isInDrawer
   - [ ] Set threshold: 2
   - [ ] Change severity to INFO
   - [ ] Update tests
   - [ ] Improve context detection

### 7.2 New Heuristic Rules (Week 16-17)

#### A23: Contextual Button Labels (HIGH PRIORITY)

**Specification:**
- Detect IconButton in ListView.builder / GridView.builder
- Check for generic tooltip patterns
- Suggest including item identifier

**Signals:**
- insideBuilderContext
- hasItemVariable
- hasItemTitleText
- tooltipIsLiteral
- hasGenericTooltip ('Delete', 'Edit', 'More')

**Guards:**
- tooltipIsLocalized
- hasSemanticsOverride
- isInSafeComponent

**Threshold:** 4

**Implementation:**
- [ ] Create `a23_contextual_button_labels.dart`
- [ ] Implement builder detection
- [ ] Implement item variable detection
- [ ] Implement generic tooltip detection
- [ ] Set up confidence scoring
- [ ] Write 20+ test cases
- [ ] Add to plugin (expanded mode)

#### A09: Units in Numeric Values (MEDIUM PRIORITY)

**Specification:**
- Detect Text widgets with numeric content
- Check for unit indicators
- Suggest adding units

**Signals:**
- hasNumericContent
- noUnitSuffix
- isValueDisplay (not in input field)

**Guards:**
- isLocalizedText
- isTimestamp
- isPercentage
- isCount

**Threshold:** 2

**Implementation:**
- [ ] Create `a09_numeric_values_with_units.dart`
- [ ] Implement numeric detection
- [ ] Implement unit detection
- [ ] Define unit patterns
- [ ] Write test cases
- [ ] Add to plugin (expanded mode)

#### A10: Debounce Live Announcements (LOWER PRIORITY)

**Specification:**
- Detect SemanticsService.announce calls
- Check for throttling/debouncing
- Warn about announcement spam

**Signals:**
- isAnnounceCall
- isInLoop
- isInStreamBuilder
- noThrottling

**Guards:**
- hasDebouncePattern
- isSingleShot
- isUserInitiated

**Threshold:** 3

**Implementation:**
- [ ] Create `a10_debounce_live_announcements.dart`
- [ ] Detect announce calls
- [ ] Detect loop contexts
- [ ] Detect throttle patterns
- [ ] Write test cases
- [ ] Add to plugin (expanded mode)

### Phase 7 Deliverables

- [ ] 4 rules migrated to heuristic framework
- [ ] 3 new heuristic rules (A23, A09, A10)
- [ ] All heuristic rules use INFO severity
- [ ] Comprehensive test coverage
- [ ] Heuristic documentation
- [ ] Examples in test app

### Phase 7 Success Criteria

- All heuristic rules follow consistent pattern
- False positive rate < 5%
- Confidence scoring tuned
- Guards effectively prevent noise
- Documentation explains heuristic nature
- Expanded mode provides value

---

## Phase 8: Production Release Preparation

**Priority:** HIGH  
**Timeline:** Weeks 18-20  
**Dependencies:** Phases 1-7 complete

### 8.1 Documentation Finalization (Week 18)

- [ ] **README.md Enhancement**
  - Clear installation instructions
  - Quick start guide
  - Rule summary table
  - Configuration overview
  - Links to detailed docs

- [ ] **User Guide** (`docs/user_guide.md`)
  - Installation steps
  - IDE setup (VS Code, Android Studio)
  - Understanding warnings vs info
  - Suppressing false positives
  - Configuration examples
  - Troubleshooting

- [ ] **Configuration Guide** (`docs/configuration.md`)
  - All options explained
  - Mode selection guidance
  - Custom widget registration
  - Ignore patterns
  - Severity overrides
  - Real-world examples

- [ ] **Contribution Guide** (`CONTRIBUTING.md`)
  - Development setup
  - Rule development workflow
  - Testing requirements
  - PR process
  - Code style
  - Documentation requirements

- [ ] **Rule Reference** (Update `docs/accessibility_rules_reference.md`)
  - All rules documented
  - Examples for each
  - WCAG mappings
  - Fix suggestions
  - Configuration options

- [ ] **API Documentation**
  - Generate dartdoc
  - Add package-level documentation
  - Document public APIs
  - Include examples

### 8.2 Package Publishing Preparation (Week 18)

- [ ] **Pubspec Enhancement**
  - Finalize version: 0.1.0
  - Complete description
  - Add topics/tags
  - Verify repository links
  - Add funding links (optional)

- [ ] **License Verification**
  - Verify MIT license text
  - Add copyright notices
  - Check dependency licenses

- [ ] **CHANGELOG.md**
  - Document all rules
  - Document features
  - Note limitations
  - Migration guide (if needed)

- [ ] **Example Project**
  - Update a11y_test_app
  - Add comprehensive examples
  - Document expected warnings
  - Include README

### 8.3 CI/CD Setup (Week 19)

- [ ] **GitHub Actions Workflows**
  ```yaml
  # .github/workflows/test.yml
  - Run tests on push/PR
  - Multiple Dart SDK versions
  - Code coverage reporting
  - Lint checks
  
  # .github/workflows/publish.yml
  - Automated pub.dev publishing
  - Version tagging
  - Release notes generation
  ```

- [ ] **Test Infrastructure**
  - Run full test suite
  - Performance benchmarks
  - Coverage requirements (>90%)
  - Integration tests

- [ ] **Quality Gates**
  - All tests pass
  - Coverage threshold met
  - No lint warnings
  - Documentation builds

### 8.4 Community Preparation (Week 19)

- [ ] **Issue Templates**
  - Bug report template
  - Feature request template
  - False positive report
  - Rule suggestion

- [ ] **Pull Request Template**
  - Checklist for contributors
  - Testing requirements
  - Documentation requirements

- [ ] **GitHub Discussions**
  - Enable discussions
  - Create categories (Q&A, Ideas, Show and tell)
  - Pin welcome message

- [ ] **Code of Conduct**
  - Add CODE_OF_CONDUCT.md
  - Define community standards

### 8.5 Beta Release (Week 20)

- [ ] **Pre-Release Checklist**
  - [ ] All tests passing
  - [ ] Documentation complete
  - [ ] Examples working
  - [ ] CI/CD functional
  - [ ] No critical issues

- [ ] **Version 0.1.0-beta.1 Release**
  - Publish to pub.dev as beta
  - Tag release on GitHub
  - Write release notes
  - Announce in Flutter community

- [ ] **Beta Testing**
  - Test in real projects
  - Gather feedback
  - Monitor issues
  - Track false positives

- [ ] **Feedback Integration**
  - Address critical feedback
  - Fix reported bugs
  - Adjust thresholds
  - Improve documentation

- [ ] **Version 0.1.0 Release**
  - Final testing
  - Update documentation
  - Publish stable version
  - Official announcement

### Phase 8 Deliverables

- [ ] Complete documentation suite
- [ ] Polished package ready for pub.dev
- [ ] CI/CD pipeline functional
- [ ] Community infrastructure in place
- [ ] Beta release published
- [ ] Stable 0.1.0 release

### Phase 8 Success Criteria

- Package discoverable on pub.dev
- Documentation is clear and comprehensive
- CI/CD catches regressions
- Community can contribute easily
- Beta feedback addressed
- Ready for wider adoption

---

## Phase 9: Post-Release Iteration & Enhancement

**Priority:** MEDIUM  
**Timeline:** Weeks 21-30 (Ongoing)  
**Dependencies:** Phase 8 complete

### 9.1 Monitoring & Support (Ongoing)

- [ ] **Issue Triage**
  - Daily monitoring of new issues
  - Categorize: bug, enhancement, false positive, question
  - Prioritize critical issues
  - Respond to questions

- [ ] **False Positive Tracking**
  - Create FP tracking spreadsheet
  - Document each reported FP
  - Analyze root cause
  - Track fix timeline

- [ ] **Metrics Collection**
  - Track adoption (pub.dev downloads)
  - Monitor issue volume
  - Measure response time
  - Track rule effectiveness

### 9.2 False Positive Resolution (Weeks 21-24)

- [ ] **FP Resolution Workflow**
  1. Reproduce reported FP
  2. Create minimal test case
  3. Add to regression suite
  4. Adjust rule logic or guards
  5. Verify fix doesn't break existing tests
  6. Release patch version

- [ ] **Heuristic Tuning**
  - Adjust confidence thresholds
  - Refine signal detection
  - Enhance guards
  - Add new guards for common patterns

- [ ] **Documentation Updates**
  - Document known edge cases
  - Add workaround guides
  - Update examples
  - Clarify rule behavior

### 9.3 Performance Optimization (Weeks 25-26)

- [ ] **Profiling**
  - Profile rules on large files
  - Identify bottlenecks
  - Measure memory usage
  - Test on large monorepos

- [ ] **Optimization**
  - Cache expensive computations
  - Optimize AST traversal
  - Reduce redundant checks
  - Improve visitor efficiency

- [ ] **Benchmarking**
  - Establish baseline metrics
  - Track performance over versions
  - Set performance budgets
  - Regular performance testing

### 9.4 Additional Rules (Weeks 27-30)

Based on roadmap and community feedback:

- [ ] **A12: Focus Order Heuristics**
  - Detect visual vs focus order mismatches
  - Heuristic-based detection
  - INFO severity

- [ ] **A13: Single Interactive Role**
  - Detect multiple interactive roles in one widget
  - Check for conflicting semantics
  - WARNING severity

- [ ] **A14: Validation Feedback Accessible**
  - Check form validation patterns
  - Ensure errors are announced
  - Heuristic detection

- [ ] **A15: Custom Gesture Semantics**
  - Detect custom gestures without semantic equivalents
  - Check onTap mapping
  - WARNING severity

- [ ] **A17: Hint Describes Operation**
  - Check hint vs label content
  - Ensure hint describes action
  - INFO severity (heuristic)

- [ ] **A19: Disabled State Handling**
  - Check disabled state communication
  - Avoid redundant label changes
  - INFO severity

- [ ] **A20: Async Announce Once**
  - Detect multiple announcements for same action
  - Check for duplicate announces
  - INFO severity

### Phase 9 Deliverables

- [ ] All reported FPs resolved or documented
- [ ] Performance optimized
- [ ] Additional rules based on feedback
- [ ] Comprehensive regression suite
- [ ] Updated documentation
- [ ] Regular patch releases

### Phase 9 Success Criteria

- < 2% false positive rate reported
- Response time < 48h for issues
- Performance < 30ms per file maintained
- Community actively contributing
- Regular updates and improvements
- High user satisfaction

---

## Phase 10: Advanced Features & Ecosystem Integration

**Priority:** LOW  
**Timeline:** Months 8-12+  
**Dependencies:** Stable 1.0 release

### 10.1 Auto-Fix Support (Months 8-9)

Implement quick fixes for common violations:

- [ ] **A21 Fix: Tooltip Migration**
  ```dart
  // Before
  Tooltip(message: 'Save', child: IconButton(...))
  
  // After
  IconButton(tooltip: 'Save', ...)
  ```

- [ ] **A24 Fix: Add ExcludeSemantics**
  ```dart
  // Before
  Icon(Icons.drag_handle)
  
  // After
  ExcludeSemantics(child: Icon(Icons.drag_handle))
  ```

- [ ] **A01 Fix: Add Tooltip**
  ```dart
  // Before
  IconButton(icon: Icon(Icons.delete), onPressed: ...)
  
  // After
  IconButton(icon: Icon(Icons.delete), tooltip: '___', onPressed: ...)
  ```

- [ ] **Fix Infrastructure**
  - Implement ChangeBuilder usage
  - Test fixes thoroughly
  - Handle edge cases
  - Document fix limitations

### 10.2 IDE Integration (Month 9)

- [ ] **VS Code**
  - Test with Flutter extension
  - Verify quick fix UX
  - Check performance
  - Document setup

- [ ] **Android Studio / IntelliJ**
  - Test integration
  - Verify UI rendering
  - Check navigation
  - Performance validation

- [ ] **Enhanced Diagnostics**
  - Rich error messages
  - Code snippets
  - Fix suggestions
  - Documentation links

### 10.3 Advanced Configuration (Month 10)

- [ ] **Rule Groups**
  ```yaml
  flutter_a11y_lints:
    enabled_groups:
      - core          # Essential rules
      - recommended   # Core + safe heuristics
      - strict        # All rules
  ```

- [ ] **Per-File Overrides**
  ```yaml
  flutter_a11y_lints:
    file_overrides:
      - pattern: "**/generated/**"
        disabled: true
      - pattern: "lib/experimental/**"
        mode: conservative
  ```

- [ ] **Custom Rule Presets**
  - Predefined configurations
  - Team-specific presets
  - Framework-specific presets (Material, Cupertino)
  - Industry presets (healthcare, finance)

### 10.4 Reporting & Analytics (Month 11)

- [ ] **Violation Reports**
  - Generate HTML reports
  - CSV export
  - JSON output
  - Trend analysis

- [ ] **Metrics Dashboard**
  - Accessibility score
  - Rule coverage
  - Progress tracking
  - Team metrics

- [ ] **CI Integration**
  - Fail on critical violations
  - Track improvement
  - Generate reports
  - Comment on PRs

### 10.5 Design System Support (Month 12)

- [ ] **Popular Design Systems**
  - Material Design presets
  - Cupertino presets
  - FluentUI support
  - Custom design system templates

- [ ] **Widget Registration API**
  ```dart
  flutter_a11y_lints:
    custom_widgets:
      AppButton:
        treats_as: MaterialButton
        inherent_semantics: true
      AppListTile:
        treats_as: ListTile
        safe_to_merge: false
  ```

- [ ] **Design System Validation**
  - Validate component library
  - Ensure proper semantics
  - Document requirements
  - Generate reports

### 10.6 Future Exploration

- [ ] **Flutter DevTools Extension**
  - Real-time accessibility inspector
  - Visual semantic tree
  - Fix suggestions in DevTools
  - Screen reader preview

- [ ] **Machine Learning Enhancements**
  - ML-based signal weighting
  - Pattern recognition
  - Personalized thresholds
  - False positive prediction

- [ ] **Cross-File Analysis**
  - Limited scope multi-file checks
  - Component consistency
  - Design pattern validation
  - Global accessibility score

### Phase 10 Deliverables

- [ ] Auto-fix support for common rules
- [ ] Excellent IDE integration
- [ ] Advanced configuration options
- [ ] Reporting tools
- [ ] Design system support
- [ ] Innovation features

### Phase 10 Success Criteria

- Auto-fixes work reliably
- IDE integration is seamless
- Advanced features add value
- Design systems well-supported
- Innovation drives ecosystem forward
- Tool is industry-standard

---

## Risk Management

### Critical Risks

#### 1. False Positive Rate Too High
**Impact:** HIGH  
**Likelihood:** MEDIUM  
**Mitigation:**
- Extensive testing with real codebases
- Conservative defaults
- Easy suppression mechanisms
- Heuristic rules as INFO only
- Community feedback loop

#### 2. Performance Issues
**Impact:** HIGH  
**Likelihood:** LOW  
**Mitigation:**
- Performance benchmarking
- Efficient AST traversal
- Caching strategies
- Profiling on large projects
- Performance budgets

#### 3. Low Adoption
**Impact:** MEDIUM  
**Likelihood:** MEDIUM  
**Mitigation:**
- Clear value proposition
- Excellent documentation
- Community engagement
- Blog posts and talks
- Integration with popular tools

#### 4. Maintenance Burden
**Impact:** MEDIUM  
**Likelihood:** MEDIUM  
**Mitigation:**
- Modular architecture
- Comprehensive tests
- Clear contribution guidelines
- Build maintainer community
- Good documentation

### Success Factors

1. **Quality Over Quantity**
   - Focus on high-confidence rules first
   - Low false positive rate
   - Reliable detection

2. **Developer Experience**
   - Clear error messages
   - Easy configuration
   - Simple suppression
   - Good documentation

3. **Community Building**
   - Responsive to issues
   - Welcome contributions
   - Clear communication
   - Regular updates

4. **Continuous Improvement**
   - Feedback-driven development
   - Regular updates
   - Performance optimization
   - Feature enhancements

---

## Metrics & Success Criteria

### Technical Metrics

- **Test Coverage:** > 90%
- **Performance:** < 30ms per file
- **False Positive Rate:** < 2% reported
- **Rule Quality:** All high-confidence rules at WARNING

### Adoption Metrics

- **Pub.dev Points:** > 130 within 6 months
- **Downloads:** > 1,000/month within 6 months
- **GitHub Stars:** > 100 within 6 months
- **Active Issues:** Healthy issue activity

### Community Metrics

- **Issue Response Time:** < 48 hours
- **PR Review Time:** < 1 week
- **Contributors:** > 10 contributors
- **Documentation:** Comprehensive and clear

### Impact Metrics

- **Apps Using Tool:** > 50 apps
- **Accessibility Improvements:** Measurable improvements reported
- **Industry Recognition:** Conference talks, blog posts
- **Integration:** Used in CI/CD pipelines

---

## Timeline Summary

### Completed (Weeks 1-4)
✅ Phase 1: Foundation  
✅ Phase 2: Initial Rules (9 rules)

### Current Focus (Weeks 5-6)
🚧 Phase 3: Testing & Quality Enhancement

### Near Term (Weeks 7-11)
📅 Phase 4: Utilities & Configuration  
📅 Phase 5: Additional High-Confidence Rules

### Medium Term (Weeks 12-17)
📅 Phase 6: Heuristic Engine  
📅 Phase 7: Heuristic Rules

### Production Release (Weeks 18-20)
📅 Phase 8: Release Preparation

### Long Term (Weeks 21-30+)
📅 Phase 9: Post-Release Iteration  
📅 Phase 10: Advanced Features

---

## Conclusion

This implementation plan provides a comprehensive roadmap from the current state (foundation with 9 rules) to a production-ready, industry-standard Flutter accessibility linter.

### Key Principles

1. **Quality First:** High-confidence rules before expanding to heuristics
2. **Test-Driven:** Comprehensive testing prevents regressions
3. **Developer-Friendly:** Easy to use, configure, and suppress
4. **Community-Focused:** Open, responsive, and welcoming
5. **Continuously Improving:** Regular updates based on feedback

### Next Steps

1. **Immediate:** Complete Phase 3 (Testing & Quality)
2. **Week 7:** Begin Phase 4 (Configuration System)
3. **Week 9:** Start Phase 5 (Additional Rules)
4. **Week 12:** Build Heuristic Engine (Phase 6)
5. **Week 18:** Prepare for Beta Release

### Long-Term Vision

Create the de facto Flutter accessibility linting tool that:
- Makes accessibility easy and automatic
- Integrates seamlessly into development workflows
- Evolves with the Flutter ecosystem
- Builds a strong community of contributors
- Has measurable impact on app accessibility

---

**Document Status:** Living Document  
**Review Frequency:** Monthly  
**Owner:** Project Maintainers  
**Last Review:** December 1, 2025
