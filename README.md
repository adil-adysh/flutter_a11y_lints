# flutter_a11y_lints

A collection of lint rules to enforce accessibility best practices in Flutter applications.

## Installation

Add the following to your `analysis_options.yaml` file:

```yaml
analyzer:
  plugins:
    - custom_lint
```

Add the following to your `pubspec.yaml` file:

```yaml
dev_dependencies:
  flutter_a11y_lints:
    path: /path/to/flutter_a11y_lints
```

## Usage

The lints are enabled by default. You can disable them or change their severity in your `analysis_options.yaml` file.

```yaml
flutter_a11y_lints:
  enabled_groups:
    - flutter_a11y.core
    - flutter_a11y.recommended
  disabled_rules:
    - FLA09
    - FLA12
  severity_overrides:
    FLA10: info
    FLR01: info
```
