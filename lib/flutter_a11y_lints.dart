/// Flutter accessibility analyzer built on semantic IR and FAQL 4 facts.
library;

export 'src/facts/fact_store.dart';
export 'src/facts/semantic_fact_extractor.dart';
export 'src/pipeline/semantic_ir_builder.dart';
export 'src/query/faql4.dart';
export 'src/semantics/known_semantics.dart';
export 'src/semantics/semantic_builder.dart';
export 'src/semantics/semantic_context.dart';
export 'src/semantics/semantic_neighborhood.dart';
export 'src/semantics/semantic_node.dart';
export 'src/semantics/semantic_tree.dart';
export 'src/widget_tree/widget_node.dart';
export 'rules/faql_rule_catalog.dart';
export 'rules/faql_rule_runner.dart';
