import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/hydration_settings.dart';
import '../providers/hydration_settings_provider.dart';

/// Settings page for hydration tracking.
///
/// Allows the user to enable/disable hydration tracking and set the daily
/// water intake target.
class HydrationSettingsPage extends ConsumerWidget {
  const HydrationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(hydrationSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hydration Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: settingsAsync.when(
        data: (settings) => _buildContent(context, ref, settings),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text(
            'Could not load hydration settings.',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    HydrationSettings settings,
  ) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SizedBox(height: AppSpacing.md),
        Text(
          'Hydration Tracking',
          style: AppTypography.title.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Enable or disable hydration tracking and set the daily '
          'water intake target.',
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        SwitchListTile(
          title: const Text('Enable hydration tracking'),
          subtitle: const Text(
            'Show hydration summary on the home page and track daily '
            'water intake.',
          ),
          value: settings.hydrationEnabled,
          onChanged: (value) async {
            await ref
                .read(hydrationSettingsRepositoryProvider)
                .updateSettings(settings.copyWith(hydrationEnabled: value));
          },
        ),
        const Divider(height: AppSpacing.md),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Daily Water Target',
          style: AppTypography.title.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Set your daily water intake target in milliliters.',
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildTargetSelector(ref, settings),
        const SizedBox(height: AppSpacing.md),
        const Divider(),
        const SizedBox(height: AppSpacing.md),
        Text(
          'About',
          style: AppTypography.title.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Systum is an offline-first productivity app. '
          'Hydration tracking data is stored locally on your device.',
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Widget _buildTargetSelector(WidgetRef ref, HydrationSettings settings) {
    final targetValues = [1000, 1500, 2000, 2500, 3000, 3500, 4000];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: targetValues.map((amount) {
        return FilterChip(
          label: Text('${amount ~/ 1000} L'),
          selected: settings.dailyTargetMl == amount,
          onSelected: (selected) async {
            await ref
                .read(hydrationSettingsRepositoryProvider)
                .updateSettings(settings.copyWith(dailyTargetMl: amount));
          },
          selectedColor: AppColors.primary.withValues(alpha: 0.12),
          checkmarkColor: AppColors.primary,
          labelStyle: TextStyle(
            color: settings.dailyTargetMl == amount
                ? AppColors.primary
                : AppColors.textSecondary,
            fontWeight: settings.dailyTargetMl == amount
                ? FontWeight.w600
                : FontWeight.w400,
          ),
          side: BorderSide(
            color: settings.dailyTargetMl == amount
                ? AppColors.primary
                : AppColors.textSecondary.withValues(alpha: 0.3),
          ),
        );
      }).toList(),
    );
  }
}
