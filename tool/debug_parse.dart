import 'dart:io';
import 'package:petitparser/petitparser.dart';
import 'package:flutter_a11y_lints/src/faql/grammar.dart';

void main() {
  final s = File('test.faql').readAsStringSync();
  final parser = FaqlGrammar().build();
  final result = parser.parse(s);
  print('Result: ${result.runtimeType}');
  if (result is Success) {
    print('Success. Value type: ${result.value.runtimeType}');
  } else if (result is Failure) {
    print('Failure: ${result.message} at ${result.position}');
    final pos = result.position;
    final start = pos - 40 < 0 ? 0 : pos - 40;
    final end = pos + 40 > s.length ? s.length : pos + 40;
    print('Context:');
    print(s
        .substring(start, end)
        .replaceAll('\r', '\\r')
        .replaceAll('\n', '\\n'));

    // Now test the standalone hidden parser copied from the grammar to see
    // whether it consumes the trailing content starting at the failure pos.
    final suffix = s.substring(pos);
    print('\n--- SUFFIX START ---');
    print(suffix.replaceAll('\r', '\\r').replaceAll('\n', '\\n'));

    // Recreate singleLineComment and hidden here for testing.
    final singleLineComment = (string('//') &
        any().starLazy(char('\n') | char('\r')) &
        (string('\r\n') | char('\n') | char('\r') | endOfInput()));
    final hidden = (whitespace() | singleLineComment).star();

    final hresult = hidden.parse(suffix);
    print('\nHidden parse result: ${hresult.runtimeType}');
    if (hresult is Success) {
      print(
          'Hidden consumed ${hresult.position} chars; success value length: ${hresult.value.toString().length}');
    } else if (hresult is Failure) {
      print('Hidden failure: ${hresult.message} at ${hresult.position}');
    }
    final sresult = singleLineComment.parse(suffix);
    print('\nSingleLineComment parse: ${sresult.runtimeType}');
    if (sresult is Success)
      print('S consumed ${sresult.position}');
    else
      print('S failure: ${sresult.message} at ${sresult.position}');
  }
}
