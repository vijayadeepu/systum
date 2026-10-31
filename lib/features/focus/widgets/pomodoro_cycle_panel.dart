import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../models/focus_session_mode.dart';
import '../models/focus_session_status.dart';
import '../models/pomodoro_cycle_state.dart';
import '../models/pomodoro_settings.dart';
import '../providers/pomodoro_provider.dart';

class PomodoroCyclePanel extends ConsumerStatefulWidget {
  const PomodoroCyclePanel({super.key, required this.cycle});

  final PomodoroCycleState cycle;

  @override
  ConsumerState<PomodoroCyclePanel> createState() => _PomodoroCyclePanelState();
}

class _PomodoroCyclePanelState extends ConsumerState<PomodoroCyclePanel> {
  bool _isWorking = false;

  @override
  Widget build(BuildContext context) {
    final cycle = widget.cycle;
    final session = cycle.lastSession.session;
    final title = cycle.isComplete
        ? 'Pomodoro cycle complete'
        : cycle.requiresRecovery
        ? 'Session ${_statusLabel(session.status)}'
        : '${_segmentLabel(session.mode)} complete';
    final subtitle = cycle.isComplete
        ? 'You completed all ${PomodoroSettings.focusRoundsBeforeLongBreak} focus rounds and the long break.'
        : cycle.requiresRecovery
        ? 'This segment did not advance the cycle. '
              'Round ${cycle.round} remains available to retry.'
        : cycle.nextMode == FocusSessionMode.pomodoro
        ? 'Next: Focus — Round ${cycle.nextRound} of ${PomodoroSettings.focusRoundsBeforeLongBreak}.'
        : 'Next: ${_segmentLabel(cycle.nextMode!)} after round ${cycle.round}.';
    final buttonLabel = cycle.isComplete
        ? 'Start a new cycle'
        : cycle.requiresRecovery
        ? 'Retry ${_segmentLabel(cycle.nextMode!)}'
        : 'Start ${_segmentLabel(cycle.nextMode!)}';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          margin: const EdgeInsets.all(AppSpacing.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (cycle.nextPlannedDurationMs != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Planned: ${cycle.nextPlannedDurationMs! ~/ Duration.millisecondsPerMinute} minutes',
                    textAlign: TextAlign.center,
                  ),
                ],
                if (cycle.taskTitleSnapshot != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Task: ${cycle.taskTitleSnapshot}',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  key: const ValueKey('start-next-pomodoro-segment'),
                  onPressed: _isWorking ? null : _startNext,
                  icon: _isWorking
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(_isWorking ? 'Starting…' : buttonLabel),
                ),
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton(
                  key: const ValueKey('exit-pomodoro-cycle'),
                  onPressed: _isWorking ? null : _exit,
                  child: const Text('Exit cycle'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startNext() async {
    setState(() => _isWorking = true);
    try {
      if (widget.cycle.isComplete) {
        await ref.read(pomodoroCycleProvider.notifier).startNewCycle();
      } else {
        await ref.read(pomodoroCycleProvider.notifier).startNextSegment();
      }
    } catch (error) {
      _showError('Could not start the next Pomodoro segment: $error');
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _exit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit this Pomodoro cycle?'),
        content: const Text(
          'Your session history will be kept. You can start a new cycle later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep cycle'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Exit cycle'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isWorking = true);
    try {
      await ref.read(pomodoroCycleProvider.notifier).exitCycle();
    } catch (error) {
      _showError('Could not exit the Pomodoro cycle: $error');
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static String _statusLabel(FocusSessionStatus status) => switch (status) {
    FocusSessionStatus.cancelled => 'cancelled',
    FocusSessionStatus.interrupted => 'interrupted',
    _ => 'ended',
  };

  static String _segmentLabel(FocusSessionMode mode) => switch (mode) {
    FocusSessionMode.pomodoro => 'Focus',
    FocusSessionMode.shortBreak => 'Short break',
    FocusSessionMode.longBreak => 'Long break',
    FocusSessionMode.standard || FocusSessionMode.custom => throw StateError(
      'Unsupported Pomodoro segment mode: $mode',
    ),
  };
}
