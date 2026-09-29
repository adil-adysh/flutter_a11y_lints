# CLI: flutter_a11y_lints

This document describes how to use the `a11y` CLI and the FAQL 4 rules generator.

## Install

From the repository root, you can run the CLI directly with Dart:

```powershell
# Run the CLI
dart run bin\a11y.dart --help
```

To activate globally (optional):

```powershell
# Activate globally (if you want the `a11y` command available system-wide)
dart pub global activate --source path .
```

After activation you can run:

```powershell
a11y --help
```

## Embedding FAQL rules

When building or compiling the CLI to a single binary, the analyzer needs the
FAQL 4 Core rule sources embedded into the package. Use the generator to
compile every validated `.faql` file from `lib/rules/core` into the canonical
`lib/rules/builtin_faql_rules.g.dart` bundle.

### Generate embedded rules

```powershell
# Core sources live in lib\rules\core.
mkdir -Force lib\rules\core

# Optional: add a FAQL 4 sample rule after the built-in rule migration
@'
@id example/unlabeled-control
@rule-id example_unlabeled_control
@severity warning
@mode conservative
from InteractiveControl control
where control.isDefinitelyEnabled() and control.isDefinitelyUnlabeled()
select control, "Interactive control must have an accessible label."
'@ | Set-Content -Path lib\rules\core\example_unlabeled_control.faql -NoNewline

# Run the generator
dart run tool\generate_rules.dart
```

This creates or overwrites `lib/rules/builtin_faql_rules.g.dart`, containing a
read-only `List<CompiledQuery> builtinFaqlRules`. The generator rejects legacy
selector/`ensure` sources. Do not edit the generated file manually.

## Notes

- The generator is deterministic (it sorts files) so generated output is stable for commits.
- Re-run the generator only after changing a coherent, validated rule corpus.
- FAQL 4 is a breaking language change. For the query format and migration
  guidance, see [FAQL 4 migration](docs/faql4_migration.md).

## Troubleshooting

- If the generator reports `Rules directory not found`, ensure
  `lib/rules/core` exists and contains validated Core `.faql` files.
- The generated `builtinFaqlRules` artifact avoids runtime file-system
  dependencies when the CLI is compiled as a binary.

---

If you want, I can also append a CLI section to the project root `README.md` or create a short `README` specifically in the `bin/` directory. Which would you prefer?
