import 'evidence.dart';
import 'value_input_facts.dart';

/// Whether a source `controlsNodes` collection is fully statically known.
///
/// This does not claim a target node exists or that Flutter will emit the
/// relationship. Those are separate composition/runtime questions.
enum IdentifierSetState { unknown, absent, dynamic, static }

/// Exact source evidence for semantic identifiers and explicit relationships.
///
/// Identifiers remain opaque strings. Source-widget, semantic-composition, and
/// accessibility-tree edges are modelled separately and are never inferred
/// from matching identifiers alone.
class SemanticRelationshipFact {
  const SemanticRelationshipFact({
    required this.identifier,
    required this.traversalParentIdentifier,
    required this.traversalChildIdentifier,
    required this.controlsNodeIdentifiers,
    required this.evidence,
  });

  final TextFact identifier;
  final TextFact traversalParentIdentifier;
  final TextFact traversalChildIdentifier;
  final IdentifierSetFact controlsNodeIdentifiers;
  final FactEvidence evidence;
}

class IdentifierSetFact {
  const IdentifierSetFact({
    required this.state,
    required this.evidence,
    this.values = const [],
  });

  final IdentifierSetState state;
  final List<String> values;
  final FactEvidence evidence;
}
