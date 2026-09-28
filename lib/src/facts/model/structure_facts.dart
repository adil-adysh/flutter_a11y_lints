import 'evidence.dart';

/// A node in the source-derived widget graph. It deliberately has no implied
/// accessibility-tree parentage.
class SourceWidgetNode {
  const SourceWidgetNode({
    required this.id,
    required this.widgetType,
    required this.evidence,
  });

  final int id;
  final String widgetType;
  final FactEvidence evidence;
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
  });

  final int id;
  final int compositionNodeId;
  final FactEvidence evidence;
}
