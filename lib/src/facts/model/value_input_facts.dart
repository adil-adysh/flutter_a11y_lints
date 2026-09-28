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

enum IntegerState { unknown, absent, dynamic, static }

class IntegerFact {
  const IntegerFact({
    required this.state,
    required this.evidence,
    this.value,
  });

  final IntegerState state;
  final int? value;
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
    required this.minValue,
    required this.maxValue,
    required this.currentValueLength,
    required this.maxValueLength,
  });

  final TextFact value;
  final TextFact hint;
  final InputKind inputKind;
  final ValidationState validation;
  final TextFact minValue;
  final TextFact maxValue;
  final IntegerFact currentValueLength;
  final IntegerFact maxValueLength;
  final FactEvidence evidence;
}
