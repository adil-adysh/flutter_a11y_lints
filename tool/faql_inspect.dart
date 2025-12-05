import 'dart:io';
import 'package:petitparser/petitparser.dart';
import 'package:flutter_a11y_lints/src/faql/grammar.dart';

void main() {
  final parser = FaqlGrammar().build();
  const input = '''
    rule "slider-integrity" on kind(slider) {
      meta { severity: "error" }
      when: prop("divisions").is_resolved
      ensure: prop("divisions") as int <= 10 && focusable
      report: "Too many divisions!"
    }
  ''';
  final result = parser.parse(input);
  print('success: ${result is Success}');
  print('value type: ${result.value.runtimeType}');
  final _out = File('tool/faql_parse_dump.txt').openWrite();

  void dump(dynamic v, [int indent = 0]) {
    final pad = ' ' * indent;
    if (v is List) {
      _out.writeln('${pad}List(len=${v.length}) [');
      for (var i = 0; i < v.length; i++) {
        dump(v[i], indent + 2);
      }
      _out.writeln('${pad}]');
    } else {
      _out.writeln('${pad}${v.runtimeType}: $v');
    }
  }

  dump(result.value);
  _out.close();
  print('Dump written to tool/faql_parse_dump.txt');
}
