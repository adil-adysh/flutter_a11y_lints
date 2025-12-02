import 'package:analyzer/dart/ast/ast.dart';
import 'package:meta/meta.dart';

import 'known_semantics.dart';

/// Label guarantee determines how confident we are that a label exists.
enum LabelGuarantee { none, hasLabelButDynamic, hasStaticLabel }

/// Origin of a label when one is known.
enum LabelSource { none, tooltip, textChild, semanticsWidget, inputDecoration, other }

/// Simplified semantic IR node for v1 of the pipeline.
@immutable
class SemanticNode {
  const SemanticNode({
    required this.widgetType,
    required this.astNode,
    required this.fileUri,
    required this.offset,
    required this.length,
    required this.role,
    required this.controlKind,
    required this.isFocusable,
    required this.isEnabled,
    required this.hasTap,
    required this.hasLongPress,
    required this.hasIncrease,
    required this.hasDecrease,
    required this.isToggled,
    required this.isChecked,
    required this.mergesDescendants,
    required this.excludesDescendants,
    required this.blocksBehind,
    required this.label,
    required this.labelGuarantee,
    required this.labelSource,
    required this.explicitChildLabel,
    required this.children,
  });

  final String widgetType;
  final AstNode astNode;
  final Uri fileUri;
  final int offset;
  final int length;

  final SemanticRole role;
  final ControlKind controlKind;

  final bool isFocusable;
  final bool isEnabled;
  final bool hasTap;
  final bool hasLongPress;
  final bool hasIncrease;
  final bool hasDecrease;
  final bool isToggled;
  final bool isChecked;

  final bool mergesDescendants;
  final bool excludesDescendants;
  final bool blocksBehind;

  final String? label;
  final LabelGuarantee labelGuarantee;
  final LabelSource labelSource;
  final String? explicitChildLabel;

  final List<SemanticNode> children;

  String? get effectiveLabel {
    if (label != null && label!.isNotEmpty) {
      return label;
    }
    if (explicitChildLabel != null && explicitChildLabel!.isNotEmpty) {
      return explicitChildLabel;
    }
    return null;
  }
}
