abstract class FaqlExpression {}

class LiteralExpression extends FaqlExpression {
  final Object value;
  LiteralExpression(this.value);
  @override
  String toString() => 'Literal($value)';
}

class BooleanStateExpression extends FaqlExpression {
  final String name;
  BooleanStateExpression(this.name);
  @override
  String toString() => 'BoolState($name)';
}

class PropExpression extends FaqlExpression {
  final String name;
  final String? asType; // 'int'|'string'|'bool'
  final bool? isResolved;
  PropExpression(this.name, {this.asType, this.isResolved});
  @override
  String toString() => 'Prop($name, as:$asType, resolved:$isResolved)';
}

class UnaryExpression extends FaqlExpression {
  final String op;
  final FaqlExpression expr;
  UnaryExpression(this.op, this.expr);
  @override
  String toString() => 'Unary($op $expr)';
}

enum FaqlBinaryOp {
  and,
  or,
  add,
  subtract,
  multiply,
  divide,
  less,
  greater,
  lessEqual,
  greaterEqual,
  equals,
  notEquals,
  tildeEquals,
  contains,
  matches,
}

enum FaqlRelation {
  children,
  ancestors,
  siblings,
  nextFocus,
  prevFocus,
}

enum FaqlAggregator { any, all, none }

class BinaryExpression extends FaqlExpression {
  final FaqlExpression left;
  final FaqlBinaryOp op;
  final FaqlExpression right;
  BinaryExpression(this.left, this.op, this.right);
  @override
  String toString() => 'Binary($left $op $right)';
}

class RegexMatchExpression extends FaqlExpression {
  final FaqlExpression left;
  final RegExp pattern;
  RegexMatchExpression(this.left, this.pattern);
  @override
  String toString() => 'RegexMatch($left, ${pattern.pattern})';
}

class AggregatorExpression extends FaqlExpression {
  final FaqlRelation relation; // children/ancestors/siblings/next_focus/prev_focus
  final FaqlAggregator aggregator; // any/all/none
  final FaqlExpression expr;
  AggregatorExpression(this.relation, this.aggregator, this.expr);
  @override
  String toString() => 'Aggregator($relation.$aggregator($expr))';
}

class RelationLengthExpression extends FaqlExpression {
  final FaqlRelation relation;
  RelationLengthExpression(this.relation);
  @override
  String toString() => 'Length($relation)';
}

class Identifier extends FaqlExpression {
  final String name;
  Identifier(this.name);
  @override
  String toString() => 'Identifier($name)';
}

class FaqlSelector {}

class AnySelector extends FaqlSelector {}

class RoleSelector extends FaqlSelector {
  final String role;
  RoleSelector(this.role);
}

class TypeSelector extends FaqlSelector {
  final String type;
  TypeSelector(this.type);
}

class KindSelector extends FaqlSelector {
  final String kind;
  KindSelector(this.kind);
}

class FaqlRule {
  final String name;
  final List<FaqlSelector> selectors;
  final Map<String, String> meta;
  final FaqlExpression? when;
  final FaqlExpression ensure;
  final String report;

  FaqlRule(
      {required this.name,
      required this.selectors,
      required this.meta,
      this.when,
      required this.ensure,
      required this.report});

  @override
  String toString() =>
      'FaqlRule($name, selectors:$selectors, meta:$meta, when:$when, ensure:$ensure, report:$report)';
}
