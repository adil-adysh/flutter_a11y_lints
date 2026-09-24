# Migrating to FAQL 4

FAQL 4 is a breaking change. The selector-based `rule/on/when/ensure/report`
format and its adapter-only properties will be removed at the final migration
cutover. During migration, bundled rules still use legacy syntax and must not
be treated as FAQL 4 queries.

Rules now declare stable metadata and emit violation tuples:

```faql
@id flutter-a11y/a01/unlabeled-interactive
@rule-id a01_unlabeled_interactive
@severity warning
@mode conservative
from InteractiveControl control
where control.isDefinitelyEnabled() and control.isDefinitelyUnlabeled()
select control, "Interactive control must have an accessible label."
```

Use `queryId` (`@id`) as the unique catalog key. Several queries may share an
`@rule-id`. Conservative rules may only use facts proven exact or safely
derived; use predicates such as `isDefinitelyUnlabeled()` instead of negating
the partial `hasAccessibleLabel()` predicate. Expanded rules can consume
heuristic facts and must be explicitly marked `@mode expanded`.

Legacy selectors and source-facing properties (`assetPath`, `childWidgetType`,
`hasButtonDescendant`, and count-specific adapter fields) have no compatibility
layer. Migrate them to standard views, typed primitive facts, and tree
relationships.
