import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';

class _ContextFrame {
  final InstanceCreationExpression node;
  final InterfaceType? type;

  _ContextFrame(this.node, this.type);
}

class WidgetContext {
  final List<_ContextFrame> stack = [];

  void push(InstanceCreationExpression node, InterfaceType? type) {
    stack.add(_ContextFrame(node, type));
  }

  void pop() {
    stack.removeLast();
  }

  bool get insideSemantics {
    return stack.any((frame) => frame.type?.element.name == 'Semantics');
  }

  bool get insideListTile {
    return stack.any((frame) => frame.type?.element.name == 'ListTile');
  }

  bool get insideBlockSemantics {
    return stack.any((frame) => frame.type?.element.name == 'BlockSemantics');
  }
}
