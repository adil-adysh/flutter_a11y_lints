# flutter_a11y_lints – Semantic IR Design Spec v2.5

## 0. Goal & Philosophy

**Goal:**
Build a **static, compiler-style semantic tree** that closely approximates Flutter’s runtime `Semantics` tree, and run **high-confidence accessibility rules** (plus optional heuristics) on top of it.

**Key principles:**

* AST-only, no runtime.
* Never guess UI appearance.
* **False positives are worse than false negatives.**
* Semantics first: rules operate on **Semantic IR**, not raw AST.
* Heuristics are opt-in, INFO-level, and must be conservative.

**Pipeline (top-level):**

1. **Resolution:** Dart AST + `ResolvedUnitResult` + constant evaluation.
2. **Widget Ingestion:** AST → `WidgetNode` (including if/else/loops and slots).
3. **Semantic Synthesis:** `WidgetNode` → `SemanticNode` using:

   * Generated `KnownSemantics` table
   * Custom-widget `SemanticSummary`
   * Semantics/Merge/Exclude/Block/Indexed widgets
4. **Tree Annotation:** Build `SemanticTree`:

   * Assign IDs, parents, sibling indices, depth
   * Compute reading / focus order
   * Assign layout groups & list item groups
   * Build both **physical** and **accessibility-focus** views
5. **Validation:** Run rules on `SemanticTree` (core rules + optional heuristics).

---

## 1. Core Data Models

### 1.1 `KnownSemantics` – Generated Source of Truth

Generated from a JSON catalogue extracted via runtime semantics probing.

Purpose: describe **capabilities and structural semantics** of core Flutter widgets (NOT instance-specific labels).

```dart
class KnownSemantics {
  final SemanticRole role;          // button, image, textField, etc.
  final ControlKind controlKind;    // more specific (iconButton, slider, etc.)

  // Interaction flags
  final bool isFocusable;
  final bool isEnabledByDefault;
  final bool hasTap;
  final bool hasLongPress;
  final bool hasIncrease;
  final bool hasDecrease;
  final bool hasScroll;
  final bool hasDismiss;
  final bool isToggled;
  final bool isChecked;
  final bool isInMutuallyExclusiveGroup;

  // Semantics behavior
  final bool mergesDescendants;         // explicit semantics merging behavior
  final bool implicitlyMergesSemantics; // like Material Buttons that collapse children semantics
  final bool excludesDescendants;       // for widgets like ExcludeSemantics (usually false here)
  final bool blocksBehind;              // for BlockSemantics-like behavior
  final bool isPureContainer;           // Row/Column/Wrappers (layout only)

  // **NEW** – slot order
  /// Explicit order in which slotted children are visited by semantics.
  /// E.g. ListTile: ['leading', 'title', 'subtitle', 'trailing'].
  final List<String> slotTraversalOrder;

  const KnownSemantics({
    required this.role,
    required this.controlKind,
    required this.isFocusable,
    required this.isEnabledByDefault,
    required this.hasTap,
    required this.hasLongPress,
    required this.hasIncrease,
    required this.hasDecrease,
    required this.hasScroll,
    required this.hasDismiss,
    required this.isToggled,
    required this.isChecked,
    required this.isInMutuallyExclusiveGroup,
    required this.mergesDescendants,
    required this.implicitlyMergesSemantics,
    required this.excludesDescendants,
    required this.blocksBehind,
    required this.isPureContainer,
    required this.slotTraversalOrder,
  });
}

final Map<String, KnownSemantics> knownSemanticsByWidget = {
  // Populated via codegen from JSON
};
```

---

### 1.2 `WidgetNode` – AST → Widget Structure

Represents a widget instance in a build method, with control-flow awareness.

```dart
enum WidgetNodeType { standard, conditionalBranch, loop }

class WidgetNode {
  final String widgetType;                 // "IconButton", "Semantics", "MyWidget"
  final AstNode astNode;                   // for locations

  // Constructor args
  final Map<String, Expression> props;     // {"tooltip": ..., "onTap": ...}

  // Named child slots: child/title/leading/trailing/etc.
  final Map<String, WidgetNode?> slots;

  // Positional children: from `children:` list
  final List<WidgetNode> children;

  // Control-flow classification
  final WidgetNodeType nodeType;

  /// If this node came from an unresolved `if`/`else`, this indicates
  /// which logical branch it belongs to.
  final int? branchId;   // nodes with different branchIds under same conditional are mutually exclusive

  WidgetNode({
    required this.widgetType,
    required this.astNode,
    required this.props,
    required this.slots,
    required this.children,
    this.nodeType = WidgetNodeType.standard,
    this.branchId,
  });
}
```

**Control-flow rules:**

* For `if (cond) A else B`:

  * If `cond` const-evaluates → only keep active branch.
  * Else:

    * Build both A and B as children with different `branchId`s.
    * Wrap them in a `WidgetNode` of type `conditionalBranch` (or you propagate `branchId` down and store branch info separately).

This **prevents heuristics** from accidentally using siblings from mutually exclusive branches as “nearby labels”.

---

### 1.3 Semantic enums

```dart
enum SemanticRole {
  button,
  image,
  switchRole,
  checkbox,
  radio,
  slider,
  textField,
  staticText,
  header,
  group,
  unknown,
}

enum ControlKind {
  none,
  iconButton,
  elevatedButton,
  textButton,
  outlinedButton,
  filledButton,
  floatingActionButton,
  listTile,
  switchControl,
  checkboxControl,
  radioControl,
  sliderControl,
  textFieldControl,
  custom,
}

enum LabelGuarantee {
  none,               // might truly be unlabeled
  hasLabelButDynamic, // always has some label, content unknown
  hasStaticLabel,     // statically known string label
}

enum LabelSource {
  none,
  tooltip,
  textChild,
  semanticsWidget,
  inputDecoration,
  customWidgetParameter,
  valueToString,
  other,
}
```

---

### 1.4 `SemanticSummary` – Custom Widget Type Summary

Semantic summary **per custom widget class**, cached globally.

```dart
class SemanticSummary {
  final String widgetType;           // "SettingsToggleTile"
  final SemanticRole role;
  final ControlKind controlKind;

  final bool isCompositeControl;
  final bool isFocusable;
  final bool hasTap;
  final bool hasLongPress;
  final bool hasIncrease;
  final bool hasDecrease;
  final bool isToggled;
  final bool isChecked;
  final bool mergesDescendants;
  final bool excludesDescendants;
  final bool blocksBehind;

  final LabelGuarantee labelGuarantee;
  final LabelSource primaryLabelSource;

  /// Transparent wrappers: semantics = child's semantics (e.g. custom Padding).
  final bool isSemanticallyTransparent;

  const SemanticSummary({
    required this.widgetType,
    required this.role,
    required this.controlKind,
    required this.isCompositeControl,
    required this.isFocusable,
    required this.hasTap,
    required this.hasLongPress,
    required this.hasIncrease,
    required this.hasDecrease,
    required this.isToggled,
    required this.isChecked,
    required this.mergesDescendants,
    required this.excludesDescendants,
    required this.blocksBehind,
    required this.labelGuarantee,
    required this.primaryLabelSource,
    required this.isSemanticallyTransparent,
  });

  factory SemanticSummary.unknown(String widgetType) => SemanticSummary(
        widgetType: widgetType,
        role: SemanticRole.unknown,
        controlKind: ControlKind.custom,
        isCompositeControl: false,
        isFocusable: false,
        hasTap: false,
        hasLongPress: false,
        hasIncrease: false,
        hasDecrease: false,
        isToggled: false,
        isChecked: false,
        mergesDescendants: false,
        excludesDescendants: false,
        blocksBehind: false,
        labelGuarantee: LabelGuarantee.none,
        primaryLabelSource: LabelSource.none,
        isSemanticallyTransparent: false,
      );
}
```

---

### 1.5 `SemanticNode` – Final IR Node

Represents **one node** in the static approximation of the semantics tree.

```dart
class SemanticNode {
  // Identity / source
  final int id;                // filled in post-pass
  final String widgetType;     // originating widget type
  final Uri fileUri;
  final int offset;
  final int length;

  // Link to custom type-level semantics (if from a summary)
  final SemanticSummary? summarySource;

  // Tree relationships
  final int? parentId;         // null for root
  final int siblingIndex;      // position among parent's children
  final int depth;             // 0 = root

  // Reading / focus order
  final int preOrderIndex;     // physical DFS order
  final int? focusOrderIndex;  // order among focusable/accessibility nodes

  // Grouping context (for heuristics)
  final int? layoutGroupId;    // Row/Column group
  final int? listItemGroupId;  // list row or item group
  final bool isPrimaryInGroup;

  // Semantic role / type
  final SemanticRole role;
  final ControlKind controlKind;

  // State & capabilities
  final bool isFocusable;
  final bool isEnabled;
  final bool isToggled;
  final bool isChecked;
  final bool isInMutuallyExclusiveGroup;

  // Actions
  final bool hasTap;
  final bool hasLongPress;
  final bool hasIncrease;
  final bool hasDecrease;
  final bool hasScroll;
  final bool hasDismiss;

  // Labeling (explicit vs aggregated)
  final String? label;              // explicit label set on this node (e.g. Semantics.label, TextField.labelText)
  final String? tooltip;            // toolbar/tooltip text if resolved
  final String? explicitChildLabel; // label aggregated from merged children (e.g. MergeSemantics / ListTile)

  final LabelGuarantee labelGuarantee;
  final LabelSource labelSource;    // where label/explicitChildLabel came from
  final String? value;              // slider value, text field value (known static)

  // Merge/exclude/block semantics
  final bool isSemanticBoundary;    // Semantics/MergeSemantics or equivalent
  final bool mergesDescendants;     // merges children semantics into this node
  final bool excludesDescendants;   // ExcludeSemantics behavior
  final bool blocksBehind;          // BlockSemantics behavior
  final int? semanticIndex;         // IndexedSemantics index, if known

  final bool isCompositeControl;    // composite (text + control) semantics
  final bool isPureContainer;       // layout-only nodes

  // Children in semantics tree (physical)
  final List<SemanticNode> children;

  const SemanticNode({
    required this.id,
    required this.widgetType,
    required this.fileUri,
    required this.offset,
    required this.length,
    required this.summarySource,
    required this.parentId,
    required this.siblingIndex,
    required this.depth,
    required this.preOrderIndex,
    required this.focusOrderIndex,
    required this.layoutGroupId,
    required this.listItemGroupId,
    required this.isPrimaryInGroup,
    required this.role,
    required this.controlKind,
    required this.isFocusable,
    required this.isEnabled,
    required this.isToggled,
    required this.isChecked,
    required this.isInMutuallyExclusiveGroup,
    required this.hasTap,
    required this.hasLongPress,
    required this.hasIncrease,
    required this.hasDecrease,
    required this.hasScroll,
    required this.hasDismiss,
    required this.label,
    required this.tooltip,
    required this.explicitChildLabel,
    required this.labelGuarantee,
    required this.labelSource,
    required this.value,
    required this.isSemanticBoundary,
    required this.mergesDescendants,
    required this.excludesDescendants,
    required this.blocksBehind,
    required this.semanticIndex,
    required this.isCompositeControl,
    required this.isPureContainer,
    required this.children,
  });

  /// Effective label the user/screen reader perceives
  String? get effectiveLabel {
    final pieces = <String>[];
    if (label != null && label!.isNotEmpty) pieces.add(label!);
    if (tooltip != null && tooltip!.isNotEmpty) pieces.add(tooltip!);
    if (explicitChildLabel != null && explicitChildLabel!.isNotEmpty) {
      pieces.add(explicitChildLabel!);
    }
    if (pieces.isEmpty) return null;
    return pieces.join('\n');
  }

  SemanticNode copyWith({ /* standard copyWith */ }) => /* ... */;
}
```

Important: `children` includes **physical descendants**, even under `MergeSemantics`.
But rules that simulate screen reader focus may use a separate list that skips children of merged/excluded nodes.

---

### 1.6 Context Objects

#### GlobalSemanticContext

Shared across analysis:

```dart
class GlobalSemanticContext {
  final Map<String, KnownSemantics> knownSemanticsByWidget;
  final TypeProvider typeProvider;
  final ConstantEvaluator constEval;

  final Map<String, SemanticSummary> _summaryCache = {};
  final Set<String> _summaryInProgress = {}; // cycle guard

  GlobalSemanticContext({
    required this.knownSemanticsByWidget,
    required this.typeProvider,
    required this.constEval,
  });

  SemanticSummary? getOrComputeSummary(ClassElement widgetClass) {
    final name = widgetClass.name;
    final cached = _summaryCache[name];
    if (cached != null) return cached;

    if (_summaryInProgress.contains(name)) {
      // Recursive widget graph: degrade to unknown.
      return SemanticSummary.unknown(name);
    }

    _summaryInProgress.add(name);
    try {
      final summary = _computeSummary(widgetClass);
      if (summary != null) _summaryCache[name] = summary;
      return summary;
    } finally {
      _summaryInProgress.remove(name);
    }
  }

  SemanticSummary? _computeSummary(ClassElement widgetClass) {
    // 1. Find build()
    // 2. Build WidgetNode tree for its return expression.
    // 3. Build internal SemanticNode tree for implementation.
    // 4. Summarize:
    //    - role, controlKind
    //    - hasTap, isFocusable, isToggled...
    //    - mergesDescendants, excludesDescendants, blocksBehind
    //    - labelGuarantee + primaryLabelSource
    //    - isCompositeControl, isSemanticallyTransparent
    return null; // Implementation detail.
  }

  // Const eval helpers
  String? evalString(Expression? expr) => constEval.tryEvalString(expr);
  bool? evalBool(Expression? expr) => constEval.tryEvalBool(expr);
  int? evalInt(Expression? expr) => constEval.tryEvalInt(expr);
}
```

#### BuildSemanticContext

Per semantic-tree build:

```dart
class BuildSemanticContext {
  final GlobalSemanticContext global;
  final bool enableHeuristics;

  int excludeDepth = 0;
  int blockDepth = 0;

  BuildSemanticContext({
    required this.global,
    required this.enableHeuristics,
  });

  bool get isWithinExcludedSubtree => excludeDepth > 0;
  bool get isWithinBlockedOverlay => blockDepth > 0;

  Map<String, KnownSemantics> get knownSemanticsByWidget =>
      global.knownSemanticsByWidget;

  SemanticSummary? summaryForClass(ClassElement klass) =>
      global.getOrComputeSummary(klass);

  String? evalString(Expression? expr) => global.evalString(expr);
  bool? evalBool(Expression? expr) => global.evalBool(expr);
  int? evalInt(Expression? expr) => global.evalInt(expr);
}
```

---

### 1.7 `SemanticTree` & `SemanticNeighborhood`

#### SemanticTree

Wraps a built semantics tree with indexing & views.

```dart
class SemanticTree {
  final SemanticNode root;

  /// All nodes in physical semantics tree (including merged children).
  final List<SemanticNode> physicalNodes;

  /// Nodes that represent actual accessibility focus targets:
  /// - focusable nodes
  /// - skipping children under merged/excluded boundaries.
  final List<SemanticNode> accessibilityFocusNodes;

  /// Quick lookup by ID.
  final Map<int, SemanticNode> byId;

  SemanticTree._({
    required this.root,
    required this.physicalNodes,
    required this.accessibilityFocusNodes,
    required this.byId,
  });

  static SemanticTree fromRoot(SemanticNode rawRoot) {
    final byId = <int, SemanticNode>{};
    final physical = <SemanticNode>[];
    final focusables = <SemanticNode>[];

    int nextId = 0;
    int nextPre = 0;
    int nextFocus = 0;

    SemanticNode visit(
      SemanticNode node, {
      int? parentId,
      int depth = 0,
      int siblingIndex = 0,
    }) {
      final id = nextId++;
      final preIndex = nextPre++;

      var annotated = node.copyWith(
        id: id,
        parentId: parentId,
        depth: depth,
        siblingIndex: siblingIndex,
        preOrderIndex: preIndex,
      );

      if (annotated.isFocusable) {
        annotated = annotated.copyWith(focusOrderIndex: nextFocus++);
      }

      byId[id] = annotated;
      physical.add(annotated);

      final newChildren = <SemanticNode>[];
      for (var i = 0; i < node.children.length; i++) {
        final child = visit(
          node.children[i],
          parentId: id,
          depth: depth + 1,
          siblingIndex: i,
        );
        newChildren.add(child);
      }

      annotated = annotated.copyWith(children: newChildren);
      byId[id] = annotated;
      physical[preIndex] = annotated;
      return annotated;
    }

    final annotatedRoot = visit(rawRoot);

    // Build accessibilityFocusNodes by walking physical tree and skipping
    // children under mergesDescendants/excludesDescendants boundaries.
    final accFocus = <SemanticNode>[];
    void collectAccessible(SemanticNode node) {
      if (node.isFocusable) accFocus.add(node);
      if (node.mergesDescendants || node.excludesDescendants) {
        // Children are not individually focus targets.
        return;
      }
      for (final child in node.children) {
        collectAccessible(child);
      }
    }
    collectAccessible(annotatedRoot);

    // TODO: extra pass to assign layoutGroupId/listItemGroupId.

    return SemanticTree._(
      root: annotatedRoot,
      physicalNodes: physical,
      accessibilityFocusNodes: accFocus,
      byId: byId,
    );
  }
}
```

#### SemanticNeighborhood

Helper for “nearby nodes” queries.

```dart
class SemanticNeighborhood {
  final SemanticTree tree;
  SemanticNeighborhood(this.tree);

  SemanticNode? parentOf(SemanticNode node) =>
      node.parentId == null ? null : tree.byId[node.parentId!] ;

  List<SemanticNode> siblings(SemanticNode node) {
    final parent = parentOf(node);
    if (parent == null) return [node];
    return parent.children;
  }

  SemanticNode? previousInReadingOrder(SemanticNode node) {
    final i = node.preOrderIndex;
    if (i <= 0) return null;
    return tree.physicalNodes[i - 1];
  }

  SemanticNode? nextInReadingOrder(SemanticNode node) {
    final i = node.preOrderIndex;
    if (i + 1 >= tree.physicalNodes.length) return null;
    return tree.physicalNodes[i + 1];
  }

  Iterable<SemanticNode> neighborsInReadingOrder(
    SemanticNode node, {
    int radius = 3,
  }) sync* {
    final i = node.preOrderIndex;
    for (var d = -radius; d <= radius; d++) {
      if (d == 0) continue;
      final j = i + d;
      if (j < 0 || j >= tree.physicalNodes.length) continue;
      yield tree.physicalNodes[j];
    }
  }

  Iterable<SemanticNode> siblingsBefore(SemanticNode node) sync* {
    final parent = parentOf(node);
    if (parent == null) return;
    for (var i = 0; i < node.siblingIndex; i++) {
      yield parent.children[i];
    }
  }

  Iterable<SemanticNode> siblingsAfter(SemanticNode node) sync* {
    final parent = parentOf(node);
    if (parent == null) return;
    for (var i = node.siblingIndex + 1; i < parent.children.length; i++) {
      yield parent.children[i];
    }
  }

  Iterable<SemanticNode> sameLayoutGroup(SemanticNode node) sync* {
    final id = node.layoutGroupId;
    if (id == null) return;
    for (final n in tree.physicalNodes) {
      if (n.layoutGroupId == id) yield n;
    }
  }

  Iterable<SemanticNode> sameListItemGroup(SemanticNode node) sync* {
    final id = node.listItemGroupId;
    if (id == null) return;
    for (final n in tree.physicalNodes) {
      if (n.listItemGroupId == id) yield n;
    }
  }

  /// Implemented by propagating branchId from WidgetNode to SemanticNode.
  bool areMutuallyExclusive(SemanticNode a, SemanticNode b) {
    // We’d store branchId on SemanticNode as well when building from WidgetNode.
    // Then: if they share an ancestor conditional and have different branchIds -> true.
    return false; // placeholder
  }
}
```

Heuristics that look for nearby labels should **filter out** mutually exclusive siblings using `areMutuallyExclusive`.

---

## 2. Build Pipeline – Algorithms

### Phase 1 – AST → WidgetNode

For each relevant `build()`:

1. Use `ResolvedUnitResult`.

2. Locate the `return` expression or arrow body.

3. Traverse expressions to build `WidgetNode`:

   * Constructor calls whose type is assignable to `Widget`.
   * Fill `props` from named arguments.
   * `child:` and special slots (title, leading, trailing, subtitle) as `slots`.
   * `children:` list literal → `children`.

4. For `if` / `?:` / `for` inside `children` or slot expressions:

   * Try `global.constEval` on condition.
   * If condition resolves:

     * Keep only active branch.
   * If not:

     * Build both branches, assign different `branchId` values, mark parent `nodeType = conditionalBranch`.

---

### Phase 2 – WidgetNode → SemanticNode (core build)

Entry:

```dart
SemanticNode? buildSemanticTreeFromRoot(
  WidgetNode rootWidget,
  GlobalSemanticContext global,
  {bool enableHeuristics = false},
) {
  final ctx = BuildSemanticContext(global: global, enableHeuristics: enableHeuristics);
  final rawRoot = _buildSemanticNode(rootWidget, ctx);
  if (rawRoot == null) return null;
  return rawRoot;
}
```

#### `_buildSemanticNode(widget, ctx)`

1. **Special semantics widgets first**:

   * `ExcludeSemantics`:

     * `ctx.excludeDepth++` while building child node.
     * All IR nodes built under this are “hidden” from accessibilityFocusNodes.
     * We typically don’t create an extra node for ExcludeSemantics in the accessibility view; instead we use `excludesDescendants` or context info to help A07/A05.

   * `MergeSemantics`:

     * Build child/children → `List<SemanticNode> children`.
     * Aggregate labels/actions → `explicitChildLabel`, `aggregatedGuarantee`.
     * Create parent node with:

       * `mergesDescendants = true`
       * `isSemanticBoundary = true`
       * `explicitChildLabel` + `labelGuarantee`.
       * Keep `children` for heuristics but children won’t be in `accessibilityFocusNodes`.

   * `BlockSemantics`:

     * `ctx.blockDepth++` while building child.
     * Node gets `blocksBehind = true`, `isSemanticBoundary = true`.

   * `IndexedSemantics`:

     * Build child, attach `semanticIndex` from `index` prop if const-int.

   * `Semantics`:

     * Build child (if any).
     * Start from child semantics or default group semantics.
     * Apply overrides (`label`, `button`, `toggled`, etc.) using const eval:

       * `label` → `label` / `LabelGuarantee` / `LabelSource.semanticsWidget`.
       * `button: true` → `role = button`.
       * `toggled:` etc. → adjust toggled/checked flags.
     * `isSemanticBoundary = true`.

2. **Known built-in widgets**:

   * Look up `KnownSemantics` by `widgetType`.

   * Build semantic children using `slotTraversalOrder` plus positional children:

     ```dart
     List<SemanticNode> _buildChildren(WidgetNode wNode, BuildSemanticContext ctx) {
       final result = <SemanticNode>[];

       final known = ctx.knownSemanticsByWidget[wNode.widgetType];
       final slotOrder = known?.slotTraversalOrder ?? wNode.slots.keys.toList();

       for (final slotName in slotOrder) {
         final slotNode = wNode.slots[slotName];
         if (slotNode != null) {
           final built = _buildSemanticNode(slotNode, ctx);
           if (built != null) result.add(built);
         }
       }

       for (final child in wNode.children) {
         final built = _buildSemanticNode(child, ctx);
         if (built != null) result.add(built);
       }

       return result;
     }
     ```

   * Seed base node from `KnownSemantics`:

     * `role`, `controlKind`, `isFocusable`, `hasTap`, `isToggled`, etc.

   * Widget-specific refinement functions:

     * `IconButton` → use `tooltip` prop (if const string) to set `tooltip`, `label`, `LabelGuarantee.hasStaticLabel`, `LabelSource.tooltip`.
     * `ListTile` → use `onTap`, text children (`title`, `subtitle`), trailing `Switch`/`Checkbox`/`Radio` to:

       * Derive `role` = button if `onTap != null`.
       * Derive `isCompositeControl = true` if text + control present.
       * Build `explicitChildLabel` = merged text children.
     * `TextField` / `TextFormField` → use `decoration.labelText` / `hintText` for label.
     * `Image` → `semanticLabel` if const string.

   * If `known.implicitlyMergesSemantics == true`, behave like a merge:

     * Use children to build `explicitChildLabel` / `aggregatedGuarantee`.
     * Set `mergesDescendants = true`, `isSemanticBoundary = true`.

3. **Custom widgets**:

   * Resolve class element for `widget.widgetType`. If it’s a custom widget with a build() method:

     * Get `summary` via `ctx.summaryForClass(classElement)` from `GlobalSemanticContext`.
   * If `summary.isSemanticallyTransparent`:

     * Find a single child from constructor parameters and delegate `_buildSemanticNode(child, ctx)`.
   * Else:

     * Create a `SemanticNode` from the summary:

       * `role`, `controlKind`, `isFocusable`, `hasTap`, `isToggled`, `mergesDescendants`, etc.
       * `summary.labelGuarantee` and `primaryLabelSource`.
       * `summarySource = summary`.
     * Then specialize label per instance:

       * If the summary says label comes from `label`/`description` parameters, and those args are const strings, build static `label` / `explicitChildLabel`.
       * Else keep `labelGuarantee = hasLabelButDynamic` with `label = null`.

4. **Unknown widgets**:

   * Build children.
   * Fallback node:

     * `role = group`, `controlKind = none`, `isFocusable = false`, `hasTap = false`.
     * `isPureContainer = true` if it clearly behaves as layout.

Output: a **raw semantics tree** (SemanticNode root) with children, but without IDs, preOrderIndex, etc.

---

### Phase 3 – Build `SemanticTree` & layout/list groups

Use `SemanticTree.fromRoot` to annotate:

* IDs, parents, depth, siblingIndex.
* preOrderIndex, focusOrderIndex.
* Build `physicalNodes` and `accessibilityFocusNodes`.

Then assign:

* `layoutGroupId`:

  * For nodes corresponding to layout containers (Row/Column/Wrap/isPureContainer), assign a unique group ID and propagate it to their child nodes.
* `listItemGroupId`:

  * For nodes under `IndexedSemantics` or known “list item” patterns (e.g. ListTile inside ListView.builder), assign an item group ID.

---

### Phase 4 – Rules

Rules use:

* For high-confidence rules (A01, A05, A06, A07, A21, etc.) → `SemanticTree.accessibilityFocusNodes` plus node-local info.
* For heuristics → `SemanticTree.physicalNodes` + `SemanticNeighborhood`.

Example high-confidence rule A01:

```dart
void runA01(SemanticTree tree, LintReporter reporter) {
  for (final node in tree.accessibilityFocusNodes) {
    final isInteractive =
        node.hasTap || node.isToggled || node.isChecked || node.hasIncrease || node.hasDecrease;

    if (!isInteractive) continue;

    final isNonTextControl =
        node.role == SemanticRole.button ||
        node.role == SemanticRole.switchRole ||
        node.role == SemanticRole.checkbox ||
        node.role == SemanticRole.radio ||
        node.role == SemanticRole.slider;

    if (!isNonTextControl) continue;

    final unlabeled =
        node.effectiveLabel == null &&
        node.labelGuarantee == LabelGuarantee.none;

    if (unlabeled) {
      reporter.report(
        code: 'A01_UNLABELED_INTERACTIVE',
        offset: node.offset,
        length: node.length,
        message: 'Interactive element ${node.widgetType} has no accessible label.',
      );
    }
  }
}
```

Example heuristic (INFO) using neighborhood:

```dart
void runH_LabelFromSiblingText(SemanticTree tree, LintReporter reporter) {
  final nb = SemanticNeighborhood(tree);

  for (final node in tree.physicalNodes) {
    final isIconish =
        node.controlKind == ControlKind.iconButton &&
        node.hasTap &&
        node.effectiveLabel == null &&
        node.labelGuarantee == LabelGuarantee.none;

    if (!isIconish) continue;

    final group = nb.sameLayoutGroup(node).toList();
    if (group.isEmpty) continue;

    final labelCandidates = group.where((n) =>
        n.role == SemanticRole.staticText &&
        n.effectiveLabel != null &&
        n.preOrderIndex > node.preOrderIndex &&
        n.preOrderIndex - node.preOrderIndex <= 3);

    if (labelCandidates.isEmpty) continue;

    final candidate = labelCandidates.first;
    reporter.reportInfo(
      code: 'H_LABEL_FROM_SIBLING_TEXT',
      offset: node.offset,
      length: node.length,
      message:
          'Icon-like control has no semantic label, but nearby text '
          '("${candidate.effectiveLabel}") may be intended as its label. '
          'Prefer tooltip or Semantics.',
    );
  }
}
```
