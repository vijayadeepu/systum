import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/hydration_provider.dart';
import '../providers/hydration_settings_provider.dart';

/// Hydration summary card showing daily intake vs target.
///
/// Displays current intake, target, remaining amount, and quick-log buttons
/// for common amounts.
class HydrationSummary extends ConsumerWidget {
  const HydrationSummary({super.key, this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(hydrationSettingsProvider);
    final today = date != null
        ? DateTime.utc(date!.year, date!.month, date!.day)
        : DateTime.utc(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          );
    final totalMsAsync = ref.watch(hydrationTotalMsProvider(today));
    final targetMs = ref.watch(hydrationTargetMsProvider);
    final isTargetMetAsync = ref.watch(hydrationTargetMetProvider(today));

    return settingsAsync.when(
      data: (settings) {
        if (!settings.hydrationEnabled) {
          return const SizedBox.shrink();
        }
        return totalMsAsync.when(
          data: (totalMs) {
            return isTargetMetAsync.when(
              data: (isTargetMet) {
                return _buildContent(
                  context,
                  ref,
                  today,
                  totalMs,
                  targetMs,
                  isTargetMet,
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    DateTime today,
    int totalMs,
    int targetMs,
    bool isTargetMet,
  ) {
    final remainingMs = (targetMs - totalMs).clamp(0, targetMs);
    final fraction = targetMs == 0 ? 0.0 : (totalMs / targetMs).clamp(0.0, 1.0);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hydration',
                  style: AppTypography.title.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Expanded(
                  child: Text(
                    '${(totalMs / 1000).toStringAsFixed(1)} L / '
                    '${(targetMs / 1000).toStringAsFixed(1)} L',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: AppRadius.small,
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor: AppColors.textSecondary.withValues(
                  alpha: 0.12,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isTargetMet ? AppColors.success : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    isTargetMet
                        ? 'Target reached'
                        : '${(remainingMs / 1000).toStringAsFixed(1)} L remaining',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _QuickLogButton(amountMs: 250, date: today),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick-log button for a fixed hydration amount.
class _QuickLogButton extends ConsumerWidget {
  const _QuickLogButton({required this.amountMs, required this.date});

  final int amountMs;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      onPressed: () async {
        await ref.read(hydrationRepositoryProvider).logEntry(amountMs);
        if (!context.mounted) return;
        // ignore: unused_result
        ref.refresh(hydrationTotalMsProvider(date));
        // ignore: unused_result
        ref.refresh(hydrationTargetMetProvider(date));
      },
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
      ),
      icon: const Icon(Icons.local_drink, size: 16, color: Colors.white),
      label: Text('$amountMs ml'),
    );
  }
}
