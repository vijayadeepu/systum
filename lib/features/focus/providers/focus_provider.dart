import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/database_provider.dart';
import '../models/focus_session.dart';
import '../models/focus_session_duration.dart';
import '../models/focus_session_mode.dart';
import '../models/focus_session_status.dart';
import '../repository/focus_repository.dart';
import 'focus_clock_provider.dart';

final focusRepositoryProvider = Provider<FocusRepository>((ref) {
  return FocusRepository(ref.watch(databaseProvider));
});

/// SQLite-backed unresolved session and its lifecycle mutations.
final focusSessionProvider =
    AsyncNotifierProvider<FocusSessionNotifier, FocusSessionTransition?>(
      FocusSessionNotifier.new,
    );

/// Persisted session history; lifecycle mutations invalidate this query.
final focusHistoryProvider = FutureProvider<List<FocusSessionTransition>>((
  ref,
) {
  return ref.watch(focusRepositoryProvider).getHistory();
});

/// Elapsed active milliseconds for the current unresolved session.
///
/// Running duration uses the display clock as the end of the persisted open
/// interval. Paused duration is evaluated at the persisted update timestamp,
/// so display ticks cannot change it.
final focusElapsedDurationProvider = Provider.autoDispose<AsyncValue<int?>>((
  ref,
) {
  final sessionState = ref.watch(focusSessionProvider);
  if (sessionState case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  if (!sessionState.hasValue) return const AsyncLoading();

  final transition = sessionState.requireValue;
  if (transition == null) return const AsyncData(null);

  final session = transition.session;
  final atMs = session.status == FocusSessionStatus.running
      ? ref.watch(focusClockProvider).toUtc().millisecondsSinceEpoch
      : session.updatedAtMs;
  return AsyncData(
    FocusSessionDuration.elapsedActiveMilliseconds(
      intervals: transition.intervals,
      atMs: atMs,
    ),
  );
});

class FocusSessionNotifier extends AsyncNotifier<FocusSessionTransition?> {
  late final FocusRepository _repository = ref.read(focusRepositoryProvider);
  AppLifecycleListener? _lifecycleListener;
  bool _isMutating = false;
  bool _refreshAfterMutation = false;
  int _loadRevision = 0;

  @override
  Future<FocusSessionTransition?> build() async {
    _lifecycleListener?.dispose();
    _lifecycleListener = AppLifecycleListener(
      onResume: () => unawaited(refresh()),
    );
    ref.onDispose(() => _lifecycleListener?.dispose());
    return _repository.getUnresolvedSession();
  }

  /// Re-reads persisted state after resume or explicit refresh.
  Future<void> refresh() async {
    if (_isMutating) {
      _refreshAfterMutation = true;
      return;
    }
    final revision = ++_loadRevision;
    state = const AsyncLoading<FocusSessionTransition?>();
    final result = await AsyncValue.guard(_repository.getUnresolvedSession);
    if (ref.mounted && revision == _loadRevision) state = result;
  }

  Future<FocusSessionTransition> startSession({
    String? taskId,
    String? taskIdSnapshot,
    String? taskTitleSnapshot,
    required FocusSessionMode mode,
    int? plannedDurationMs,
    String? cycleId,
    int? cycleRound,
  }) {
    return _mutate(() {
      return _repository.startSession(
        taskId: taskId,
        taskIdSnapshot: taskIdSnapshot,
        taskTitleSnapshot: taskTitleSnapshot,
        mode: mode,
        startedAtMs: _nowMs(),
        plannedDurationMs: plannedDurationMs,
        cycleId: cycleId,
        cycleRound: cycleRound,
      );
    });
  }

  Future<FocusSessionTransition> pauseSession(String id) =>
      _mutate(() => _repository.pauseSession(id, atMs: _nowMs()));

  Future<FocusSessionTransition> resumeSession(String id) =>
      _mutate(() => _repository.resumeSession(id, atMs: _nowMs()));

  Future<FocusSessionTransition> completeSession(String id) =>
      _mutate(() => _repository.completeSession(id, atMs: _nowMs()));

  Future<FocusSessionTransition> cancelSession(String id) =>
      _mutate(() => _repository.cancelSession(id, atMs: _nowMs()));

  Future<FocusSessionTransition> interruptSession(String id) =>
      _mutate(() => _repository.interruptSession(id, atMs: _nowMs()));

  Future<FocusSessionTransition> _mutate(
    Future<FocusSessionTransition> Function() operation,
  ) async {
    if (_isMutating) throw const FocusMutationInProgressException();
    _isMutating = true;
    final revision = ++_loadRevision;
    state = const AsyncLoading<FocusSessionTransition?>();
    try {
      final transition = await operation();
      if (!ref.mounted) return transition;
      if (revision == _loadRevision) {
        state = transition.session.status.isTerminal
            ? AsyncData(await _repository.getUnresolvedSession())
            : AsyncData(transition);
      }
      ref.invalidate(focusHistoryProvider);
      return transition;
    } catch (error, stackTrace) {
      if (ref.mounted && revision == _loadRevision) {
        state = AsyncError(error, stackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      _isMutating = false;
      if (ref.mounted && _refreshAfterMutation) {
        _refreshAfterMutation = false;
        await refresh();
      }
    }
  }

  int _nowMs() =>
      ref.read(focusSystemClockProvider)().toUtc().millisecondsSinceEpoch;
}

class FocusMutationInProgressException implements Exception {
  const FocusMutationInProgressException();

  @override
  String toString() =>
      'FocusMutationInProgressException: a focus mutation is already running.';
}
