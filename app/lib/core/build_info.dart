/// Facts about this build.
library;

/// The version people see in Settings. Keep it in step with `version:` in
/// pubspec.yaml (a test checks).
const appVersion = '1.0.0';

/// The test lab is for test builds only: pass `--dart-define=PEEL_LAB=true`
/// to include it. Store builds leave it out, and its code with it.
const showTestLab = bool.fromEnvironment('PEEL_LAB');
