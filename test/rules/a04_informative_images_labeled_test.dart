// expect_lint: flutter_a11y_informative_images_labeled
import 'package:flutter/material.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Image.asset('assets/icon.png'),
    );
  }
}

class MyWidget2 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Image.asset(
        'assets/icon.png',
        semanticLabel: 'Icon',
      ),
    );
  }
}

class MyWidget3 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Icon',
      child: GestureDetector(
        onTap: () {},
        child: Image.asset('assets/icon.png'),
      ),
    );
  }
}
