import 'package:flutter/material.dart';

/// Typography tokens for Hadi.
///
/// All styles use the app's default font family (Material 3 system font).
/// Colors are intentionally omitted — apply [AppColors] tokens or the active
/// theme's text theme via [Theme.of(context).textTheme] instead.
///
/// Naming follows a three-tier hierarchy:
///   display  → hero / splash numbers  (48 pt)
///   heading  → section titles (1–3)   (20 / 18 / 16 pt bold)
///   body     → readable prose         (16 / 13 pt)
///   caption  → meta, chips, labels    (12 / 11 pt)
abstract final class AppTypography {
  // ── Display ──────────────────────────────────────────────────────────────

  /// 48 pt bold — login / onboarding hero number or headline.
  static const TextStyle display = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.bold,
    height: 1.15,
    letterSpacing: -0.5,
  );

  // ── Headings ─────────────────────────────────────────────────────────────

  /// 20 pt bold — screen title, card hero text.
  static const TextStyle heading1 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    height: 1.3,
  );

  /// 18 pt bold — section heading inside a screen.
  static const TextStyle heading2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    height: 1.35,
  );

  /// 16 pt semi-bold — subsection or prominent label.
  static const TextStyle heading3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  // ── Body ─────────────────────────────────────────────────────────────────

  /// 16 pt regular — primary reading text.
  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );

  /// 16 pt medium — body text with emphasis, e.g. selected filter chips.
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  /// 13 pt regular — secondary detail lines (location, distance, etc.).
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    height: 1.45,
  );

  // ── Caption ──────────────────────────────────────────────────────────────

  /// 12 pt regular — meta text, chip labels, timestamps.
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    height: 1.4,
  );

  /// 12 pt semi-bold — badge / pill text on colored backgrounds.
  static const TextStyle captionBold = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.2,
  );

  /// 11 pt regular — smallest label, e.g. status chips at extremes.
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.normal,
    height: 1.35,
  );

  // ── TextTheme helper ─────────────────────────────────────────────────────

  /// Returns a [TextTheme] wired to [AppTypography] scales.
  ///
  /// Pass to [ThemeData.textTheme] so Material widgets inherit these sizes
  /// while still respecting user font-scale preferences.
  static TextTheme get textTheme => const TextTheme(
        displayLarge: display,
        titleLarge: heading1,
        titleMedium: heading2,
        titleSmall: heading3,
        bodyLarge: body,
        bodyMedium: bodySmall,
        labelLarge: bodyMedium,
        bodySmall: caption,
        labelSmall: labelSmall,
      );
}
