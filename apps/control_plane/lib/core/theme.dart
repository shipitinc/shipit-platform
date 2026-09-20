import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Builds the two themes defined by the Penpot design.
///
/// The design is deliberately flat: no elevation, no Material surface tints,
/// 1px hairlines and 3px radii. Material defaults that would contradict that
/// (shadows, tinted surfaces, 40px+ touch inflation on links) are switched off
/// here rather than fought in every widget.
class ShipItTheme {
  ShipItTheme._();

  static ThemeData light() => _build(ShipItPalette.light, Brightness.light);

  static ThemeData dark() => _build(ShipItPalette.dark, Brightness.dark);

  static ThemeData _build(ShipItPalette palette, Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);

    return base.copyWith(
      extensions: [palette],
      scaffoldBackgroundColor: palette.canvas,
      canvasColor: palette.canvas,
      colorScheme: base.colorScheme.copyWith(
        brightness: brightness,
        primary: palette.accent,
        onPrimary: brightness == Brightness.light
            ? const Color(0xFFFFFFFF)
            : const Color(0xFF10110F),
        surface: palette.canvas,
        onSurface: palette.inkPrimary,
        outline: palette.rule,
        error: palette.negative,
      ),
      // The design applies no surface tint or shadow anywhere.
      applyElevationOverlayColor: false,
      shadowColor: const Color(0x00000000),
      splashFactory: NoSplash.splashFactory,
      dividerTheme: DividerThemeData(
        color: palette.rule,
        thickness: ShipItMetrics.hairline,
        space: 0,
      ),
      dividerColor: palette.rule,
      textTheme: _textTheme(palette),
      // `Gate Btn`: outlined, 3px radius, hairline border, Sans 11/500.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.inkPrimary,
          backgroundColor: const Color(0x00000000),
          side: BorderSide(
            color: palette.controlBorder,
            width: ShipItMetrics.hairline,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ShipItMetrics.radius),
          ),
          textStyle: ShipItType.link,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 24),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          elevation: 0,
        ),
      ),
      // Filled primary action, e.g. `Approve` / `Save my decision`.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: brightness == Brightness.light
              ? const Color(0xFFFFFFFF)
              : const Color(0xFF10110F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ShipItMetrics.radius),
          ),
          textStyle: ShipItType.link,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 28),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.accent,
          textStyle: ShipItType.link,
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.card,
        hintStyle: ShipItType.bodySmall.copyWith(color: palette.inkTertiary),
        contentPadding: const EdgeInsets.all(10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ShipItMetrics.radius),
          borderSide: BorderSide(color: palette.controlBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ShipItMetrics.radius),
          borderSide: BorderSide(color: palette.controlBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ShipItMetrics.radius),
          borderSide: BorderSide(color: palette.accent),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: palette.card,
          border: Border.all(color: palette.cardBorder),
          borderRadius: BorderRadius.circular(ShipItMetrics.radius),
        ),
        textStyle: ShipItType.monoMeta.copyWith(color: palette.inkSecondary),
      ),
    );
  }

  /// Maps the design's type ramp onto the Material slots so unstyled text
  /// inherits something from the design rather than Roboto 14.
  static TextTheme _textTheme(ShipItPalette palette) {
    final ink = palette.inkPrimary;
    final second = palette.inkSecondary;
    final third = palette.inkTertiary;
    return TextTheme(
      headlineLarge: ShipItType.pageTitle.copyWith(color: ink),
      headlineMedium: ShipItType.pageTitle.copyWith(color: ink),
      titleLarge: ShipItType.sectionTitle.copyWith(color: ink),
      titleMedium: ShipItType.sectionTitleSmall.copyWith(color: ink),
      titleSmall: ShipItType.microLabel.copyWith(color: third),
      bodyLarge: ShipItType.rowTitle.copyWith(color: ink),
      bodyMedium: ShipItType.bodySmall.copyWith(color: second),
      bodySmall: ShipItType.bodyMicro.copyWith(color: third),
      labelLarge: ShipItType.link.copyWith(color: palette.accent),
      labelMedium: ShipItType.ref.copyWith(color: second),
      labelSmall: ShipItType.microLabel.copyWith(color: third),
    );
  }
}

/// Convenience accessor so widgets read design tokens instead of guessing.
extension ShipItThemeX on BuildContext {
  ShipItPalette get palette =>
      Theme.of(this).extension<ShipItPalette>() ?? ShipItPalette.light;
}
