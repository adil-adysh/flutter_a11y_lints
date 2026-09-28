/// How the analyzer obtained a fact. This is deliberately independent from
/// whether the value is statically known.
enum FactProvenance { exact, derived, heuristic }

/// Whether the fact's value can safely be used as a definite premise.
enum KnowledgeState { known, dynamic, unknown }

/// A source range contributing to a fact. It is serializable so diagnostics do
/// not need analyzer AST objects after extraction.
class SourceSpan {
  const SourceSpan(this.uri, this.offset, this.length);

  final String uri;
  final int offset;
  final int length;
}

/// A fact input retained by derived facts for diagnostics and auditing.
class FactReference {
  const FactReference({required this.nodeId, required this.kind});

  final int nodeId;
  final String kind;
}

/// Common evidence carried by every typed fact.
class FactEvidence {
  const FactEvidence({
    required this.provenance,
    required this.knowledge,
    this.sources = const [],
    this.inputs = const [],
  });

  const FactEvidence.dynamic({this.sources = const []})
      : provenance = FactProvenance.exact,
        knowledge = KnowledgeState.dynamic,
        inputs = const [];

  final FactProvenance provenance;
  final KnowledgeState knowledge;
  final List<SourceSpan> sources;
  final List<FactReference> inputs;
}
