import 'package:flutter/material.dart';

/// Semantic color tokens for Hadi.
///
/// Light/dark values align with the Material 3 ColorScheme generated from
/// [Colors.deepPurple] via [ColorScheme.fromSeed]. Use these tokens when you
/// need a direct color reference outside of the active theme's ColorScheme
/// (e.g. static icon tints, chart fills, overlay scrim). For everything else,
/// prefer [Theme.of(context).colorScheme].
abstract final class AppColors {
  // ── Brand / Primary ──────────────────────────────────────────────────────
  static const Color primary = Color(0xFF6750A4);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFEADDFF);
  static const Color onPrimaryContainer = Color(0xFF21005D);

  // ── Surface / Neutral ────────────────────────────────────────────────────
  static const Color surface = Color(0xFFFFFBFE);
  static const Color surfaceVariant = Color(0xFFE7E0EC);
  static const Color onSurface = Color(0xFF1C1B1F);
  static const Color onSurfaceVariant = Color(0xFF49454F);
  static const Color outline = Color(0xFF79747E);
  static const Color outlineVariant = Color(0xFFCAC4D0);

  // ── Error ────────────────────────────────────────────────────────────────
  static const Color error = Color(0xFFB3261E);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFF9DEDC);
  static const Color onErrorContainer = Color(0xFF410E0B);

  // ── Success ──────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF146C2E);
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color successContainer = Color(0xFFC3EFCD);
  static const Color onSuccessContainer = Color(0xFF002111);

  // ── Warning ──────────────────────────────────────────────────────────────
  static const Color warning = Color(0xFF7D5700);
  static const Color onWarning = Color(0xFFFFFFFF);
  static const Color warningContainer = Color(0xFFFFDEAD);
  static const Color onWarningContainer = Color(0xFF261900);

  // ── Dark variants ────────────────────────────────────────────────────────
  static const Color primaryDark = Color(0xFFD0BCFF);
  static const Color onPrimaryDark = Color(0xFF381E72);
  static const Color primaryContainerDark = Color(0xFF4F378B);
  static const Color onPrimaryContainerDark = Color(0xFFEADDFF);

  static const Color surfaceDark = Color(0xFF1C1B1F);
  static const Color onSurfaceDark = Color(0xFFE6E1E5);
  static const Color surfaceVariantDark = Color(0xFF49454F);
  static const Color outlineDark = Color(0xFF938F99);

  static const Color errorDark = Color(0xFFF2B8B5);
  static const Color onErrorDark = Color(0xFF601410);
  static const Color errorContainerDark = Color(0xFF8C1D18);
  static const Color onErrorContainerDark = Color(0xFFF9DEDC);

  // ── Utility / Shared ─────────────────────────────────────────────────────
  static const Color transparent = Color(0x00000000);
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);

  /// Semi-transparent scrim for image overlays (replaces Colors.black.withValues(alpha: 0.6)).
  static const Color imageScrim = Color(0x99000000);

  /// Star / rating fill — amber 600.
  static const Color starFilled = Color(0xFFFFC107);

  /// Star / rating empty track.
  static const Color starEmpty = Color(0xFFCAC4D0);

  /// Muted text/icon color for empty states and placeholders.
  static const Color textMuted = Color(0xFF9E9E9E);

  /// Shimmer skeleton animation base color.
  static const Color shimmerBase = Color(0xFFE0E0E0);

  /// Shimmer skeleton animation highlight color.
  static const Color shimmerHighlight = Color(0xFFF5F5F5);
}
