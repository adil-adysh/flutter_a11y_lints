import 'package:flutter/material.dart';

void main() {
  runApp(const A11yDemoApp());
}

class A11yDemoApp extends StatelessWidget {
  const A11yDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A11y Lints Demo',
      theme: ThemeData(useMaterial3: true),
      home: const A11yDemoHome(),
    );
  }
}

class A11yDemoHome extends StatelessWidget {
  const A11yDemoHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_a11y_lints – Rule Samples'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('A01 — Label non-text controls'),
          const A01Examples(),
          const Divider(),

          _buildSectionHeader('A03 — Decorative images must be excluded'),
          const A03Examples(),
          const Divider(),

          _buildSectionHeader('A04 — Informative images must have labels'),
          const A04Examples(),
          const Divider(),

          _buildSectionHeader(
              'A05 — No redundant Semantics wrappers on material buttons'),
          const A05Examples(),
          const Divider(),

          _buildSectionHeader('A11 — Minimum tap target size'),
          const A11Examples(),
          const Divider(),

          _buildSectionHeader('A16 — Toggle state via semantics flag'),
          const A16Examples(),
          const Divider(),

          _buildSectionHeader('A18 — Hidden focus traps (Offstage/Visibility)'),
          const A18Examples(),
          const Divider(),

          _buildSectionHeader(
              'A21 — Use IconButton.tooltip instead of Tooltip wrapper'),
          const A21Examples(),
          const Divider(),

          _buildSectionHeader(
              'A22 — Respect widget semantic boundaries (ListTile family)'),
          const A22Examples(),
          const Divider(),

          _buildSectionHeader(
              'A24 — Drag handle icons must be excluded from semantics'),
          const A24Examples(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  static Widget _buildSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}

//
// A01 — Label non-text controls (IconButton)
//

class A01Examples extends StatelessWidget {
  const A01Examples({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ❌ A01 violation: interactive IconButton without tooltip or Semantics label
        IconButton(
          icon: const Icon(Icons.info),
          onPressed: () {},
        ),

        const SizedBox(width: 24),

        // ✅ Correct: IconButton with tooltip
        IconButton(
          icon: const Icon(Icons.info),
          tooltip: 'More information',
          onPressed: () {},
        ),

        const SizedBox(width: 24),

        // ✅ Correct: wrapped in Semantics with label
        Semantics(
          label: 'Help and FAQ',
          child: IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {},
          ),
        ),
      ],
    );
  }
}

//
// A03 — Decorative images must be excluded
//

class A03Examples extends StatelessWidget {
  const A03Examples({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ❌ A03 violation:
        // Decorative background asset, not excluded, no semanticLabel
        const Text('Hero section with decorative background:'),
        const SizedBox(height: 8),
        Image.asset(
          'assets/bg_pattern.png', // contains "bg"
          fit: BoxFit.cover,
        ),

        const SizedBox(height: 16),

        // ✅ Correct: exclude decorative image from semantics
        const Text('Properly excluded decorative background:'),
        const SizedBox(height: 8),
        const ExcludeSemantics(
          child: Image.asset(
            'assets/bg_wallpaper.png', // contains "bg"
            fit: BoxFit.cover,
          ),
        ),

        const SizedBox(height: 16),

        // ✅ Alternative: semanticLabel marks it informative, not decorative
        const Text('Informative illustration with label:'),
        const SizedBox(height: 8),
        Image.asset(
          'assets/background_illustration.png',
          semanticLabel: 'Wave pattern behind onboarding illustration',
        ),
      ],
    );
  }
}

//
// A04 — Informative images must have labels
//

class A04Examples extends StatelessWidget {
  const A04Examples({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ❌ CircleAvatar(backgroundImage) without label
        const Text('Unlabeled avatar (violation):'),
        const SizedBox(height: 8),
        const CircleAvatar(
          radius: 24,
          backgroundImage: NetworkImage(
            'https://example.com/avatars/user_1.png',
          ),
        ),

        const SizedBox(height: 16),

        // ✅ CircleAvatar wrapped in Semantics with label
        const Text('Labeled avatar (correct):'),
        const SizedBox(height: 8),
        const Semantics(
          label: 'Profile picture of Alex Chen',
          child: CircleAvatar(
            radius: 24,
            backgroundImage: NetworkImage(
              'https://example.com/avatars/user_2.png',
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ❌ ListTile.leading Image.network without semanticLabel or Semantics
        const Text('ListTile with unlabeled leading image (violation):'),
        const SizedBox(height: 8),
        ListTile(
          leading: Image.network(
            'https://example.com/icons/article_cover.png',
            width: 40,
            height: 40,
          ),
          title: const Text('Meditation basics'),
          subtitle: const Text('5 min · Beginner'),
        ),

        const SizedBox(height: 16),

        // ✅ ListTile.leading Image with semanticLabel
        const Text('ListTile with labeled leading image (correct):'),
        const SizedBox(height: 8),
        ListTile(
          leading: Image.network(
            'https://example.com/icons/article_cover_2.png',
            width: 40,
            height: 40,
            semanticLabel: 'Article cover showing a sunrise',
          ),
          title: const Text('Morning energy'),
          subtitle: const Text('10 min · Intermediate'),
        ),

        const SizedBox(height: 16),

        // ✅ ListTile.leading CircleAvatar wrapped in Semantics
        const Text('ListTile with avatar labeled via Semantics (correct):'),
        const SizedBox(height: 8),
        ListTile(
          leading: const Semantics(
            label: 'Profile picture of Sara',
            child: CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage(
                'https://example.com/avatars/user_3.png',
              ),
            ),
          ),
          title: const Text('Sara Williams'),
          subtitle: const Text('Premium member'),
        ),
      ],
    );
  }
}

//
// A05 — No redundant Semantics on material buttons
//

class A05Examples extends StatelessWidget {
  const A05Examples({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        // ❌ A05 violation: redundant Semantics(button: true)
        Semantics(
          // Redundant, ElevatedButton already announces as button
          button: true,
          child: ElevatedButton(
            onPressed: () {},
            child: const Text('Save'),
          ),
        ),

        // ❌ A05 violation: empty Semantics wrapper around a button
        Semantics(
          // no label, no other properties
          child: IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: () {},
          ),
        ),

        // ✅ Correct: Semantics adds label, not just button flag
        Semantics(
          label: 'Save changes to profile',
          child: ElevatedButton(
            onPressed: () {},
            child: const Text('Save'),
          ),
        ),

        // ✅ Correct: no Semantics wrapper at all
        IconButton(
          icon: const Icon(Icons.share),
          tooltip: 'Share',
          onPressed: () {},
        ),
      ],
    );
  }
}

//
// A11 — Minimum tap target size (literal)
//

class A11Examples extends StatelessWidget {
  const A11Examples({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ❌ A11 violation: very small tappable area (32x32)
        SizedBox(
          width: 32,
          height: 32,
          child: IconButton(
            iconSize: 16,
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.close),
            onPressed: () {},
          ),
        ),

        const SizedBox(width: 24),

        // ✅ Correct: at least 48x48
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {},
          ),
        ),
      ],
    );
  }
}

//
// A16 — Toggle state must use Semantics flags (not label text)
//

class A16Examples extends StatelessWidget {
  const A16Examples({super.key});

  @override
  Widget build(BuildContext context) {
    const bool wifiOn = true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ❌ A16 violation: on/off state encoded in label text
        const Text('Wifi toggle (bad label-based state):'),
        const SizedBox(height: 8),
        Semantics(
          label: wifiOn ? 'Wifi on' : 'Wifi off',
          child: Switch(
            value: wifiOn,
            onChanged: (_) {},
          ),
        ),

        const SizedBox(height: 16),

        // ✅ Correct: use toggled flag + neutral label
        const Text('Wifi toggle (correct semantics flags):'),
        const SizedBox(height: 8),
        Semantics(
          label: 'Wifi',
          toggled: wifiOn,
          child: Switch(
            value: wifiOn,
            onChanged: (_) {},
          ),
        ),
      ],
    );
  }
}

//
// A18 — Hidden focus traps (Offstage / Visibility)
//

class A18Examples extends StatelessWidget {
  const A18Examples({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ❌ A18 violation: focusable TextField in Offstage(offstage: true)
        const Text('Offstage focus trap (violation):'),
        const SizedBox(height: 8),
        const Offstage(
          offstage: true,
          child: TextField(
            decoration: InputDecoration(labelText: 'Hidden but focusable'),
          ),
        ),

        const SizedBox(height: 16),

        // ❌ A18 violation: focusable button inside Visibility(visible: false)
        const Text('Visibility focus trap (violation):'),
        const SizedBox(height: 8),
        Visibility(
          visible: false,
          child: ElevatedButton(
            onPressed: () {},
            child: const Text('Hidden submit'),
          ),
        ),

        const SizedBox(height: 16),

        // ✅ Correct: Offstage used for non-focusable content
        const Text('Offstage with non-focusable child (allowed):'),
        const SizedBox(height: 8),
        const Offstage(
          offstage: true,
          child: Text('Hidden debug label'),
        ),
      ],
    );
  }
}

//
// A21 — Use IconButton.tooltip instead of Tooltip wrapper
//

class A21Examples extends StatelessWidget {
  const A21Examples({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ❌ A21 violation:
        // Tooltip wrapping IconButton that has no tooltip of its own
        Tooltip(
          message: 'Open settings',
          child: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          ),
        ),

        const SizedBox(width: 24),

        // ✅ Correct: use IconButton.tooltip directly
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: 'Open settings',
          onPressed: () {},
        ),
      ],
    );
  }
}

//
// A22 — Respect semantic boundaries (ListTile family)
//

class A22Examples extends StatelessWidget {
  const A22Examples({super.key});

  @override
  Widget build(BuildContext context) {
    bool notificationsOn = true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ❌ A22 violation: MergeSemantics around a ListTile
        const Text('MergeSemantics wrapping ListTile (violation):'),
        const SizedBox(height: 8),
        MergeSemantics(
          child: ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            trailing: Switch(
              value: notificationsOn,
              onChanged: (_) {},
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ❌ A22 violation: MergeSemantics around SwitchListTile
        const Text('MergeSemantics wrapping SwitchListTile (violation):'),
        const SizedBox(height: 8),
        MergeSemantics(
          child: SwitchListTile(
            value: notificationsOn,
            onChanged: (_) {},
            title: const Text('Newsletter'),
          ),
        ),

        const SizedBox(height: 16),

        // ✅ Correct: no MergeSemantics, widget handles semantics internally
        const Text('Plain SwitchListTile (correct):'),
        const SizedBox(height: 8),
        SwitchListTile(
          value: notificationsOn,
          onChanged: (_) {},
          title: const Text('Dark mode'),
        ),
      ],
    );
  }
}

//
// A24 — Drag handle icons must be excluded
//

class A24Examples extends StatelessWidget {
  const A24Examples({super.key});

  @override
  Widget build(BuildContext context) {
    final items = List<String>.generate(3, (i) => 'Item ${i + 1}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Reorderable list with drag handles:'),

        const SizedBox(height: 8),

        // This is just a visual layout demo; not an actual ReorderableListView
        Column(
          children: [
            for (final item in items)
              ListTile(
                // ❌ A24 violation: drag handle Icon not excluded
                leading: const Icon(Icons.drag_handle),
                title: Text(item),
              ),
          ],
        ),

        const SizedBox(height: 16),

        const Text('Correct: drag handles excluded from semantics:'),

        const SizedBox(height: 8),

        Column(
          children: [
            for (final item in items)
              ListTile(
                // ✅ Correct: drag handle inside ExcludeSemantics
                leading: const ExcludeSemantics(
                  child: Icon(Icons.drag_handle),
                ),
                title: Text(item),
              ),
          ],
        ),
      ],
    );
  }
}

