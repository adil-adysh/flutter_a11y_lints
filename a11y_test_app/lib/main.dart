import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter A11y Test App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const A11yTestPage(title: 'A11y Lint Rules Test'),
    );
  }
}

/// Test page demonstrating all accessibility lint rule violations.
/// Each section contains code that should trigger a specific lint rule.
class A11yTestPage extends StatelessWidget {
  const A11yTestPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ============================================================
            // A01: Label Non-Text Controls
            // Rule: flutter_a11y_label_non_text_controls
            // Interactive controls without visible text must have labels.
            // ============================================================
            const Text('A01: Label Non-Text Controls',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // VIOLATION: IconButton without tooltip
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {},
            ),
            // CORRECT: IconButton with tooltip
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {},
              tooltip: 'Add item',
            ),
            const Divider(),

            // ============================================================
            // A02: Avoid Redundant Role Words
            // Rule: flutter_a11y_avoid_redundant_role_words
            // Don't include words like "button" in button labels.
            // ============================================================
            const Text('A02: Avoid Redundant Role Words',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // VIOLATION: Contains redundant "button" word
            ElevatedButton(
              onPressed: () {},
              child: const Text('Save button'),
            ),
            const SizedBox(height: 8),
            // VIOLATION: IconButton tooltip with redundant "button" word
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {},
              tooltip: 'Add button',
            ),
            // CORRECT: No redundant role words
            ElevatedButton(
              onPressed: () {},
              child: const Text('Save'),
            ),
            const Divider(),

            // ============================================================
            // A03: Decorative Images Excluded
            // Rule: flutter_a11y_decorative_images_excluded
            // Decorative images should be excluded from semantics.
            // ============================================================
            const Text('A03: Decorative Images Excluded',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // VIOLATION: Image in ListTile without excludeFromSemantics
            ListTile(
              leading: Image.asset('assets/icon.png'),
              title: const Text('Item with decorative icon'),
            ),
            // CORRECT: Image with excludeFromSemantics
            ListTile(
              leading: Image.asset(
                'assets/icon.png',
                excludeFromSemantics: true,
              ),
              title: const Text('Item with excluded icon'),
            ),
            // CORRECT: Image with semantic label
            ListTile(
              leading: Image.asset(
                'assets/icon.png',
                semanticLabel: 'User avatar',
              ),
              title: const Text('Item with labeled icon'),
            ),
            const Divider(),

            // ============================================================
            // A04: Informative Images Labeled
            // Rule: flutter_a11y_informative_images_labeled
            // Meaningful images in tappable areas must have semantic labels.
            // ============================================================
            const Text('A04: Informative Images Labeled',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // VIOLATION: Tappable image without semantic label
            GestureDetector(
              onTap: () {},
              child: Image.asset('assets/product.png'),
            ),
            const SizedBox(height: 8),
            // CORRECT: Tappable image with semantic label
            GestureDetector(
              onTap: () {},
              child: Image.asset(
                'assets/product.png',
                semanticLabel: 'View product details',
              ),
            ),
            const Divider(),

            // ============================================================
            // A05: No Redundant Button Semantics
            // Rule: flutter_a11y_no_button_semantics
            // Don't wrap Material buttons with Semantics(button: true).
            // ============================================================
            const Text('A05: No Redundant Button Semantics',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // VIOLATION: Redundant Semantics wrapper on button
            Semantics(
              button: true,
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('Submit'),
              ),
            ),
            const SizedBox(height: 8),
            // VIOLATION: Semantics with onTap wrapping IconButton
            Semantics(
              onTap: () {},
              child: IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {},
                tooltip: 'Settings',
              ),
            ),
            // CORRECT: Button without redundant semantics wrapper
            ElevatedButton(
              onPressed: () {},
              child: const Text('Submit'),
            ),
            const Divider(),

            // ============================================================
            // A06: Merge Multi-Part Single Concept
            // Rule: flutter_a11y_merge_composite_values
            // Multi-part values representing a single concept should be merged.
            // ============================================================
            const Text('A06: Merge Multi-Part Single Concept',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // VIOLATION: Icon and Text in Row without MergeSemantics
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.trending_up),
                const Text('72'),
              ],
            ),
            const SizedBox(height: 8),
            // CORRECT: Wrapped with MergeSemantics
            MergeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.trending_up),
                  const Text('72'),
                ],
              ),
            ),
            const Divider(),

            // ============================================================
            // A07: Replace Semantics Cleanly
            // Rule: flutter_a11y_clean_semantics_replacement
            // When Semantics provides label, children should be excluded.
            // ============================================================
            const Text('A07: Replace Semantics Cleanly',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // VIOLATION: Semantics with label but children not excluded
            Semantics(
              label: 'Mood score 72, up 2 today',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text('72'),
                  Icon(Icons.trending_up),
                  Text('+2'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // CORRECT: Children excluded from semantics
            Semantics(
              label: 'Mood score 72, up 2 today',
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text('72'),
                    Icon(Icons.trending_up),
                    Text('+2'),
                  ],
                ),
              ),
            ),
            const Divider(),

            // ============================================================
            // A08: Block Semantics Only for True Modals
            // Rule: flutter_a11y_block_semantics_only_for_modals
            // BlockSemantics should only be used for modals/overlays.
            // ============================================================
            const Text('A08: Block Semantics Only for True Modals',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // VIOLATION: BlockSemantics used outside of modal context
            BlockSemantics(
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.amber.shade100,
                child: const Text('This is not a modal'),
              ),
            ),
            const SizedBox(height: 8),
            // CORRECT: Button that shows a proper modal with BlockSemantics
            ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm'),
                    content: const Text('Are you sure?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Show Modal Dialog'),
            ),
            const Divider(),

            // ============================================================
            // A21: Use IconButton Tooltip Parameter
            // Rule: flutter_a11y_use_iconbutton_tooltip
            // Use IconButton's tooltip parameter instead of Tooltip wrapper.
            // ============================================================
            const Text('A21: Use IconButton Tooltip Parameter',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // VIOLATION: Tooltip widget wrapping IconButton
            Tooltip(
              message: 'Delete',
              child: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {},
              ),
            ),
            // CORRECT: Using tooltip parameter of IconButton
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {},
              tooltip: 'Delete',
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}