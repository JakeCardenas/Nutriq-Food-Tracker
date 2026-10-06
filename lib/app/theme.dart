import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Nutriq colour tokens: graphite surfaces, warm-white numbers, restrained
/// sage-green and amber accents.
abstract final class NqColors {
  static const background = Color(0xFF0F1012);
  static const surface = Color(0xFF18191C);
  static const raised = Color(0xFF212327);
  static const raisedHigh = Color(0xFF2A2C31);
  static const hairline = Color(0xFF2B2D31);

  static const textPrimary = Color(0xFFF5F5F2);
  static const textSecondary = Color(0xFFA3A6AB);
  static const textTertiary = Color(0xFF6E7277);

  /// Primary accent; also the protein colour.
  static const sage = Color(0xFF8BD8A0);

  /// Warm accent: carbs, estimate/demo labels, "above range".
  static const amber = Color(0xFFF0B357);

  /// Fat.
  static const periwinkle = Color(0xFF9DB4F0);

  /// Destructive actions only.
  static const coral = Color(0xFFF07A6A);

  static const protein = sage;
  static const carbs = amber;
  static const fat = periwinkle;
}

abstract final class NqSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  /// Horizontal page gutter.
  static const page = 20.0;
}

abstract final class NqRadius {
  static const card = 20.0;
  static const control = 14.0;
  static const chip = 10.0;
}

/// Type scale tuned like iOS: tight tracking on large text, tabular numbers.
abstract final class NqText {
  static const _tabular = [FontFeature.tabularFigures()];

  static const heroNumber = TextStyle(
    fontSize: 52,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.8,
    height: 1.0,
    color: NqColors.textPrimary,
    fontFeatures: _tabular,
  );
  static const largeTitle = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    height: 1.1,
    color: NqColors.textPrimary,
  );
  static const title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    height: 1.2,
    color: NqColors.textPrimary,
  );
  static const metric = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    height: 1.1,
    color: NqColors.textPrimary,
    fontFeatures: _tabular,
  );
  static const headline = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.25,
    color: NqColors.textPrimary,
  );
  static const body = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.2,
    height: 1.35,
    color: NqColors.textPrimary,
  );
  static const callout = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    height: 1.35,
    color: NqColors.textSecondary,
  );
  static const subhead = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.3,
    color: NqColors.textPrimary,
  );
  static const footnote = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: NqColors.textSecondary,
  );
  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.3,
    color: NqColors.textTertiary,
  );
  static const numberSmall = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: NqColors.textPrimary,
    fontFeatures: _tabular,
  );
}

bool isCupertino(BuildContext context) {
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
}

ThemeData buildNutriqTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: NqColors.sage,
    onPrimary: NqColors.background,
    secondary: NqColors.amber,
    onSecondary: NqColors.background,
    error: NqColors.coral,
    onError: NqColors.background,
    surface: NqColors.background,
    onSurface: NqColors.textPrimary,
    onSurfaceVariant: NqColors.textSecondary,
    surfaceContainerLowest: NqColors.background,
    surfaceContainerLow: NqColors.surface,
    surfaceContainer: NqColors.surface,
    surfaceContainerHigh: NqColors.raised,
    surfaceContainerHighest: NqColors.raisedHigh,
    outline: NqColors.textTertiary,
    outlineVariant: NqColors.hairline,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: NqColors.background,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.white.withValues(alpha: 0.04),
  );

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displayLarge: NqText.heroNumber,
      headlineLarge: NqText.largeTitle,
      titleLarge: NqText.title,
      titleMedium: NqText.headline,
      bodyLarge: NqText.body,
      bodyMedium: NqText.callout.copyWith(color: NqColors.textPrimary),
      bodySmall: NqText.footnote,
      labelLarge: NqText.subhead,
      labelSmall: NqText.caption,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: NqColors.background,
      foregroundColor: NqColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      titleTextStyle: NqText.headline,
    ),
    dividerTheme: const DividerThemeData(color: NqColors.hairline, thickness: 0.5, space: 0.5),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: NqColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: NqColors.textTertiary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: NqColors.raised,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: NqColors.raisedHigh,
      contentTextStyle: NqText.subhead,
      actionTextColor: NqColors.sage,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(NqRadius.control))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: NqColors.raised,
      hintStyle: NqText.body.copyWith(color: NqColors.textTertiary),
      labelStyle: NqText.callout,
      floatingLabelStyle: NqText.footnote.copyWith(color: NqColors.sage),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide.none,
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: NqColors.sage, width: 1),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: NqColors.coral, width: 1),
      ),
      errorStyle: NqText.footnote.copyWith(color: NqColors.coral),
      errorMaxLines: 3,
      helperMaxLines: 3,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: NqColors.sage,
      selectionHandleColor: NqColors.sage,
    ),
    cupertinoOverrideTheme: const CupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: NqColors.sage,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: NqColors.surface,
      indicatorColor: NqColors.sage.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll(NqText.caption.copyWith(color: NqColors.textSecondary)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: NqColors.sage),
  );
}
