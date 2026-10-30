import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/focus_session.dart';
import '../models/focus_session_mode.dart';
import '../models/pomodoro_cycle_state.dart';
import '../models/pomodoro_settings.dart';
import '../repository/focus_session_repository_support.dart';
import '../repository/pomodoro_settings_store.dart';
import 'focus_provider.dart';

final pomodoroSettingsStoreProvider = Provider<PomodoroSettingsStore>(
  (ref) => PomodoroSettingsStore(),
);

final pomodoroSettingsProvider =
    AsyncNotifierProvider<PomodoroSettingsNotifier, PomodoroSettings>(
      PomodoroSettingsNotifier.new,
    );

final pomodoroCycleIdGeneratorProvider = Provider<String Function()>(
  (ref) => FocusSessionRepositorySupport.newUuid,
);

/// Reconstructs cycle progression from persisted Focus session history.
final pomodoroCycleProvider =
    AsyncNotifierProvider<PomodoroCycleNotifier, PomodoroCycleState?>(
      PomodoroCycleNotifier.new,
    );

class PomodoroSettingsNotifier extends AsyncNotifier<PomodoroSettings> {
  @override
  Future<PomodoroSettings> build() =>
      ref.read(pomodoroSettingsStoreProvider).load();

  Future<void> save(PomodoroSettings settings) async {
    try {
      await ref.read(pomodoroSettingsStoreProvider).save(settings);
      if (ref.mounted) state = AsyncData(settings);
    } catch (error, stackTrace) {
      if (ref.mounted) state = AsyncError(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

class PomodoroCycleNotifier extends AsyncNotifier<PomodoroCycleState?> {
  bool _isMutating = false;

  @override
  Future<PomodoroCycleState?> build() async {
    final history = await ref.watch(focusHistoryProvider.future);
    final settings = await ref.watch(pomodoroSettingsProvider.future);
    final dismissedIds = await ref
        .read(pomodoroSettingsStoreProvider)
        .loadDismissedCycleIds();
    return PomodoroCycleState.fromHistory(
      history,
      settings: settings,
      dismissedCycleIds: dismissedIds,
    );
  }

  Future<FocusSessionTransition> startCycle({String? taskId}) => _mutate(
    () async {
      final current = await _loadCycleState();
      if (current != null && !current.isComplete) {
        throw StateError('Exit or continue the current Pomodoro cycle first.');
      }
      final settings = await ref.read(pomodoroSettingsProvider.future);
      final cycleId = ref.read(pomodoroCycleIdGeneratorProvider)();
      final transition = await ref
          .read(focusSessionProvider.notifier)
          .startSession(
            taskId: taskId,
            mode: FocusSessionMode.pomodoro,
            plannedDurationMs: settings.focusDurationMs,
            cycleId: cycleId,
            cycleRound: 1,
          );
      await _refresh();
      return transition;
    },
  );

  Future<FocusSessionTransition> startNextSegment() => _mutate(() async {
    final current = await _loadCycleState();
    if (current == null || current.nextMode == null) {
      throw StateError('There is no Pomodoro segment ready to start.');
    }
    final settings = await ref.read(pomodoroSettingsProvider.future);
    final mode = current.nextMode!;
    final isFocus = mode == FocusSessionMode.pomodoro;
    final transition = await ref
        .read(focusSessionProvider.notifier)
        .startSession(
          taskId: isFocus ? current.taskId : null,
          taskIdSnapshot: isFocus ? current.taskIdSnapshot : null,
          taskTitleSnapshot: isFocus ? current.taskTitleSnapshot : null,
          mode: mode,
          plannedDurationMs: _durationFor(settings, mode),
          cycleId: current.cycleId,
          cycleRound: current.nextRound,
        );
    await _refresh();
    return transition;
  });

  Future<FocusSessionTransition> startNewCycle() => _mutate(() async {
    final current = await _loadCycleState();
    if (current != null && !current.isComplete) {
      throw StateError('Exit or continue the current Pomodoro cycle first.');
    }
    final settings = await ref.read(pomodoroSettingsProvider.future);
    final transition = await ref
        .read(focusSessionProvider.notifier)
        .startSession(
          taskId: current?.taskId,
          taskIdSnapshot: current?.taskIdSnapshot,
          taskTitleSnapshot: current?.taskTitleSnapshot,
          mode: FocusSessionMode.pomodoro,
          plannedDurationMs: settings.focusDurationMs,
          cycleId: ref.read(pomodoroCycleIdGeneratorProvider)(),
          cycleRound: 1,
        );
    await _refresh();
    return transition;
  });

  Future<void> exitCycle() => _mutate(() async {
    final current = await _loadCycleState();
    if (current == null) return;
    if (current.isActive) {
      await ref
          .read(focusSessionProvider.notifier)
          .cancelSession(current.lastSession.session.id);
    }
    await ref.read(pomodoroSettingsStoreProvider).dismissCycle(current.cycleId);
    await _refresh();
  });

  Future<PomodoroCycleState?> _loadCycleState() async {
    final history = await ref.read(focusRepositoryProvider).getHistory();
    final settings = await ref.read(pomodoroSettingsProvider.future);
    final dismissedIds = await ref
        .read(pomodoroSettingsStoreProvider)
        .loadDismissedCycleIds();
    return PomodoroCycleState.fromHistory(
      history,
      settings: settings,
      dismissedCycleIds: dismissedIds,
    );
  }

  Future<void> _refresh() async {
    try {
      final cycle = await _loadCycleState();
      if (ref.mounted) state = AsyncData(cycle);
    } catch (error, stackTrace) {
      if (ref.mounted) state = AsyncError(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<T> _mutate<T>(Future<T> Function() operation) async {
    if (_isMutating) throw const PomodoroMutationInProgressException();
    _isMutating = true;
    try {
      return await operation();
    } finally {
      _isMutating = false;
    }
  }

  static int _durationFor(PomodoroSettings settings, FocusSessionMode mode) =>
      switch (mode) {
        FocusSessionMode.pomodoro => settings.focusDurationMs,
        FocusSessionMode.shortBreak => settings.shortBreakDurationMs,
        FocusSessionMode.longBreak => settings.longBreakDurationMs,
        FocusSessionMode.standard || FocusSessionMode.custom =>
          throw StateError('Unsupported Pomodoro segment mode: $mode'),
      };
}

class PomodoroMutationInProgressException implements Exception {
  const PomodoroMutationInProgressException();

  @override
  String toString() =>
      'PomodoroMutationInProgressException: a cycle transition is in progress.';
}
