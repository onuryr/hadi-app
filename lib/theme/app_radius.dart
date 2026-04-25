import 'package:flutter/material.dart';

/// Border-radius tokens for Hadi.
///
/// Three-tier scale covers all surfaces found in the current codebase.
/// Use the [BorderRadius] getters for widget construction, or the raw
/// [double] constants when building custom painters.
abstract final class AppRadius {
  // ── Raw values ───────────────────────────────────────────────────────────

  /// 8 pt — small surfaces: badges, chips, small containers.
  static const double sm = 8.0;

  /// 12 pt — standard card / sheet corners. Most common in the codebase.
  static const double md = 12.0;

  /// 16 pt — large bottom-sheet tops and modal containers.
  static const double lg = 16.0;

  // ── Radius objects ───────────────────────────────────────────────────────

  static const Radius radiusSm = Radius.circular(sm);
  static const Radius radiusMd = Radius.circular(md);
  static const Radius radiusLg = Radius.circular(lg);

  // ── BorderRadius getters ─────────────────────────────────────────────────

  /// All corners — sm.
  static const BorderRadius borderSm = BorderRadius.all(radiusSm);

  /// All corners — md. Default for cards.
  static const BorderRadius borderMd = BorderRadius.all(radiusMd);

  /// All corners — lg.
  static const BorderRadius borderLg = BorderRadius.all(radiusLg);

  /// Top corners only — lg. Matches the bottom-sheet pattern in home_screen.
  static const BorderRadius borderTopLg = BorderRadius.vertical(top: radiusLg);

  /// Top corners only — md.
  static const BorderRadius borderTopMd = BorderRadius.vertical(top: radiusMd);
}
