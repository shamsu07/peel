# Contributing to Peel

Thanks for helping. Peel aims to be small, fast and simple, so the best
changes are often the ones that remove steps or words.

## Before you start

- For anything bigger than a small fix, open an issue first so we can agree
  on the approach.
- Check `docs/spec/` and `docs/adr/` for the decisions behind the app.

## Set up

```bash
cd app
flutter pub get
flutter test
```

See the [README](README.md#-build-it) for tool versions.

## Making a change

1. Fork, then branch from `main`.
2. Keep changes focused; one topic per pull request.
3. Run before pushing:
   ```bash
   cd app
   dart format lib test hook
   flutter analyze
   flutter test
   ```
4. Add or update tests for behaviour changes.
5. For UI changes, add before and after screenshots in light and dark mode.

CI runs the same checks and builds both apps.

## Style

- Follow the Dart style guide and the lints in `analysis_options.yaml`.
- Comments explain why, not what.
- UI text is short and plain. Use colours, type and spacing from
  `lib/core/design/` rather than new values.
- Don't add analytics, tracking or network calls. Everything stays on the
  device.

## Commit messages

Short imperative summary line, then a blank line and the why if it isn't
obvious.

## Code of conduct

By taking part you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
