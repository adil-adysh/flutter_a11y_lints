import 'evidence.dart';

enum TextState { unknown, absent, dynamic, static }

class TextFact {
  const TextFact({
    required this.state,
    required this.evidence,
    this.value,
  });

  final TextState state;
  final String? value;
  final FactEvidence evidence;
}

enum InputKind { unknown, text, number, emailAddress, phone, url, password }

enum ValidationState { unknown, valid, invalid }

class ValueInputFact {
  const ValueInputFact({
    required this.value,
    required this.hint,
    required this.inputKind,
    required this.validation,
    required this.evidence,
    this.minValue,
    this.maxValue,
    this.currentValueLength,
    this.maxValueLength,
  });

  final TextFact value;
  final TextFact hint;
  final InputKind inputKind;
  final ValidationState validation;
  final int? minValue;
  final int? maxValue;
  final int? currentValueLength;
  final int? maxValueLength;
  final FactEvidence evidence;
}
