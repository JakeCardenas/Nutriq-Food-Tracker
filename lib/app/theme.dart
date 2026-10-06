import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Nutriq colour tokens — light canvas, white cards, near-black ink, black
/// pill actions, and three macro colours used consistently everywhere.
abstract final class NqColors {
  static const canvas = Color(0xFFF6F6F8);
  static const card = Color(0xFFFFFFFF);
  static const fill = Color(0xFFF2F2F5);
  static const fillPressed = Color(0xFFE8E8EE);
  static const hairline = Color(0xFFECECF0);
  static const track = Color(0xFFEEEEF3);

  static const ink = Color(0xFF111114);
  static const inkSoft = Color(0xFF1C1C20);
  static const textSecondary = Color(0xFF85858F);
  static const textTertiary = Color(0xFFB2B2BA);
  static const onInk = Color(0xFFFFFFFF);

  static const protein = Color(0xFFE46B5D);
  static const carbs = Color(0xFFE0A15E);
  static const fat = Color(0xFF5F8FE8);
  static const flame = Color(0xFFF08A3C);

  static const inRange = Color(0xFF2FA866);
  static const aboveRange = Color(0xFFEFA036);
  static const danger = Color(0xFFE5484D);

  static const demoFill = Color(0xFFFFF4E2);
  static const demoInk = Color(0xFFAA6A12);

  // Back-compat names used across the codebase.
  static const background = canvas;
  static const surface = card;
  static const raised = fill;
  static const raisedHigh = fillPressed;
  static const textPrimary = ink;
  static const sage = inRange;
  static const amber = aboveRange;
  static const coral = danger;
  static const periwinkle = fat;
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
  static const tile = 16.0;
  static const control = 14.0;
  static const chip = 12.0;
}

abstract final class NqShadow {
  static const card = [BoxShadow(color: Color(0x0D000000), blurRadius: 18, offset: Offset(0, 6))];
  static const floating = [BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 8))];
}

/// Type scale: bold, tight display text; tabular numbers for every value.
abstract final class NqText {
  static const _tabular = [FontFeature.tabularFigures()];

  static const heroNumber = TextStyle(
    fontSize: 44,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.6,
    height: 1.0,
    color: NqColors.ink,
    fontFeatures: _tabular,
  );
  static const largeTitle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.9,
    height: 1.12,
    color: NqColors.ink,
  );
  static const title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
    color: NqColors.ink,
  );
  static const metric = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.1,
    color: NqColors.ink,
    fontFeatures: _tabular,
  );
  static const headline = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.25,
    color: NqColors.ink,
  );
  static const body = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.3,
    height: 1.35,
    color: NqColors.ink,
  );
  static const callout = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    height: 1.4,
    color: NqColors.textSecondary,
  );
  static const subhead = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.3,
    color: NqColors.ink,
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
    color: NqColors.textSecondary,
  );
  static const numberSmall = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: NqColors.ink,
    fontFeatures: _tabular,
  );
}

bool isCupertino(BuildContext context) {
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
}

ThemeData buildNutriqTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: NqColors.ink,
    onPrimary: NqColors.onInk,
    secondary: NqColors.flame,
    onSecondary: NqColors.onInk,
    error: NqColors.danger,
    onError: NqColors.onInk,
    surface: NqColors.canvas,
    onSurface: NqColors.ink,
    onSurfaceVariant: NqColors.textSecondary,
    surfaceContainerLowest: NqColors.card,
    surfaceContainerLow: NqColors.card,
    surfaceContainer: NqColors.card,
    surfaceContainerHigh: NqColors.fill,
    surfaceContainerHighest: NqColors.fillPressed,
    outline: NqColors.textTertiary,
    outlineVariant: NqColors.hairline,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: NqColors.canvas,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.black.withValues(alpha: 0.03),
  );

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displayLarge: NqText.heroNumber,
      headlineLarge: NqText.largeTitle,
      titleLarge: NqText.title,
      titleMedium: NqText.headline,
      bodyLarge: NqText.body,
      bodyMedium: NqText.callout.copyWith(color: NqColors.ink),
      bodySmall: NqText.footnote,
      labelLarge: NqText.subhead,
      labelSmall: NqText.caption,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: NqColors.canvas,
      foregroundColor: NqColors.ink,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      titleTextStyle: NqText.headline,
    ),
    dividerTheme: const DividerThemeData(color: NqColors.hairline, thickness: 1, space: 1),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: NqColors.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: NqColors.textTertiary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: NqColors.card, surfaceTintColor: Colors.transparent),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: NqColors.ink,
      contentTextStyle: NqText.subhead.copyWith(color: NqColors.onInk),
      actionTextColor: NqColors.carbs,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(NqRadius.control))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: NqColors.fill,
      hintStyle: NqText.body.copyWith(color: NqColors.textTertiary),
      labelStyle: NqText.callout,
      floatingLabelStyle: NqText.footnote.copyWith(color: NqColors.ink, fontWeight: FontWeight.w600),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(NqRadius.control)),
        borderSide: BorderSide.none,
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(NqRadius.control)),
        borderSide: BorderSide(color: NqColors.ink, width: 1.2),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(NqRadius.control)),
        borderSide: BorderSide(color: NqColors.danger, width: 1),
      ),
      errorStyle: NqText.footnote.copyWith(color: NqColors.danger),
      errorMaxLines: 3,
      helperMaxLines: 3,
    ),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: NqColors.ink, selectionHandleColor: NqColors.ink),
    cupertinoOverrideTheme: const CupertinoThemeData(brightness: Brightness.light, primaryColor: NqColors.ink),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: NqColors.ink),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? NqColors.inRange : NqColors.fillPressed,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
  );
}
