import 'package:flutter/material.dart';
import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/theme/tokens.dart';

/// Display face for headings and hero numbers (Space Grotesk, OFL, bundled).
const kDisplayFont = 'SpaceGrotesk';

/// Text styles. Variable fonts need an explicit weight axis.
abstract final class KText {
  /// Headings, reactor IDs and hero numbers.
  static TextStyle display(double size, {FontWeight weight = FontWeight.w600, Color? color}) => TextStyle(
    fontFamily: kDisplayFont,
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation.weight(weight.value.toDouble())],
    fontFeatures: const [FontFeature.tabularFigures()],
    color: color ?? KColors.textPrimary,
    height: 1.1,
    letterSpacing: -0.3,
  );

  static TextStyle ui(double size, {FontWeight weight = FontWeight.w400, Color? color}) => TextStyle(
    fontFamily: KFont.ui,
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation.weight(weight.value.toDouble())],
    color: color ?? KColors.textPrimary,
    height: 1.35,
  );

  /// Tabular monospace numerals for every number shown.
  static TextStyle mono(double size, {FontWeight weight = FontWeight.w400, Color? color}) => TextStyle(
    fontFamily: KFont.mono,
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation.weight(weight.value.toDouble())],
    fontFeatures: const [FontFeature.tabularFigures()],
    color: color ?? KColors.textPrimary,
    height: 1.2,
  );

  /// Tiny uppercase overline (11-12 px, 0.06em tracking).
  static TextStyle overline({Color? color}) => ui(
    KSize.xs - 1,
    weight: FontWeight.w500,
    color: color ?? KColors.textMuted,
  ).copyWith(letterSpacing: 0.66);
}

Color stateColor(HealthState s) => switch (s) {
  HealthState.normal => KColors.stateHealthy,
  HealthState.watch => KColors.stateWatch,
  HealthState.alarm => KColors.stateAlarm,
};

String stateLabel(HealthState s) => switch (s) {
  HealthState.normal => 'Healthy',
  HealthState.watch => 'Watch',
  HealthState.alarm => 'Alarm',
};

Color provenanceColor(Provenance p) => switch (p) {
  Provenance.measured => KColors.provenanceMeasured,
  Provenance.published => KColors.provenancePublished,
  Provenance.assumed || Provenance.fitted => KColors.provenanceAssumed,
  Provenance.synthetic => KColors.provenanceSynthetic,
};

/// Theme for the active palette (`KColors.palette`); call after switching palettes.
ThemeData kairosTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = (dark ? ColorScheme.dark : ColorScheme.light)(
    primary: KColors.accentX500,
    onPrimary: KColors.bgBase,
    secondary: KColors.accentX600,
    surface: KColors.bgSurface,
    onSurface: KColors.textPrimary,
    error: KColors.stateAlarm,
    outline: KColors.borderStrong,
    outlineVariant: KColors.borderSubtle,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: KFont.ui,
  );
  return base.copyWith(
    scaffoldBackgroundColor: KColors.bgBase,
    textTheme: base.textTheme.apply(bodyColor: KColors.textPrimary, displayColor: KColors.textPrimary),
    appBarTheme: AppBarTheme(
      backgroundColor: KColors.bgBase,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: KText.ui(KSize.lg, weight: FontWeight.w500),
    ),
    dividerTheme: DividerThemeData(color: KColors.borderSubtle, thickness: 1, space: 1),
    cardTheme: CardThemeData(
      color: KColors.bgSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(KRadius.card)),
        side: BorderSide(color: KColors.borderSubtle),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KColors.bgInset,
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(KRadius.control)),
        borderSide: BorderSide(color: KColors.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(KRadius.control)),
        borderSide: BorderSide(color: KColors.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(KRadius.control)),
        borderSide: BorderSide(color: KColors.accentX500, width: 1.5),
      ),
      labelStyle: TextStyle(color: KColors.textSecondary),
      hintStyle: TextStyle(color: KColors.textMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: KColors.accentX500,
        foregroundColor: KColors.bgBase,
        minimumSize: const Size.fromHeight(48),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(KRadius.control))),
        textStyle: KText.ui(KSize.md, weight: FontWeight.w500),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: KColors.textPrimary,
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: KColors.borderStrong),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(KRadius.control))),
        textStyle: KText.ui(KSize.md, weight: FontWeight.w500),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: KColors.bgElevated,
      contentTextStyle: KText.ui(KSize.md),
      behavior: SnackBarBehavior.floating,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
  );
}
