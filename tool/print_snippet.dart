import 'dart:io';
void main() {
  final s = File('test.faql').readAsStringSync();
  print('LEN=${s.length}');
  final pos = 1369;
  var start = pos - 40;
  if (start < 0) start = 0;
  final lenOut = (s.length - start < 120) ? s.length - start : 120;
  print('START=$start, LEN=$lenOut');
  print('---SNIPPET---');
  print(s.substring(start, start + lenOut));
  print('---END---');
}
