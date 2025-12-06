import 'dart:io';
import 'package:flutter_a11y_lints/src/faql/parser.dart';

void main(List<String> args) {
  final path = args.isNotEmpty ? args.first : 'a11y_rules/custom_label.faql';
  final content = File(path).readAsStringSync();
  final p = FaqlParser();
  try {
    final rules = p.parseRules(content);
    print('Parsed ${rules.length} rule(s)');
    for (final rule in rules) {
      print('Rule name: ${rule.name}, selectors: ${rule.selectors}');
    }
  } catch (e) {
    final err = e.toString();
    print('Parse error: $err');
    // Try to extract position from exception message if present
    final m = RegExp(r'at (\d+)').firstMatch(err);
    if (m != null) {
      final pos = int.tryParse(m.group(1)!) ?? -1;
      if (pos >= 0) {
        final before =
            content.substring((pos - 10).clamp(0, content.length), pos);
        final after =
            content.substring(pos, (pos + 10).clamp(0, content.length));
        print('Around position $pos: <<${before}>>|<<${after}>>');
      }
    }
  }
}
