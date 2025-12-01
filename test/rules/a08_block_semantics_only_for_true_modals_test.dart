// expect_lint: flutter_a11y_block_semantics_only_for_modals
import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlockSemantics(
      child: Text('This is not a modal'),
    );
  }
}

class MyWidget2 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: BlockSemantics(
        child: Text('This is a modal'),
      ),
    );
  }
}
