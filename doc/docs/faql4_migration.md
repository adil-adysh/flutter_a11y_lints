# Migrating to FAQL 4

FAQL 4 is a breaking change. The selector-based `rule/on/when/ensure/report`
format and its adapter-only properties have no runtime compatibility layer.
The generated bundle contains validated FAQL 4 Core queries only. Retain a
legacy source only while its policy is deferred and has neither a tested Core
replacement nor an explicit retirement decision. Candidate Core sources are
the policy reference for candidates; they do not need a duplicate legacy
source.

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

## Current bundled-query status

The CLI runs conservative queries by default. Expanded queries are present in
the catalog for an explicit expanded-mode consumer, but never contribute to
default diagnostics.

| Policy | FAQL 4 status | Boundary |
| --- | --- | --- |
| A01 unlabeled interactive controls | conservative | Proven exposed, enabled, unlabeled controls only. |
| A04 ListTile-leading network/file image | conservative | Exact leading slot, image source, inclusion, and effective-name evidence. |
| A22 ListTile under `MergeSemantics` | conservative | Direct semantic child only. |
| Multiple actions under `MergeSemantics` | conservative | Counts only branch-compatible, enabled interactive descendants. |
| A02 redundant role words | expanded | Static names from explicit sources; visible text-child labels are excluded. |
| A03 decorative images | expanded | Static decorative filename classification is a policy heuristic. |
| A05 redundant button semantics | expanded | Explicit `button: true` plus a direct material button and no other proven wrapper configuration. |
| A06 multi-part concept | expanded | Proven tap action, no proven merge, and two static-name descendants. |
| A07 replacement action | expanded | A replacement label must retain a tap action when it discards an actionable child. |
| A09 numeric names without units | expanded | Static bare numeric names only. |
| A15 custom gesture actions | expanded | Literal `GestureDetector.onTap` with a proven absent name only. |
| A04 CircleAvatar | candidate | Requires runtime-backed known-widget and naming semantics. |
| A13, A21, A99 | deferred | Their legacy conditions require additional reusable composite-role or source-graph facts, or a retirement decision. |

Do not treat a legacy source with a matching rule ID as an active query. The
generated bundle at `lib/rules/builtin_faql_rules.g.dart` is authoritative.

Legacy selectors and source-facing properties (`assetPath`, `childWidgetType`,
`hasButtonDescendant`, and count-specific adapter fields) have no compatibility
layer. Migrate them to standard views, typed primitive facts, and tree
relationships.
