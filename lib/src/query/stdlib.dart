import '../facts/fact_store.dart';
import '../facts/model/role_action_facts.dart';
import 'ast.dart';

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
    'isDefinitelyEnabled', 'isDefinitelyFocusable', 'isDefinitelyExposed',
    'isDefinitelyIncludedInSemantics', 'isDefinitelyUnlabeled',
    'isDefinitelyEffectivelyUnlabeled', 'hasAccessibleLabel', 'hasStaticLabel',
    'hasTapAction', 'hasLongPressAction', 'mergesDescendants',
    'excludesDescendants', 'hasImageContent', 'isKnownDecorativeAsset',
    'isNetworkOrFileImage', 'isDefinitelyExcludedFromSemantics',
    'isDefinitelyNotExcludedFromSemantics', 'hasExplicitSemanticsLabel',
    'hasStaticExplicitSemanticsLabel', 'hasExplicitSemanticsButtonRole',
    'isDefinitelyExcludingDescendants', 'isDefinitelyNotExcludingDescendants',
    'createsSemanticContainer', 'requiresExplicitChildNodes',
    'replacesDescendantSemantics', 'blocksSemanticUserActions',
  };
  static const relationshipMembers = {
    'getParent',
    'getAChild',
    'getAnAncestor',
    'getADescendant',
    'getASibling',
    'getSlot'
  };

  /// No Boolean member is total over unresolved widgets and dynamic state.
  /// Conservative rules must use positive definite-state predicates rather
  /// than deriving absence by negation.
  static bool isPartial(String member) => booleanMembers.contains(member);
  static FaqlType? memberType(String member) =>
      booleanMembers.contains(member)
          ? FaqlType.boolean
          : relationshipMembers.contains(member)
              ? FaqlType.node
              : member == 'getWidgetType'
                  ? FaqlType.string
                  : null;
  static bool validArguments(String member, List<LiteralAst> arguments) =>
      member == 'getSlot'
          ? arguments.length == 1 && arguments.single.value is String
          : arguments.isEmpty;
  static bool matchesView(String view, FactNode node, FactStoreView facts) {
    final typed = facts.typedFactsFor(node.id);
    return switch (view) {
      'SemanticNode' => true,
      'InteractiveControl' =>
        typed?.action(ActionKind.tap)?.availability ==
                ActionAvailability.present ||
            typed?.action(ActionKind.longPress)?.availability ==
                ActionAvailability.present,
      'MaterialButtonControl' => const {
          ControlClassification.iconButton,
          ControlClassification.elevatedButton,
          ControlClassification.textButton,
          ControlClassification.filledButton,
          ControlClassification.outlinedButton,
          ControlClassification.floatingActionButton,
        }.contains(typed?.role?.control),
      'ImageNode' =>
        typed?.image != null ||
            node.widgetType == 'Image' ||
            node.widgetType == 'CircleAvatar',
      'SemanticsNode' => node.widgetType == 'Semantics',
      'MergeSemanticsNode' => node.widgetType == 'MergeSemantics',
      'ListTileNode' => node.widgetType.endsWith('ListTile'),
      _ => false,
    };
  }
}
