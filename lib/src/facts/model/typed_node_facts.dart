import 'composition_facts.dart';
import 'exposure_facts.dart';
import 'image_facts.dart';
import 'naming_facts.dart';
import 'role_action_facts.dart';
import 'relationship_facts.dart';
import 'state_facts.dart';
import 'value_input_facts.dart';

/// Typed, authoritative semantic facts associated with one source node.
///
/// The generic `SemanticFact` records remain a temporary serialization layer
/// for FAQL migration and diagnostics. New semantic consumers must use this
/// model instead of string fact names.
class TypedNodeFacts {
  const TypedNodeFacts({
    this.composition,
    this.name,
    this.controlState,
    this.exposure,
    this.role,
    this.image,
    this.valueInput,
    this.relationship,
    this.actions = const [],
  });

  final CompositionFact? composition;
  final NameFact? name;
  final ControlStateFact? controlState;
  final ExposureFact? exposure;
  final RoleFact? role;
  final ImageFact? image;
  final ValueInputFact? valueInput;
  final SemanticRelationshipFact? relationship;
  final List<SemanticActionFact> actions;

  SemanticActionFact? action(ActionKind kind) {
    for (final candidate in actions) {
      if (candidate.kind == kind) return candidate;
    }
    return null;
  }
}
