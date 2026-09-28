import 'evidence.dart';

enum NameState { unknown, absent, dynamic, static }

enum NameSource {
  semanticsLabel,
  tooltip,
  widgetLabel,
  textChild,
  inputDecoration,
  customWidgetDerived,
  frameworkDerived,
}

class NameFact {
  const NameFact({
    required this.state,
    required this.evidence,
    this.source,
    this.value,
  });

  const NameFact.unknown()
      : state = NameState.unknown,
        evidence = const FactEvidence(
          provenance: FactProvenance.exact,
          knowledge: KnowledgeState.unknown,
        ),
        source = null,
        value = null;

  final NameState state;
  final NameSource? source;
  final String? value;
  final FactEvidence evidence;
}
