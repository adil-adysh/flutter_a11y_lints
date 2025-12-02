import 'known_semantics_data.dart';

/// Semantic roles supported by the v1 semantic IR.
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

/// High-level control kinds used for extra context in rules.
enum ControlKind {
  none,
  elevatedButton,
  textButton,
  iconButton,
  floatingActionButton,
  listTile,
  checkboxControl,
  switchControl,
  sliderControl,
  textFieldControl,
}

/// Normalized semantics metadata for a known Flutter widget.
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
        slotTraversalOrder: List<String>.from(data['slotTraversalOrder'] as List),
      );
    }

    return MapEntry(widgetType, build());
  });
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
