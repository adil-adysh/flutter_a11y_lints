// expect_lint: flutter_a11y_decorative_images_excluded
import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Image.asset('assets/icon.png'),
      title: Text('Item title'),
    );
  }
}

class MyWidget2 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Image.asset(
        'assets/icon.png',
        excludeFromSemantics: true,
      ),
      title: Text('Item title'),
    );
  }
}

class MyWidget3 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Image.asset(
        'assets/icon.png',
        semanticLabel: 'Icon',
      ),
      title: Text('Item title'),
    );
  }
}
