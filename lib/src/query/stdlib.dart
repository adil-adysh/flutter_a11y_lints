import '../facts/fact_store.dart';

enum FaqlType { boolean, integer, string, node }

class Faql4StandardLibrary {
  static const views = {
    'SemanticNode',
    'InteractiveControl',
    'MaterialButtonControl',
    'ImageNode',
    'SemanticsNode',
    'MergeSemanticsNode',
    'ListTileNode'
  };
  static const booleanMembers = {
    'isDefinitelyEnabled': 'enabled',
    'isDefinitelyFocusable': 'focusable',
    'isDefinitelyUnlabeled': 'labelState',
    'hasAccessibleLabel': 'labelState',
    'hasStaticLabel': 'labelState',
    'hasTapAction': 'tap',
    'hasLongPressAction': 'longPress',
    'mergesDescendants': 'mergesDescendants',
    'excludesDescendants': 'excludesDescendants'
  };
  static const relationshipMembers = {
    'getParent',
    'getAChild',
    'getAnAncestor',
    'getADescendant',
    'getASibling'
  };

  /// No Boolean member is total over unresolved widgets and dynamic state.
  /// Conservative rules must use positive definite-state predicates rather
  /// than deriving absence by negation.
  static bool isPartial(String member) => booleanMembers.containsKey(member);
  static FaqlType? memberType(String member) =>
      booleanMembers.containsKey(member)
          ? FaqlType.boolean
          : relationshipMembers.contains(member)
              ? FaqlType.node
              : member == 'getWidgetType'
                  ? FaqlType.string
                  : null;
  static bool matchesView(String view, FactNode node, FactStoreView facts) {
    final values = {
      for (final fact in facts.factsFor(node.id)) fact.name: fact.value
    };
    return switch (view) {
      'SemanticNode' => true,
      'InteractiveControl' =>
        values['tap'] == true || values['longPress'] == true,
      'MaterialButtonControl' => const {
          'iconButton',
          'elevatedButton',
          'textButton',
          'filledButton',
          'outlinedButton',
          'floatingActionButton'
        }.contains(values['controlKind']),
      'ImageNode' =>
        node.widgetType == 'Image' || node.widgetType == 'CircleAvatar',
      'SemanticsNode' => node.widgetType == 'Semantics',
      'MergeSemanticsNode' => node.widgetType == 'MergeSemantics',
      'ListTileNode' => node.widgetType.endsWith('ListTile'),
      _ => false,
    };
  }
}
