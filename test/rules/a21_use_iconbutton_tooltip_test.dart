// expect_lint: flutter_a11y_use_iconbutton_tooltip
import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Delete',
      child: IconButton(
        icon: Icon(Icons.delete),
        onPressed: () {},
      ),
    );
  }
}

class MyWidget2 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.delete),
      onPressed: () {},
      tooltip: 'Delete',
    );
  }
}
