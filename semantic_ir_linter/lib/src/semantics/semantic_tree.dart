import 'semantic_node.dart';

/// Minimal semantic tree representation for v1.
class SemanticTree {
  SemanticTree._({
    required this.root,
    required this.physicalNodes,
    required this.accessibilityFocusNodes,
  });

  final SemanticNode root;
  final List<SemanticNode> physicalNodes;
  final List<SemanticNode> accessibilityFocusNodes;

  static SemanticTree fromRoot(SemanticNode root) {
    final physical = <SemanticNode>[];
    final focusable = <SemanticNode>[];

    void visit(SemanticNode node) {
      physical.add(node);
      if (node.isFocusable && node.isEnabled) {
        focusable.add(node);
      }
      for (final child in node.children) {
        visit(child);
      }
    }

    visit(root);
    return SemanticTree._(
      root: root,
      physicalNodes: physical,
      accessibilityFocusNodes: focusable,
    );
  }
}
