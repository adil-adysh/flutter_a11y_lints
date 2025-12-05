import 'dart:io';

void main() {
  final s = File('test.faql').readAsStringSync();
  for (var i = s.length - 50; i < s.length; i++) {
    if (i < 0) continue;
    final ch = s[i];
    final rep = (ch == '\n')
        ? '\\n'
        : (ch == '\r')
            ? '\\r'
            : ch;
    print(
        '${i.toString().padLeft(5)}: "$rep" (0x${ch.codeUnitAt(0).toRadixString(16)})');
  }
}
