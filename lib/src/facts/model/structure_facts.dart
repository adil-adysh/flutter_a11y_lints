import 'evidence.dart';
import '../fact_store.dart' show BranchPath;

/// A node in the source-derived widget graph. It deliberately has no implied
/// accessibility-tree parentage.
class SourceWidgetNode {
  const SourceWidgetNode({
    required this.id,
    required this.widgetType,
    required this.evidence,
    this.branchPath = const BranchPath([]),
  });

  final int id;
  final String widgetType;
  final FactEvidence evidence;
  final BranchPath branchPath;
}

/// A source-level widget child edge. It is not a semantic or accessibility
/// relationship, even when the same widgets later contribute nodes there.
class SourceWidgetChildEdge {
  const SourceWidgetChildEdge({
    required this.parentId,
    required this.childId,
  });

  final int parentId;
  final int childId;
}

/// A source constructor-slot relationship, such as `ListTile.leading`.
class NamedSlotEdge {
  const NamedSlotEdge({
    required this.parentId,
    required this.name,
    required this.childId,
  });

  final int parentId;
  final String name;
  final int childId;
}

/// A conservative approximation of an emitted accessibility node. Its
/// composition input is explicit so callers never confuse it with a source
/// widget or source slot edge.
class AccessibilityNode {
  const AccessibilityNode({
    required this.id,
    required this.compositionNodeId,
    required this.evidence,
    this.branchPath = const BranchPath([]),
  });

  final int id;
  final int compositionNodeId;
  final FactEvidence evidence;
  final BranchPath branchPath;
}

/// A semantic-composition node synthesized from a source widget or wrapper.
///
/// Its identity is intentionally distinct from [SourceWidgetNode] and
/// [AccessibilityNode], even when the current conservative projection maps
/// them one-to-one.
class SemanticCompositionNode {
  const SemanticCompositionNode({
    required this.id,
    required this.sourceWidgetId,
    required this.evidence,
    this.branchPath = const BranchPath([]),
  });

  final int id;
  final int sourceWidgetId;
  final FactEvidence evidence;
  final BranchPath branchPath;
}

/// A composition contribution edge, rather than a source child edge.
class SemanticCompositionChildEdge {
  const SemanticCompositionChildEdge({
    required this.parentId,
    required this.childId,
  });

  final int parentId;
  final int childId;
}

/// An edge in the conservative accessibility-tree approximation.
class AccessibilityChildEdge {
  const AccessibilityChildEdge({
    required this.parentId,
    required this.childId,
  });

  final int parentId;
  final int childId;
}

/// An explicit accessibility traversal parent/child link. Unlike a source or
/// accessibility-tree edge, this exists only when matching static traversal
/// identifiers prove it.
class TraversalChildEdge {
  const TraversalChildEdge({required this.parentId, required this.childId});

  final int parentId;
  final int childId;
}

/// An explicit `controlsNodes` association resolved through a static target
/// identifier. It does not imply either hierarchy or traversal order.
class ControlsNodeEdge {
  const ControlsNodeEdge({
    required this.controllerId,
    required this.controlledId,
  });

  final int controllerId;
  final int controlledId;
}

/// Immutable projections for the three graph layers used by analysis.
///
/// The lists remain deliberately separate: APIs consuming this model cannot
/// accidentally treat a source edge as an accessibility-tree edge.
class AccessibilityFactGraph {
  const AccessibilityFactGraph({
    this.sourceNodes = const [],
    this.sourceChildren = const [],
    this.slots = const [],
    this.compositionNodes = const [],
    this.compositionChildren = const [],
    this.accessibilityNodes = const [],
    this.accessibilityChildren = const [],
    this.traversalChildren = const [],
    this.controlsNodes = const [],
  });

  final List<SourceWidgetNode> sourceNodes;
  final List<SourceWidgetChildEdge> sourceChildren;
  final List<NamedSlotEdge> slots;
  final List<SemanticCompositionNode> compositionNodes;
  final List<SemanticCompositionChildEdge> compositionChildren;
  final List<AccessibilityNode> accessibilityNodes;
  final List<AccessibilityChildEdge> accessibilityChildren;
  final List<TraversalChildEdge> traversalChildren;
  final List<ControlsNodeEdge> controlsNodes;
}
