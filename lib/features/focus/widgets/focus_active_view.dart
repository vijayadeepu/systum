import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../models/focus_session.dart';
import '../models/focus_session_mode.dart';
import '../models/focus_session_status.dart';
import '../models/pomodoro_cycle_state.dart';
import '../providers/focus_provider.dart';
import '../providers/pomodoro_provider.dart';

class FocusActiveView extends ConsumerStatefulWidget {
  const FocusActiveView({
    super.key,
    required this.transition,
    this.cycle,
    this.cycleError,
  });

  final FocusSessionTransition transition;
  final PomodoroCycleState? cycle;
  final String? cycleError;

  @override
  ConsumerState<FocusActiveView> createState() => _FocusActiveViewState();
}

class _FocusActiveViewState extends ConsumerState<FocusActiveView> {
  bool _isWorking = false;
  bool _showContinueMessage = true;

  @override
  Widget build(BuildContext context) {
    final session = widget.transition.session;
    final cycle = widget.cycle?.cycleId == session.cycleId
        ? widget.cycle
        : null;
    final elapsedState = ref.watch(focusElapsedDurationProvider);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            if (session.status == FocusSessionStatus.running &&
                _showContinueMessage)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.restore_rounded),
                  title: const Text('Your session is saved'),
                  subtitle: const Text(
                    'Elapsed time comes from recorded focus intervals.',
                  ),
                  trailing: TextButton(
                    onPressed: () =>
                        setState(() => _showContinueMessage = false),
                    child: const Text('Continue'),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Text(
              cycle != null && session.mode == FocusSessionMode.pomodoro
                  ? 'Focus'
                  : _modeLabel(session.mode),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (cycle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Round ${session.cycleRound} of 4',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (cycle.activeNextSegmentLabel case final nextLabel?) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(nextLabel, textAlign: TextAlign.center),
              ],
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(
              session.taskTitleSnapshot ?? 'Standalone focus session',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.xl),
            _timer(context, session, elapsedState),
            if (session.plannedDurationMs case final plannedMs?) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Planned duration: ${_formatDuration(plannedMs)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              session.status == FocusSessionStatus.running
                  ? 'Running'
                  : 'Paused',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (elapsedState.hasError)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(
                  'Could not calculate elapsed time: ${elapsedState.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (widget.cycleError != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(
                  'Could not load Pomodoro cycle: ${widget.cycleError}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
            _controls(session),
            if (cycle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                key: const ValueKey('exit-active-pomodoro-cycle'),
                onPressed: _isWorking ? null : _confirmExitCycle,
                icon: const Icon(Icons.exit_to_app_rounded),
                label: const Text('Exit cycle'),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              key: const ValueKey('interrupt-focus-session'),
              onPressed: _isWorking
                  ? null
                  : () => _run(
                      () => ref
                          .read(focusSessionProvider.notifier)
                          .interruptSession(session.id),
                    ),
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('End as interrupted'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timer(
    BuildContext context,
    FocusSession session,
    AsyncValue<int?> elapsedState,
  ) {
    if (elapsedState.isLoading) {
      return const SizedBox(
        height: 110,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (elapsedState.hasError || !elapsedState.hasValue) {
      return const SizedBox(
        height: 110,
        child: Center(child: Text('Timer unavailable')),
      );
    }

    final elapsedMs = elapsedState.requireValue ?? 0;
    final plannedMs = session.plannedDurationMs;
    final shownMs = plannedMs == null
        ? elapsedMs
        : (plannedMs - elapsedMs).clamp(0, plannedMs).toInt();
    final label = plannedMs == null ? 'Elapsed' : 'Remaining';
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          label: '$label ${_formatDuration(shownMs)}',
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _formatDuration(shownMs),
              key: const ValueKey('focus-timer'),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: 64,
                fontFeatures: const [],
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        if (plannedMs != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              '${_formatDuration(elapsedMs)} focused',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _controls(FocusSession session) {
    final notifier = ref.read(focusSessionProvider.notifier);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        FilledButton.icon(
          key: ValueKey(
            session.status == FocusSessionStatus.running
                ? 'pause-focus-session'
                : 'resume-focus-session',
          ),
          onPressed: _isWorking
              ? null
              : () => _run(
                  session.status == FocusSessionStatus.running
                      ? () => notifier.pauseSession(session.id)
                      : () => notifier.resumeSession(session.id),
                ),
          icon: Icon(
            session.status == FocusSessionStatus.running
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
          ),
          label: Text(
            session.status == FocusSessionStatus.running ? 'Pause' : 'Resume',
          ),
        ),
        FilledButton.tonalIcon(
          key: const ValueKey('complete-focus-session'),
          onPressed: _isWorking
              ? null
              : () => _run(() => notifier.completeSession(session.id)),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Complete'),
        ),
        OutlinedButton.icon(
          key: const ValueKey('cancel-focus-session'),
          onPressed: _isWorking ? null : () => _confirmCancel(session.id),
          icon: const Icon(Icons.close_rounded),
          label: const Text('Cancel'),
        ),
      ],
    );
  }

  Future<void> _confirmCancel(String sessionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this session?'),
        content: const Text(
          'The session will be saved as cancelled in your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep session'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel session'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _run(
        () => ref.read(focusSessionProvider.notifier).cancelSession(sessionId),
      );
    }
  }

  Future<void> _confirmExitCycle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit this Pomodoro cycle?'),
        content: const Text(
          'The current segment will be saved as cancelled, and all session '
          'history will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep cycle'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel segment and exit'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isWorking = true);
    try {
      await ref.read(pomodoroCycleProvider.notifier).exitCycle();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Could not exit the Pomodoro cycle: $error'),
            ),
          );
        await ref.read(focusSessionProvider.notifier).refresh();
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _run(Future<FocusSessionTransition> Function() action) async {
    if (_isWorking) return;
    setState(() => _isWorking = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Focus action failed: $error')),
          );
        await ref.read(focusSessionProvider.notifier).refresh();
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  static String _formatDuration(int milliseconds) {
    final totalSeconds = milliseconds ~/ Duration.millisecondsPerSecond;
    final hours = totalSeconds ~/ Duration.secondsPerHour;
    final minutes = (totalSeconds ~/ Duration.secondsPerMinute) % 60;
    final seconds = totalSeconds % Duration.secondsPerMinute;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  static String _modeLabel(FocusSessionMode mode) => switch (mode) {
    FocusSessionMode.standard => 'Standard focus',
    FocusSessionMode.pomodoro => 'Pomodoro',
    FocusSessionMode.shortBreak => 'Short break',
    FocusSessionMode.longBreak => 'Long break',
    FocusSessionMode.custom => 'Custom focus',
  };
}
