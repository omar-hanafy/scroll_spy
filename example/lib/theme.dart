import 'package:flutter/material.dart';

/// Palette for the showcase.
///
/// The status colors deliberately mirror the defaults in
/// `ScrollSpyDebugConfig` so that a legend drawn in Dart lines up with the
/// colors the built-in debug overlay paints.
abstract final class SpyColors {
  /// App background (near-black).
  static const Color bg = Color(0xFF070908);

  /// Base surface for cards and sheets.
  static const Color surface = Color(0xFF0B0E0C);

  /// Elevated surface (controls, chips).
  static const Color surfaceHigh = Color(0xFF161B17);

  /// Hairline stroke (white at low opacity).
  static const Color stroke = Color(0xFF252B26);

  /// Brand signal green.
  static const Color accent = Color(0xFF4DF477);

  /// Secondary brand foreground.
  static const Color accent2 = Color(0xFFF2F5EF);

  /// Muted foreground for secondary text.
  static const Color muted = Color(0xFF9CA59D);

  // --- Focus-state colors (aligned with ScrollSpyDebugConfig defaults) ---

  /// Primary / "playing" winner (system green).
  static const Color primary = Color(0xFF34C759);

  /// Focused / "ready" (system yellow).
  static const Color focused = Color(0xFFFFCC00);

  /// Visible in viewport (system blue).
  static const Color visible = Color(0xFF007AFF);

  /// Focus region band (system red).
  static const Color region = Color(0xFFFF3B30);
}

/// Builds the single dark theme used across the showcase.
ThemeData buildShowcaseTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: SpyColors.accent,
    brightness: Brightness.dark,
  ).copyWith(surface: SpyColors.surface);

  final ThemeData base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: SpyColors.bg,
    splashFactory: InkSparkle.splashFactory,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: SpyColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: SpyColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: SpyColors.stroke),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerColor: SpyColors.stroke,
    textTheme: base.textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: SpyColors.accent,
      thumbColor: SpyColors.accent,
      overlayColor: SpyColors.accent.withValues(alpha: 0.15),
      inactiveTrackColor: SpyColors.surfaceHigh,
      trackHeight: 3,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? SpyColors.accent
            : SpyColors.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? SpyColors.accent.withValues(alpha: 0.35)
            : SpyColors.surfaceHigh,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
  );
}
