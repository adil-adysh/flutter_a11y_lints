# CLI: flutter_a11y_lints

This document describes how to use the `a11y` CLI and the FAQL rules generator.

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

When building or compiling the CLI to a single binary, the analyzer needs the FAQL rule sources embedded into the package. Use the provided generator script to embed every `.faql` file from `lib/rules` into `lib/src/rules/builtin_faql_rules.g.dart`.

### Generate embedded rules

```powershell
# Ensure you have rules in lib\rules (create if needed)
mkdir -Force lib\rules

# Optional: add a sample rule
Set-Content -Path lib\rules\sample.faql -Value "rule \"test_rule\" on role(\"button\") { ensure: label.is_resolved report: \"Test\" }" -NoNewline

# Run the generator
dart run tool\generate_rules.dart
```

This will create or overwrite `lib/src/rules/builtin_faql_rules.g.dart` containing a `const Map<String, String> builtinFaqlRules` mapping filenames to their FAQL source.

## Notes

- The generator is deterministic (it sorts files) so generated output is stable for commits.
- If you add or modify `.faql` files, re-run the generator before compiling or publishing.

## Troubleshooting

- If the generator reports `Rules directory not found`, ensure `lib/rules` exists and contains `.faql` files.
- If your CLI code references FAQL files from the file system at runtime, prefer using `builtinFaqlRules` to avoid runtime FS dependencies when compiled as a binary.

---

If you want, I can also append a CLI section to the project root `README.md` or create a short `README` specifically in the `bin/` directory. Which would you prefer?