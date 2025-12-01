import 'dart:typed_data';

import 'package:flutter/material.dart';

typedef WidgetBuilderFactory = Widget Function();

class WidgetCatalogueEntry {
  final String name;
  final Type type;
  final WidgetBuilderFactory builder;

  const WidgetCatalogueEntry(this.name, this.type, this.builder);
}

/// 1x1 transparent PNG bytes for testing Image widget
final Uint8List _transparentPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

final List<WidgetCatalogueEntry> widgetCatalogue = [
  // ============================================================
  // Buttons & Interactive Controls
  // ============================================================

  WidgetCatalogueEntry(
    'IconButton',
    IconButton,
    () => IconButton(
      onPressed: () {},
      icon: const Icon(Icons.add),
      tooltip: 'Test',
    ),
  ),

  WidgetCatalogueEntry(
    'ElevatedButton',
    ElevatedButton,
    () => ElevatedButton(
      onPressed: () {},
      child: const Text('Button'),
    ),
  ),

  WidgetCatalogueEntry(
    'TextButton',
    TextButton,
    () => TextButton(
      onPressed: () {},
      child: const Text('Button'),
    ),
  ),

  WidgetCatalogueEntry(
    'OutlinedButton',
    OutlinedButton,
    () => OutlinedButton(
      onPressed: () {},
      child: const Text('Button'),
    ),
  ),

  WidgetCatalogueEntry(
    'FilledButton',
    FilledButton,
    () => FilledButton(
      onPressed: () {},
      child: const Text('Button'),
    ),
  ),

  WidgetCatalogueEntry(
    'FloatingActionButton',
    FloatingActionButton,
    () => FloatingActionButton(
      onPressed: () {},
      child: const Icon(Icons.add),
    ),
  ),

  // ============================================================
  // Toggles
  // ============================================================

  WidgetCatalogueEntry(
    'Switch',
    Switch,
    () => Switch(
      value: true,
      onChanged: (_) {},
    ),
  ),

  WidgetCatalogueEntry(
    'Checkbox',
    Checkbox,
    () => Checkbox(
      value: true,
      onChanged: (_) {},
    ),
  ),

  WidgetCatalogueEntry(
    'Radio',
    Radio,
    () => Radio<int>(
      value: 1,
      groupValue: 1,
      onChanged: (_) {},
    ),
  ),

  WidgetCatalogueEntry(
    'SwitchListTile',
    SwitchListTile,
    () => SwitchListTile(
      value: true,
      onChanged: (_) {},
      title: const Text('Switch'),
    ),
  ),

  WidgetCatalogueEntry(
    'CheckboxListTile',
    CheckboxListTile,
    () => CheckboxListTile(
      value: true,
      onChanged: (_) {},
      title: const Text('Checkbox'),
    ),
  ),

  WidgetCatalogueEntry(
    'RadioListTile',
    RadioListTile,
    () => RadioListTile<int>(
      value: 1,
      groupValue: 1,
      onChanged: (_) {},
      title: const Text('Radio'),
    ),
  ),

  // ============================================================
  // Input Fields
  // ============================================================

  WidgetCatalogueEntry(
    'TextField',
    TextField,
    () => const TextField(
      decoration: InputDecoration(labelText: 'Input'),
    ),
  ),

  WidgetCatalogueEntry(
    'TextFormField',
    TextFormField,
    () => TextFormField(
      decoration: const InputDecoration(labelText: 'Form Input'),
    ),
  ),

  // ============================================================
  // Sliders
  // ============================================================

  WidgetCatalogueEntry(
    'Slider',
    Slider,
    () => Slider(
      value: 0.5,
      onChanged: (_) {},
    ),
  ),

  // ============================================================
  // Structure & Layout
  // ============================================================

  WidgetCatalogueEntry(
    'ListTile',
    ListTile,
    () => const ListTile(
      title: Text('Title'),
      subtitle: Text('Subtitle'),
    ),
  ),

  WidgetCatalogueEntry(
    'Card',
    Card,
    () => const Card(
      child: Text('Card content'),
    ),
  ),

  // ============================================================
  // Images & Icons
  // ============================================================

  WidgetCatalogueEntry(
    'Image',
    Image,
    () => Image.memory(
      _transparentPng,
      semanticLabel: 'Example image',
    ),
  ),

  WidgetCatalogueEntry(
    'Icon',
    Icon,
    () => const Icon(Icons.home),
  ),

  WidgetCatalogueEntry(
    'CircleAvatar',
    CircleAvatar,
    () => const CircleAvatar(
      child: Text('A'),
    ),
  ),

  // ============================================================
  // Text
  // ============================================================

  WidgetCatalogueEntry(
    'Text',
    Text,
    () => const Text('Sample text'),
  ),

  // ============================================================
  // Semantic Containers
  // ============================================================

  WidgetCatalogueEntry(
    'Semantics',
    Semantics,
    () => Semantics(
      label: 'Test label',
      child: const Text('Content'),
    ),
  ),

  WidgetCatalogueEntry(
    'MergeSemantics',
    MergeSemantics,
    () => const MergeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star),
          Text('Merged'),
        ],
      ),
    ),
  ),

  WidgetCatalogueEntry(
    'ExcludeSemantics',
    ExcludeSemantics,
    () => const ExcludeSemantics(
      child: Icon(Icons.ac_unit),
    ),
  ),

  WidgetCatalogueEntry(
    'BlockSemantics',
    BlockSemantics,
    () => const BlockSemantics(
      child: Text('Blocked'),
    ),
  ),

  // ============================================================
  // Layout Containers
  // ============================================================

  WidgetCatalogueEntry(
    'Row',
    Row,
    () => const Row(
      mainAxisSize: MainAxisSize.min,
      children: [Text('A'), Text('B')],
    ),
  ),

  WidgetCatalogueEntry(
    'Column',
    Column,
    () => const Column(
      mainAxisSize: MainAxisSize.min,
      children: [Text('A'), Text('B')],
    ),
  ),

  WidgetCatalogueEntry(
    'Wrap',
    Wrap,
    () => const Wrap(
      children: [Text('A'), Text('B')],
    ),
  ),
];
