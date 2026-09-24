import '../facts/fact_store.dart';

class Faql4ValidationError implements Exception {
  Faql4ValidationError(this.message);
  final String message;
  @override
  String toString() => 'Faql4ValidationError: $message';
}

class CompiledQuery {
  const CompiledQuery({
    required this.queryId,
    required this.ruleId,
    required this.severity,
    required this.mode,
    required this.view,
    required this.variable,
    required this.where,
    required this.message,
  });

  final String queryId;
  final String ruleId;
  final String severity;
  final FactMode mode;
  final String view;
  final String variable;
  final _Expression? where;
  final String message;
}

class Faql4Violation {
  const Faql4Violation(this.nodeId, this.query);
  final int nodeId;
  final CompiledQuery query;
}

/// Deliberately small FAQL 4 compiler. Its tokens are independent from Dart
/// syntax; all Flutter knowledge is exposed through the standard predicates.
class Faql4Compiler {
  CompiledQuery compile(String source) {
    final metadata = <String, String>{};
    for (final line in source.split('\n')) {
      final match = RegExp(r'^\s*@([\w-]+)\s+(.+?)\s*$').firstMatch(line);
      if (match != null) metadata[match[1]!] = match[2]!;
    }
    const required = ['id', 'rule-id', 'severity', 'mode'];
    for (final key in required) {
      if (!metadata.containsKey(key)) throw Faql4ValidationError('Missing @$key metadata.');
    }
    final from = RegExp(r'\bfrom\s+(\w+)\s+(\w+)').firstMatch(source);
    final select = RegExp(r'\bselect\s+(\w+)\s*,\s*"([^"]*)"').firstMatch(source);
    if (from == null || select == null || from[2] != select[1]) {
      throw Faql4ValidationError('A query needs matching from/select variables.');
    }
    if (!_views.contains(from[1])) throw Faql4ValidationError('Unknown view ${from[1]}.');
    final mode = switch (metadata['mode']) {
      'conservative' => FactMode.conservative,
      'expanded' => FactMode.expanded,
      _ => throw Faql4ValidationError('Mode must be conservative or expanded.'),
    };
    final whereMatch = RegExp(r'\bwhere\s+([\s\S]*?)\s*\bselect\b').firstMatch(source);
    final expression = whereMatch == null ? null : _ExpressionParser(whereMatch[1]!, from[2]!).parse();
    if (mode == FactMode.conservative && expression?.hasUnsafePartialNegation == true) {
      throw Faql4ValidationError('Conservative queries cannot negate partial predicates.');
    }
    return CompiledQuery(
      queryId: metadata['id']!, ruleId: metadata['rule-id']!, severity: metadata['severity']!,
      mode: mode, view: from[1]!, variable: from[2]!, where: expression, message: select[2]!,
    );
  }
}

class Faql4Evaluator {
  List<Faql4Violation> evaluate(CompiledQuery query, AccessibilityFactStore store) {
    final view = query.mode == FactMode.conservative ? store.conservative : store.expanded;
    final hits = <Faql4Violation>[];
    for (final node in view.nodes.where((node) => _matchesView(query.view, node, view))) {
      final context = _EvaluationContext(store, view, {query.variable: node.id});
      if (query.where == null || query.where!.evaluate(context) == true) hits.add(Faql4Violation(node.id, query));
    }
    return hits;
  }
}

const _views = {
  'SemanticNode', 'InteractiveControl', 'MaterialButtonControl', 'ImageNode',
  'SemanticsNode', 'MergeSemanticsNode', 'ListTileNode',
};

bool _matchesView(String view, FactNode node, FactStoreView facts) {
  final values = {for (final f in facts.factsFor(node.id)) f.name: f.value};
  switch (view) {
    case 'SemanticNode': return true;
    case 'InteractiveControl': return values['tap'] == true || values['longPress'] == true;
    case 'MaterialButtonControl': return const {'iconButton','elevatedButton','textButton','filledButton','outlinedButton','floatingActionButton'}.contains(values['controlKind']);
    case 'ImageNode': return node.widgetType == 'Image' || node.widgetType == 'CircleAvatar';
    case 'SemanticsNode': return node.widgetType == 'Semantics';
    case 'MergeSemanticsNode': return node.widgetType == 'MergeSemantics';
    case 'ListTileNode': return node.widgetType.endsWith('ListTile');
  }
  return false;
}

class _EvaluationContext {
  const _EvaluationContext(this.store, this.view, this.bindings);
  final AccessibilityFactStore store;
  final FactStoreView view;
  final Map<String, int> bindings;
  Object? property(String variable, String name) {
    final id = bindings[variable];
    if (id == null) return null;
    if (name == 'getWidgetType') return store.nodes.firstWhere((node) => node.id == id).widgetType;
    for (final fact in view.factsFor(id)) if (fact.name == name) return fact.value;
    return null;
  }
}

abstract class _Expression {
  bool? evaluate(_EvaluationContext context);
  bool get hasUnsafePartialNegation => false;
}

class _Predicate extends _Expression {
  _Predicate(this.variable, this.name);
  final String variable;
  final String name;
  @override bool? evaluate(_EvaluationContext c) {
    final value = c.property(variable, _factName(name));
    return switch (name) {
      'isDefinitelyEnabled' => value == true,
      'isDefinitelyFocusable' => value == true,
      'isDefinitelyUnlabeled' => value == 'absent',
      'hasAccessibleLabel' => value == 'static' || value == 'dynamic',
      'hasStaticLabel' => value == 'static',
      'hasTapAction' => value == true,
      'hasLongPressAction' => value == true,
      'mergesDescendants' => value == true,
      'excludesDescendants' => value == true,
      _ => throw Faql4ValidationError('Unknown predicate $name.'),
    };
  }
}

String _factName(String predicate) => switch (predicate) {
  'isDefinitelyEnabled' => 'enabled', 'isDefinitelyFocusable' => 'focusable',
  'isDefinitelyUnlabeled' || 'hasAccessibleLabel' || 'hasStaticLabel' => 'labelState',
  'hasTapAction' => 'tap', 'hasLongPressAction' => 'longPress',
  _ => predicate,
};

class _Not extends _Expression {
  _Not(this.inner); final _Expression inner;
  @override bool? evaluate(_EvaluationContext c) => !(inner.evaluate(c) ?? false);
  @override bool get hasUnsafePartialNegation => inner is _Predicate && (inner as _Predicate).name == 'hasAccessibleLabel';
}
class _Binary extends _Expression {
  _Binary(this.left, this.operator, this.right); final _Expression left; final String operator; final _Expression right;
  @override bool? evaluate(_EvaluationContext c) {
    if (operator == 'and') return left.evaluate(c) == true && right.evaluate(c) == true;
    return left.evaluate(c) == true || right.evaluate(c) == true;
  }
  @override bool get hasUnsafePartialNegation => left.hasUnsafePartialNegation || right.hasUnsafePartialNegation;
}

/// Parser intentionally accepts only Core predicate calls and Boolean logic.
class _ExpressionParser {
  _ExpressionParser(this.source, this.variable);
  final String source; final String variable;
  _Expression parse() {
    final parts = source.trim();
    final or = _split(parts, ' or '); if (or != null) return _Binary(_ExpressionParser(or.$1, variable).parse(), 'or', _ExpressionParser(or.$2, variable).parse());
    final and = _split(parts, ' and '); if (and != null) return _Binary(_ExpressionParser(and.$1, variable).parse(), 'and', _ExpressionParser(and.$2, variable).parse());
    if (parts.startsWith('not ')) return _Not(_ExpressionParser(parts.substring(4), variable).parse());
    final match = RegExp(r'^(\w+)\.(\w+)\(\)$').firstMatch(parts);
    if (match == null || match[1] != variable) throw Faql4ValidationError('Invalid Core expression: $parts');
    return _Predicate(match[1]!, match[2]!);
  }
  (String, String)? _split(String value, String needle) {
    final index = value.indexOf(needle); return index < 0 ? null : (value.substring(0,index), value.substring(index + needle.length));
  }
}
