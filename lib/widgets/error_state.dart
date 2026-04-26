import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

class ErrorState extends StatelessWidget {
  final String? message;
  final String? retryLabel;
  final VoidCallback onRetry;
  final IconData icon;

  const ErrorState({
    super.key,
    this.message,
    this.retryLabel,
    required this.onRetry,
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      liveRegion: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: AppColors.error.withValues(alpha: 0.8)),
              const SizedBox(height: AppSpacing.md),
              Text(message ?? l.somethingWentWrong,
                  style: AppTypography.body, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: retryLabel ?? l.retry,
                onPressed: onRetry,
                variant: AppButtonVariant.secondary,
                leadingIcon: Icons.refresh_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
