// expect_lint: flutter_a11y_clean_semantics_replacement
import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'This is a test',
      child: Text('This is a test'),
    );
  }
}

class MyWidget2 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'This is a test',
      child: ExcludeSemantics(
        child: Text('This is a test'),
      ),
    );
  }
}
