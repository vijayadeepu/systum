import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../providers/focus_provider.dart';
import '../providers/pomodoro_provider.dart';
import '../widgets/focus_active_view.dart';
import '../widgets/pomodoro_cycle_panel.dart';
import '../widgets/focus_setup_view.dart';

class FocusPage extends ConsumerWidget {
  const FocusPage({super.key, this.initialTaskId});

  final String? initialTaskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(focusSessionProvider);
    final cycleState = ref.watch(pomodoroCycleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Focus')),
      body: SafeArea(
        child: sessionState.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Loading focus session',
            ),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Could not load your focus session.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SelectableText(error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: () =>
                        ref.read(focusSessionProvider.notifier).refresh(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (transition) {
            if (transition != null) {
              return FocusActiveView(
                transition: transition,
                cycle: cycleState.asData?.value,
                cycleError: cycleState.hasError
                    ? cycleState.error.toString()
                    : null,
              );
            }
            return cycleState.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Loading Pomodoro cycle',
                ),
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Could not load your Pomodoro cycle.'),
                      const SizedBox(height: AppSpacing.sm),
                      SelectableText(error.toString()),
                      TextButton(
                        onPressed: () => ref.invalidate(pomodoroCycleProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (cycle) => switch (cycle) {
                final cycle? when cycle.nextMode != null || cycle.isComplete =>
                  PomodoroCyclePanel(cycle: cycle),
                final cycle? when cycle.isActive => const Center(
                  child: Text('Recovering your Pomodoro session…'),
                ),
                _ => FocusSetupView(initialTaskId: initialTaskId),
              },
            );
          },
        ),
      ),
    );
  }
}
