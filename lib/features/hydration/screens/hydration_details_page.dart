import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/hydration_entry.dart';
import '../providers/hydration_provider.dart';
import '../providers/hydration_settings_provider.dart';

/// Hydration details page showing water intake level as a cylinder visualization.
///
/// Displays current intake vs target with a cylinder graphic representing the
/// water level, plus Drink (log 250 ml) and Undo (delete most recent entry)
/// buttons.
class HydrationDetailsPage extends ConsumerStatefulWidget {
  const HydrationDetailsPage({super.key});

  @override
  ConsumerState<HydrationDetailsPage> createState() =>
      _HydrationDetailsPageState();
}

class _HydrationDetailsPageState extends ConsumerState<HydrationDetailsPage> {
  DateTime get today => DateTime.utc(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(hydrationSettingsProvider);
    final totalMsAsync = ref.watch(hydrationTotalMsProvider(today));
    final targetMs = ref.watch(hydrationTargetMsProvider);
    final isTargetMetAsync = ref.watch(hydrationTargetMetProvider(today));
    final entriesAsync = ref.watch(hydrationEntriesProvider(today));

    return settingsAsync.when(
      data: (settings) {
        if (!settings.hydrationEnabled) {
          return const Center(child: Text('Hydration tracking is disabled.'));
        }
        return totalMsAsync.when(
          data: (totalMs) {
            return isTargetMetAsync.when(
              data: (isTargetMet) {
                return entriesAsync.when(
                  data: (entries) {
                    return _buildContent(
                      context,
                      totalMs,
                      targetMs,
                      isTargetMet,
                      entries,
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const Center(
                    child: Text('Could not load hydration entries.'),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) =>
                  const Center(child: Text('Could not load hydration target.')),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Center(child: Text('Could not load hydration intake.')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          const Center(child: Text('Could not load hydration settings.')),
    );
  }

  Widget _buildContent(
    BuildContext context,
    int totalMs,
    int targetMs,
    bool isTargetMet,
    List<HydrationEntry> entries,
  ) {
    final remainingMs = (targetMs - totalMs).clamp(0, targetMs);
    final fraction = targetMs == 0 ? 0.0 : (totalMs / targetMs).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hydration'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.md),
            Text(
              'Daily Water Intake',
              style: AppTypography.title.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${(totalMs / 1000).toStringAsFixed(1)} L / '
              '${(targetMs / 1000).toStringAsFixed(1)} L',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Cylinder visualization: less than 60% of screen height.
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: Column(
                children: [
                  Expanded(
                    child: _CylinderGraphic(
                      fraction: fraction,
                      isFull: isTargetMet,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    isTargetMet
                        ? 'Target reached'
                        : '${(remainingMs / 1000).toStringAsFixed(1)} L remaining',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Drink and Undo buttons.
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      await ref.read(hydrationRepositoryProvider).logEntry(250);
                      if (!mounted) return;
                      // ignore: unused_result
                      ref.refresh(hydrationTotalMsProvider(today));
                      // ignore: unused_result
                      ref.refresh(hydrationTargetMetProvider(today));
                      // ignore: unused_result
                      ref.refresh(hydrationEntriesProvider(today));
                    },
                    icon: const Icon(Icons.local_drink, size: 18),
                    label: const Text('Drink 250 ml'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: entries.isEmpty
                        ? null
                        : () async {
                            // Undo: delete the most recent entry.
                            final latest = entries.reduce(
                              (a, b) => a.loggedAtMs > b.loggedAtMs ? a : b,
                            );
                            await ref
                                .read(hydrationRepositoryProvider)
                                .deleteEntry(latest.id);
                            if (!mounted) return;
                            // ignore: unused_result
                            ref.refresh(hydrationTotalMsProvider(today));
                            // ignore: unused_result
                            ref.refresh(hydrationTargetMetProvider(today));
                            // ignore: unused_result
                            ref.refresh(hydrationEntriesProvider(today));
                          },
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    label: const Text('Undo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Entry list.
            if (entries.isNotEmpty) ...[
              const Text(
                'Today\'s Entries',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ..._buildEntryList(entries),
            ],
          ],
        ),
      ),
    );
  }
}

/// A cylinder graphic showing water fill level.
///
/// [fraction] is a value from 0.0 to 1.0 representing fill level.
/// [isFull] indicates whether the target has been met.
class _CylinderGraphic extends StatelessWidget {
  const _CylinderGraphic({required this.fraction, required this.isFull});

  final double fraction;
  final bool isFull;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _CylinderPainter(fraction: fraction, isFull: isFull),
    );
  }
}

/// Draws a cylinder with water fill level.
class _CylinderPainter extends CustomPainter {
  _CylinderPainter({required this.fraction, required this.isFull});

  final double fraction;
  final bool isFull;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final topY = 20.0;
    final bottomY = size.height - 40.0;
    final radiusX = size.width * 0.35;
    final radiusY = 20.0;

    // Paint colors
    final cylinderColor = AppColors.textSecondary.withValues(alpha: 0.2);
    final waterColor = isFull ? AppColors.success : AppColors.primary;

    // Draw cylinder back ellipse (top)
    _drawEllipse(
      canvas,
      Offset(centerX, topY),
      radiusX,
      radiusY,
      cylinderColor,
    );

    // Draw cylinder back ellipse (bottom)
    _drawEllipse(
      canvas,
      Offset(centerX, bottomY),
      radiusX,
      radiusY,
      cylinderColor,
    );

    // Draw cylinder sides
    final path = Path();
    path.moveTo(centerX - radiusX, topY);
    path.lineTo(centerX - radiusX, bottomY);
    path.arcToPoint(
      Offset(centerX + radiusX, bottomY),
      radius: Radius.elliptical(radiusX, radiusY),
      clockwise: false,
    );
    path.lineTo(centerX + radiusX, topY);
    path.arcToPoint(
      Offset(centerX - radiusX, topY),
      radius: Radius.elliptical(radiusX, radiusY),
      clockwise: false,
    );
    canvas.drawPath(path, Paint()..color = cylinderColor);

    // Draw water fill if fraction > 0
    if (fraction > 0.005) {
      final waterHeight = (bottomY - topY - 2 * radiusY) * fraction;
      final waterBottom = bottomY - radiusY;
      final waterTop = waterBottom - waterHeight;

      // Water body path
      final waterPath = Path();
      waterPath.moveTo(centerX - radiusX, waterTop);
      waterPath.lineTo(centerX - radiusX, waterBottom - radiusY);
      waterPath.arcToPoint(
        Offset(centerX + radiusX, waterBottom - radiusY),
        radius: Radius.elliptical(radiusX, radiusY),
        clockwise: false,
      );
      waterPath.lineTo(centerX + radiusX, waterTop);
      waterPath.close();
      canvas.drawPath(
        waterPath,
        Paint()..color = waterColor.withValues(alpha: 0.9),
      );

      // Water surface ellipse
      _drawEllipse(
        canvas,
        Offset(centerX, waterTop),
        radiusX,
        radiusY * 0.5,
        waterColor.withValues(alpha: 0.4),
      );
    }

    // Draw top rim arc
    final topPath = Path();
    topPath.moveTo(centerX - radiusX, topY);
    topPath.arcToPoint(
      Offset(centerX + radiusX, topY),
      radius: Radius.elliptical(radiusX, radiusY),
      clockwise: true,
    );
    canvas.drawPath(
      topPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.textSecondary.withValues(alpha: 0.6),
    );
  }

  void _drawEllipse(
    Canvas canvas,
    Offset center,
    double radiusX,
    double radiusY,
    Color color,
  ) {
    final paint = Paint()..color = color;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radiusX * 2, height: radiusY * 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CylinderPainter old) =>
      old.fraction != fraction || old.isFull != isFull;
}

List<Widget> _buildEntryList(List<HydrationEntry> entries) {
  final sorted = List.of(entries)
    ..sort((a, b) => b.loggedAtMs.compareTo(a.loggedAtMs));
  return sorted.map((entry) {
    final time = DateTime.fromMillisecondsSinceEpoch(
      entry.loggedAtMs,
      isUtc: true,
    ).toLocal();
    return ListTile(
      leading: const Icon(Icons.local_drink_rounded, color: AppColors.primary),
      title: Text('${entry.amountMs} ml'),
      subtitle: Text(
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}',
        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
      ),
    );
  }).toList();
}
