import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  const ErrorState({
    super.key,
    this.message = 'Bir şeyler ters gitti.',
    required this.onRetry,
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
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
              Text(message, style: AppTypography.body, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Tekrar Dene',
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
