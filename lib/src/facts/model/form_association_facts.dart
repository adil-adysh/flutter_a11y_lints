import 'evidence.dart';

/// Whether a field has a source-proven static semantic label association.
///
/// Absence is intentionally not represented: a static analyzer cannot prove
/// that arbitrary source structure supplies no accessible label.
enum StaticLabelAssociationState { unknown, static }

/// A derived association from a static `controlsNodes` target identifier to a
/// controller with a static local semantic name.
class FormAssociationFact {
  const FormAssociationFact({
    required this.state,
    required this.evidence,
    this.labelNodeIds = const [],
  });

  final StaticLabelAssociationState state;
  final List<int> labelNodeIds;
  final FactEvidence evidence;
}
