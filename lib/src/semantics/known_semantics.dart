import 'known_semantics_data.dart';
import 'semantic_node.dart' show LabelSource;

/// ============================================================================
/// SEMANTIC SOURCE HIERARCHY
/// ============================================================================

/// Sealed class representing strategies for extracting semantic data from
/// widget instances. Each source type defines where and how to retrieve
/// a piece of semantic information (label, tooltip, value, etc.).
///
/// The optional [sourceOverride] allows specifying which LabelSource should
/// be used when this source is successfully extracted. This is crucial for
/// preserving data provenance (e.g., marking a tooltip extraction as having
/// LabelSource.tooltip even though it populates the label field).
sealed class SemanticSource {
  const SemanticSource({this.sourceOverride});
  final LabelSource? sourceOverride;
}

/// Extract data from a named argument (e.g., `semanticLabel` in Icon).
class PropSource extends SemanticSource {
  const PropSource(this.name, {LabelSource? sourceOverride})
      : super(sourceOverride: sourceOverride);
  final String name;
}

/// Extract data from a positional argument (e.g., Text('hi') -> index 0).
class PositionalSource extends SemanticSource {
  const PositionalSource(this.index, {LabelSource? sourceOverride})
      : super(sourceOverride: sourceOverride);
  final int index;
}

/// Extract data from a built child widget in a specific slot
/// (e.g., ListTile's `title` slot child).
class SlotSource extends SemanticSource {
  const SlotSource(this.slotName, {LabelSource? sourceOverride})
      : super(sourceOverride: sourceOverride);
  final String slotName;
}

/// ============================================================================
/// SEMANTIC SCHEMA
/// ============================================================================

/// Declarative configuration defining how to extract semantic attributes
/// from a widget instance. Each field is a prioritized list of `SemanticSource`
/// strategies to attempt in order until one succeeds.
///
/// This replaces hardcoded, widget-specific logic with a table-driven approach.
class SemanticSchema {
  const SemanticSchema({
    this.label = const [],
    this.tooltip = const [],
    this.value = const [],
    this.toggled = const [],
    this.isChecked = const [],
  });

  /// Strategies to extract a label (in priority order).
  final List<SemanticSource> label;

  /// Strategies to extract a tooltip.
  final List<SemanticSource> tooltip;

  /// Strategies to extract a value.
  final List<SemanticSource> value;

  /// Strategies to extract toggled state.
  final List<SemanticSource> toggled;

  /// Strategies to extract isChecked state.
  final List<SemanticSource> isChecked;
}

/// ============================================================================
/// SEMANTIC ROLE & CONTROL KIND
/// ============================================================================

/// This file defines the normalized metadata used by the semantic builder to
/// understand built-in Flutter widget semantics. The `KnownSemantics` table is
/// intended to be generated from a JSON catalogue (`data/known_semantics_v2.6.json`)
/// and contains per-widget static behavior useful for building the IR.
///
/// `SemanticRole` provides a coarse-grained role for accessibility
/// reasoning (button/image/textField/etc.).
enum SemanticRole {
  button,
  image,
  switchRole,
  checkbox,
  slider,
  textField,
  staticText,
  header,
  group,
  unknown,
}

/// `ControlKind` is a more specific classification that helps rules distinguish
/// between types of controls that share a role (e.g., `IconButton` vs.
/// `ElevatedButton` both map to `button` role but have different expectations).
enum ControlKind {
  none,
  elevatedButton,
  textButton,
  filledButton,
  outlinedButton,
  iconButton,
  floatingActionButton,
  listTile,
  checkboxControl,
  switchControl,
  sliderControl,
  textFieldControl,
}

/// Static metadata for a widget type. This is read-only and should reflect
/// widget-level behavior that does not depend on instance args (except where
/// explicitly noted in slotTraversalOrder and schema).
class KnownSemantics {
  const KnownSemantics({
    required this.role,
    required this.controlKind,
    required this.isFocusable,
    required this.isEnabledByDefault,
    required this.hasTap,
    required this.hasLongPress,
    required this.hasIncrease,
    required this.hasDecrease,
    required this.isToggled,
    required this.isChecked,
    required this.mergesDescendants,
    required this.implicitlyMergesSemantics,
    required this.excludesDescendants,
    required this.blocksBehind,
    required this.isPureContainer,
    required this.slotTraversalOrder,
    this.schema = const SemanticSchema(),
  });

  final SemanticRole role;
  final ControlKind controlKind;

  final bool isFocusable;
  final bool isEnabledByDefault;
  final bool hasTap;
  final bool hasLongPress;
  final bool hasIncrease;
  final bool hasDecrease;
  final bool isToggled;
  final bool isChecked;

  final bool mergesDescendants;
  final bool implicitlyMergesSemantics;
  final bool excludesDescendants;
  final bool blocksBehind;
  final bool isPureContainer;

  final List<String> slotTraversalOrder;

  /// Declarative schema for extracting semantic attributes from widget instances.
  final SemanticSchema schema;
}

/// Repository that exposes the v2.6 known semantics catalogue.
class KnownSemanticsRepository {
  KnownSemanticsRepository()
      : _byWidget = _loadKnownSemantics(rawKnownSemanticsV26);

  final Map<String, KnownSemantics> _byWidget;

  KnownSemantics? operator [](String widgetType) => _byWidget[widgetType];
}

Map<String, KnownSemantics> _loadKnownSemantics(
  Map<String, Map<String, Object>> raw,
) {
  return raw.map((widgetType, data) {
    KnownSemantics build() {
      return KnownSemantics(
        role: _parseRole(data['role'] as String),
        controlKind: _parseControlKind(data['controlKind'] as String),
        isFocusable: data['isFocusable'] as bool,
        isEnabledByDefault: data['isEnabledByDefault'] as bool,
        hasTap: data['hasTap'] as bool,
        hasLongPress: data['hasLongPress'] as bool,
        hasIncrease: data['hasIncrease'] as bool,
        hasDecrease: data['hasDecrease'] as bool,
        isToggled: data['isToggled'] as bool,
        isChecked: data['isChecked'] as bool,
        mergesDescendants: data['mergesDescendants'] as bool,
        implicitlyMergesSemantics: data['implicitlyMergesSemantics'] as bool,
        excludesDescendants: data['excludesDescendants'] as bool,
        blocksBehind: data['blocksBehind'] as bool,
        isPureContainer: data['isPureContainer'] as bool,
        slotTraversalOrder:
            List<String>.from(data['slotTraversalOrder'] as List),
        schema: _parseSchema(data['schema'] as Map<String, Object>?),
      );
    }

    return MapEntry(widgetType, build());
  });
}

/// Parse semantic schema from raw data map.
SemanticSchema _parseSchema(Map<String, Object>? raw) {
  if (raw == null) return const SemanticSchema();
  return SemanticSchema(
    label: _parseSourceList(raw['label'] as List?),
    tooltip: _parseSourceList(raw['tooltip'] as List?),
    value: _parseSourceList(raw['value'] as List?),
    toggled: _parseSourceList(raw['toggled'] as List?),
    isChecked: _parseSourceList(raw['isChecked'] as List?),
  );
}

/// Parse a list of semantic sources from raw data.
List<SemanticSource> _parseSourceList(List? raw) {
  if (raw == null) return [];
  return raw
      .whereType<Map<String, Object>>()
      .map((Map<String, Object> item) {
        final type = item['type'] as String?;
        final sourceOverride =
            _parseSourceOverride(item['sourceOverride'] as String?);
        switch (type) {
          case 'prop':
            return PropSource(
              item['name'] as String,
              sourceOverride: sourceOverride,
            );
          case 'positional':
            return PositionalSource(
              item['index'] as int,
              sourceOverride: sourceOverride,
            );
          case 'slot':
            return SlotSource(
              item['slotName'] as String,
              sourceOverride: sourceOverride,
            );
          default:
            return null;
        }
      })
      .whereType<SemanticSource>()
      .toList();
}

/// Parse LabelSource override from string representation.
LabelSource? _parseSourceOverride(String? raw) {
  if (raw == null) return null;
  switch (raw) {
    case 'tooltip':
      return LabelSource.tooltip;
    case 'textChild':
      return LabelSource.textChild;
    case 'semanticsWidget':
      return LabelSource.semanticsWidget;
    case 'customWidgetParameter':
      return LabelSource.customWidgetParameter;
    case 'inputDecoration':
      return LabelSource.inputDecoration;
    case 'valueToString':
      return LabelSource.valueToString;
    case 'other':
      return LabelSource.other;
    case 'none':
    default:
      return null;
  }
}

SemanticRole _parseRole(String raw) {
  switch (raw) {
    case 'button':
      return SemanticRole.button;
    case 'image':
      return SemanticRole.image;
    case 'switchRole':
      return SemanticRole.switchRole;
    case 'checkbox':
      return SemanticRole.checkbox;
    case 'slider':
      return SemanticRole.slider;
    case 'textField':
      return SemanticRole.textField;
    case 'staticText':
      return SemanticRole.staticText;
    case 'header':
      return SemanticRole.header;
    case 'group':
      return SemanticRole.group;
    case 'unknown':
    default:
      return SemanticRole.unknown;
  }
}

ControlKind _parseControlKind(String raw) {
  switch (raw) {
    case 'elevatedButton':
      return ControlKind.elevatedButton;
    case 'textButton':
      return ControlKind.textButton;
    case 'filledButton':
      return ControlKind.filledButton;
    case 'outlinedButton':
      return ControlKind.outlinedButton;
    case 'iconButton':
      return ControlKind.iconButton;
    case 'floatingActionButton':
      return ControlKind.floatingActionButton;
    case 'listTile':
      return ControlKind.listTile;
    case 'checkboxControl':
      return ControlKind.checkboxControl;
    case 'switchControl':
      return ControlKind.switchControl;
    case 'sliderControl':
      return ControlKind.sliderControl;
    case 'textFieldControl':
      return ControlKind.textFieldControl;
    case 'none':
    default:
      return ControlKind.none;
  }
}
