import 'package:flutter/material.dart';

/// Spacing tokens for Hadi — 4 pt base grid.
///
/// Use these named constants everywhere instead of magic-number doubles so
/// that global spacing changes (e.g. compact / comfortable density) can be
/// applied in one place.
abstract final class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;

  /// Between [sm] and [md]. Covers the 12 pt card-internal padding common
  /// throughout the app.
  static const double smMd = 12.0;

  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // ── Convenience EdgeInsets ────────────────────────────────────────────────

  /// Uniform xs padding — 4 pt all sides.
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);

  /// Uniform sm padding — 8 pt all sides.
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);

  /// Uniform smMd padding — 12 pt all sides.
  static const EdgeInsets paddingSmMd = EdgeInsets.all(smMd);

  /// Uniform md padding — 16 pt all sides. Most common page / card padding.
  static const EdgeInsets paddingMd = EdgeInsets.all(md);

  /// Uniform lg padding — 24 pt all sides.
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);

  /// Standard horizontal page padding (md left + md right).
  static const EdgeInsets pagePadding =
      EdgeInsets.symmetric(horizontal: md);

  /// Inset for list items — smMd vertical, md horizontal.
  static const EdgeInsets listItemPadding =
      EdgeInsets.symmetric(horizontal: md, vertical: smMd);

  // ── Convenience SizedBox gaps ────────────────────────────────────────────

  static const SizedBox gapXs = SizedBox(height: xs);
  static const SizedBox gapSm = SizedBox(height: sm);
  static const SizedBox gapSmMd = SizedBox(height: smMd);
  static const SizedBox gapMd = SizedBox(height: md);
  static const SizedBox gapLg = SizedBox(height: lg);
  static const SizedBox gapXl = SizedBox(height: xl);

  static const SizedBox gapXsH = SizedBox(width: xs);
  static const SizedBox gapSmH = SizedBox(width: sm);
  static const SizedBox gapSmMdH = SizedBox(width: smMd);
  static const SizedBox gapMdH = SizedBox(width: md);
}
