import 'package:analyzer/dart/element/type.dart';

bool isType(DartType? t, String package, String className) {
  if (t == null) return false;
  return t.element?.name == className &&
      t.element?.library?.identifier.startsWith('package:$package') == true;
}

bool isIconButton(DartType? t) {
  return isType(t, 'flutter', 'IconButton');
}

bool isMaterialButton(DartType? t) {
  return isType(t, 'flutter', 'ElevatedButton') ||
      isType(t, 'flutter', 'FilledButton') ||
      isType(t, 'flutter', 'TextButton') ||
      isType(t, 'flutter', 'OutlinedButton') ||
      isType(t, 'flutter', 'FloatingActionButton');
}

bool isListTile(DartType? t) {
  return isType(t, 'flutter', 'ListTile');
}

bool isImage(DartType? t) {
  return isType(t, 'flutter', 'Image');
}

bool isSemantics(DartType? t) {
  return isType(t, 'flutter', 'Semantics');
}

