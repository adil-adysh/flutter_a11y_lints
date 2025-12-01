// expect_lint: flutter_a11y_merge_composite_values
import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.trending_up),
        Text('72'),
      ],
    );
  }
}

class MyWidget2 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        children: [
          Icon(Icons.trending_up),
          Text('72'),
        ],
      ),
    );
  }
}
