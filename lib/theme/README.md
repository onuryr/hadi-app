# Hadi Design System — Token Reference

Import everything with one line:

```dart
import 'package:hadi_app/theme/theme.dart';
```

---

## AppColors

Semantic color tokens aligned with Material 3.  
For in-widget access, prefer `Theme.of(context).colorScheme`.  
Use `AppColors` constants for static tints, chart fills, and overlays.

```dart
// Primary brand color
Container(color: AppColors.primaryContainer)

// Error feedback
Icon(Icons.warning, color: AppColors.error)

// Success indicator
Icon(Icons.check_circle, color: AppColors.success)

// Image overlay scrim (replaces Colors.black.withValues(alpha: 0.6))
Container(color: AppColors.imageScrim)

// Star rating fill
Icon(Icons.star, color: AppColors.starFilled)
```

### Token table

| Token | Value | Usage |
|---|---|---|
| `primary` | `#6750A4` | Buttons, FABs, active nav |
| `onPrimary` | `#FFFFFF` | Text/icons on primary |
| `primaryContainer` | `#EADDFF` | Chip backgrounds, selected state |
| `onPrimaryContainer` | `#21005D` | Text/icons on primaryContainer |
| `surface` | `#FFFBFE` | Screen background |
| `surfaceVariant` | `#E7E0EC` | Card/input fill |
| `onSurface` | `#1C1B1F` | Primary body text |
| `onSurfaceVariant` | `#49454F` | Secondary / hint text |
| `outline` | `#79747E` | Dividers, unfocused borders |
| `outlineVariant` | `#CAC4D0` | Subtle dividers, empty stars |
| `error` | `#B3261E` | Error text/icon |
| `errorContainer` | `#F9DEDC` | Error background chip |
| `success` | `#146C2E` | Success text/icon |
| `successContainer` | `#C3EFCD` | Success background chip |
| `warning` | `#7D5700` | Warning text/icon |
| `warningContainer` | `#FFDEAB` | Warning background chip |
| `imageScrim` | `#99000000` | 60% black overlay on images |
| `starFilled` | `#FFC107` | Filled star in ratings |
| `starEmpty` | `#CAC4D0` | Empty star in ratings |

Each light token has a `*Dark` counterpart (e.g. `primaryDark`, `surfaceDark`).

---

## AppSpacing

4 pt base grid. Use named tokens — never raw doubles.

```dart
// Vertical gap between form fields
AppSpacing.gapMd  // SizedBox(height: 16)

// Card internal padding
Padding(padding: AppSpacing.paddingSmMd)  // EdgeInsets.all(12)

// Page horizontal inset
Padding(padding: AppSpacing.pagePadding)  // EdgeInsets.symmetric(horizontal: 16)

// Inline horizontal gap
Row(children: [Icon(Icons.place), AppSpacing.gapSmH, Text(location)])
```

### Token table

| Token | Value | Typical usage |
|---|---|---|
| `xs` | 4 pt | Inline icon–label gap, tiny vertical rhythm |
| `sm` | 8 pt | Between related list items, tight card internals |
| `smMd` | 12 pt | Card padding, chip horizontal padding |
| `md` | 16 pt | Standard screen padding, form field gap |
| `lg` | 24 pt | Section separator, dialog padding |
| `xl` | 32 pt | Hero sections, generous inset |
| `xxl` | 48 pt | Full-bleed splash spacing |

---

## AppTypography

```dart
// Screen title
Text('Aktiviteler', style: AppTypography.heading1)

// Card title
Text(activity.name, style: AppTypography.heading3)

// Body copy
Text(activity.description, style: AppTypography.body)

// Distance / location meta
Text('2.3 km', style: AppTypography.bodySmall)

// Chip label
Text('Spor', style: AppTypography.caption)

// Badge on image
Text('Ücretsiz', style: AppTypography.captionBold.copyWith(color: AppColors.onPrimary))

// Wiring into ThemeData
ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
  useMaterial3: true,
  textTheme: AppTypography.textTheme,
)
```

### Token table

| Token | Size | Weight | Usage |
|---|---|---|---|
| `display` | 48 | bold | Login hero, splash numbers |
| `heading1` | 20 | bold | Screen / AppBar title |
| `heading2` | 18 | bold | Section heading |
| `heading3` | 16 | w600 | Subsection / card title |
| `body` | 16 | regular | Primary reading text |
| `bodyMedium` | 16 | w500 | Emphasized body (selected filter) |
| `bodySmall` | 13 | regular | Secondary detail (location, date) |
| `caption` | 12 | regular | Chip label, timestamp, meta |
| `captionBold` | 12 | w600 | Badge / pill on colored background |
| `labelSmall` | 11 | regular | Smallest status label |

---

## AppRadius

```dart
// Standard card
Card(
  shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
)

// Bottom sheet
Container(
  decoration: BoxDecoration(borderRadius: AppRadius.borderTopLg),
)

// Badge chip
Container(
  decoration: BoxDecoration(borderRadius: AppRadius.borderSm),
)
```

### Token table

| Token | Value | Usage |
|---|---|---|
| `sm` / `borderSm` | 8 pt | Badges, chips, small containers |
| `md` / `borderMd` | 12 pt | Cards (default) |
| `lg` / `borderLg` | 16 pt | Large modals, sheets |
| `borderTopLg` | top 16 pt | Bottom sheet corners |
| `borderTopMd` | top 12 pt | Peek-up card corners |

---

## Hardcoded Values Inventory (refactor target)

This section lists every magic number found in the January 2026 scan.
A dedicated refactor task will replace these with the tokens above.

### Colors

| Hardcoded value | Replacement token | Occurrences | Files |
|---|---|---|---|
| `Colors.deepPurple` | `AppColors.primary` | 9 | main, home_screen, login_screen |
| `Colors.grey` | `AppColors.onSurfaceVariant` | 17 | multiple |
| `Colors.grey.shade200` | `AppColors.surfaceVariant` | 7 | home, activity_detail, create_activity, profile |
| `Colors.grey.shade100` | `AppColors.surface` | 1 | home_screen |
| `Colors.white` | `AppColors.onPrimary` / `AppColors.surface` | 6 | multiple |
| `Colors.red` | `AppColors.error` | 4 | activity_detail, home |
| `Colors.red.shade100` | `AppColors.errorContainer` | 1 | activity_detail |
| `Colors.red.shade800` | `AppColors.onErrorContainer` | 1 | activity_detail |
| `Colors.amber` | `AppColors.starFilled` | 2 | star_rating, profile |
| `Colors.black.withValues(alpha: 0.6)` | `AppColors.imageScrim` | 2 | home_screen |
| `Colors.black54` | `AppColors.onSurfaceVariant` | 1 | create_activity |

### Spacing

| Raw value | Replacement | Occurrences | Notes |
|---|---|---|---|
| `4` | `AppSpacing.xs` | 2 | small vertical gaps |
| `6` | between `xs` and `sm` — review callsite | 2 | consider xs or sm |
| `8` | `AppSpacing.sm` | 11+ | very common |
| `10` | between `sm` and `smMd` — review | 4 | consider sm |
| `12` | `AppSpacing.smMd` | 8 | card internal padding |
| `14` | round to `smMd` (12) or `md` (16) | 1 | odd one-off |
| `16` | `AppSpacing.md` | 30+ | most common |
| `20` | `md` + `xs` — review | 1 | profile card padding |
| `24` | `AppSpacing.lg` | 2 | form gaps |
| `48` | `AppSpacing.xxl` | 1 | login |

### Typography

| Raw value | Replacement | Occurrences |
|---|---|---|
| `fontSize: 48` | `AppTypography.display` | 1 |
| `fontSize: 20, bold` | `AppTypography.heading1` | 2 |
| `fontSize: 18, bold` | `AppTypography.heading2` | 2 |
| `fontSize: 16, w600` | `AppTypography.heading3` | 1 |
| `fontSize: 16, bold` | `AppTypography.heading3` | 2 |
| `fontSize: 16` | `AppTypography.body` | 4 |
| `fontSize: 13` | `AppTypography.bodySmall` | 1 |
| `fontSize: 12` | `AppTypography.caption` | 6 |
| `fontSize: 12, w600` | `AppTypography.captionBold` | 2 |
| `fontSize: 11` | `AppTypography.labelSmall` | 1 |

### Border Radius

| Raw value | Replacement | Occurrences | Files |
|---|---|---|---|
| `BorderRadius.circular(12)` | `AppRadius.borderMd` | 7 | activity_detail, create_activity, home, map_picker |
| `BorderRadius.circular(8)` | `AppRadius.borderSm` | 1 | profile |
| `BorderRadius.vertical(top: Radius.circular(16))` | `AppRadius.borderTopLg` | 1 | home_screen |
