import 'package:material_ui/material_ui.dart';

import 'tokens.dart';
import 'typography.dart';

/// App-wide Material theme. Most screens draw their own die-cut pieces; the
/// theme keeps stock widgets (dialogs, text fields, snackbars) on brand.
ThemeData buildPeelTheme() {
  final dark = PeelColors.dark;
  final scheme = ColorScheme(
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: PeelColors.ink,
    onPrimary: PeelColors.surface,
    secondary: PeelColors.electric,
    onSecondary: PeelColors.white,
    surface: PeelColors.surface,
    onSurface: PeelColors.ink,
    error: const Color(0xFFB42318),
    onError: PeelColors.white,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: PeelColors.paper,
    splashFactory: InkRipple.splashFactory,
    textTheme: TextTheme(
      displayLarge: PeelType.display(),
      headlineLarge: PeelType.title(),
      titleLarge: PeelType.label(),
      bodyLarge: PeelType.body(color: PeelColors.ink),
      bodyMedium: PeelType.body(),
      bodySmall: PeelType.caption(),
      labelLarge: PeelType.button(),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: PeelColors.ink,
      contentTextStyle: PeelType.button().copyWith(fontSize: 15),
      behavior: SnackBarBehavior.floating,
      shape: const StadiumBorder(),
    ),
  );
}
