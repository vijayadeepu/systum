import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../models/focus_session.dart';
import '../models/focus_session_interval.dart';
import '../models/focus_session_mode.dart';
import '../models/focus_session_status.dart';
import 'focus_repository_exceptions.dart';
import 'focus_session_repository_support.dart';

export 'focus_repository_exceptions.dart';

typedef _SessionTransitionOperation =
    FocusSessionTransition Function(
      FocusSession session,
      List<FocusSessionInterval> intervals,
      int atMs,
    );

/// Persists focus sessions and their intervals as one transactional aggregate.
///
/// Lifecycle changes are the only supported session updates. This keeps
/// terminal session and interval history immutable through repository calls.
class FocusRepository {
  const FocusRepository(this._database);

  final SystumDatabase _database;

  /// Starts a session, capturing a task's ID and title at the same time.
  ///
  /// The task snapshot and session/interval writes are committed together.
  Future<FocusSessionTransition> startSession({
    String? taskId,
    String? taskIdSnapshot,
    String? taskTitleSnapshot,
    required FocusSessionMode mode,
    required int startedAtMs,
    int? plannedDurationMs,
    String? cycleId,
    int? cycleRound,
  }) {
    return _database.transaction(() async {
      final unresolved = await _unresolvedSessionRow();
      if (unresolved != null) {
        throw FocusSessionAlreadyUnresolvedException(unresolved.id);
      }

      String? capturedTaskTitleSnapshot;
      if (taskId != null) {
        final task = await (_database.select(
          _database.tasks,
        )..where((row) => row.id.equals(taskId))).getSingleOrNull();
        if (task == null) {
          throw FocusTaskNotFoundException(taskId);
        }
        capturedTaskTitleSnapshot = task.title;
      } else if ((taskIdSnapshot == null) != (taskTitleSnapshot == null)) {
        throw ArgumentError(
          'Task snapshot ID and title must either both be set or both be null.',
        );
      } else {
        capturedTaskTitleSnapshot = taskTitleSnapshot;
      }

      final transition = FocusSession.start(
        id: FocusSessionRepositorySupport.newUuid(),
        taskId: taskId,
        taskIdSnapshot: taskId ?? taskIdSnapshot,
        taskTitleSnapshot: capturedTaskTitleSnapshot,
        mode: mode,
        startedAtMs: startedAtMs,
        plannedDurationMs: plannedDurationMs,
        cycleId: cycleId,
        cycleRound: cycleRound,
      );

      await _database
          .into(_database.focusSessions)
          .insert(
            FocusSessionRepositorySupport.sessionCompanion(transition.session),
          );
      await _database
          .into(_database.focusSessionIntervals)
          .insert(
            FocusSessionRepositorySupport.intervalCompanion(
              FocusSessionRepositorySupport.newUuid(),
              transition.intervals.single,
            ),
          );

      return transition;
    });
  }

  /// Retrieves a session with its validated intervals, or null if absent.
  Future<FocusSessionTransition?> getById(String id) {
    return _database.transaction(() async {
      final session = await (_database.select(
        _database.focusSessions,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      if (session == null) return null;

      final intervals = await _intervalRowsFor({id});
      return FocusSessionRepositorySupport.transitionFromRows(
        session,
        intervals,
      );
    });
  }

  /// Returns the single running or paused session, if one exists.
  Future<FocusSessionTransition?> getUnresolvedSession() {
    return _database.transaction(() async {
      final session = await _unresolvedSessionRow();
      if (session == null) return null;

      final intervals = await _intervalRowsFor({session.id});
      return FocusSessionRepositorySupport.transitionFromRows(
        session,
        intervals,
      );
    });
  }

  /// Returns session history newest first, with deterministic tie ordering.
  Future<List<FocusSessionTransition>> getHistory() {
    return _database.transaction(() async {
      final sessions =
          await (_database.select(_database.focusSessions)..orderBy([
                (row) => OrderingTerm.desc(row.startedAtMs),
                (row) => OrderingTerm.desc(row.id),
              ]))
              .get();
      if (sessions.isEmpty) return const [];

      final intervalRows = await _intervalRowsFor(
        sessions.map((session) => session.id).toSet(),
      );
      final intervalsBySession = <String, List<FocusSessionIntervalRow>>{};
      for (final interval in intervalRows) {
        intervalsBySession
            .putIfAbsent(interval.sessionId, () => [])
            .add(interval);
      }

      return [
        for (final session in sessions)
          FocusSessionRepositorySupport.transitionFromRows(
            session,
            intervalsBySession[session.id] ?? const [],
          ),
      ];
    });
  }

  Future<FocusSessionTransition> pauseSession(String id, {required int atMs}) =>
      _applyTransition(
        id,
        atMs,
        (session, intervals, time) =>
            session.pause(intervals: intervals, atMs: time),
      );

  Future<FocusSessionTransition> resumeSession(
    String id, {
    required int atMs,
  }) => _applyTransition(
    id,
    atMs,
    (session, intervals, time) =>
        session.resume(intervals: intervals, atMs: time),
  );

  Future<FocusSessionTransition> completeSession(
    String id, {
    required int atMs,
  }) => _applyTransition(
    id,
    atMs,
    (session, intervals, time) =>
        session.complete(intervals: intervals, atMs: time),
  );

  Future<FocusSessionTransition> cancelSession(
    String id, {
    required int atMs,
  }) => _applyTransition(
    id,
    atMs,
    (session, intervals, time) =>
        session.cancel(intervals: intervals, atMs: time),
  );

  Future<FocusSessionTransition> interruptSession(
    String id, {
    required int atMs,
  }) => _applyTransition(
    id,
    atMs,
    (session, intervals, time) =>
        session.interrupt(intervals: intervals, atMs: time),
  );

  Future<FocusSessionTransition> _applyTransition(
    String id,
    int atMs,
    _SessionTransitionOperation operation,
  ) {
    return _database.transaction(() async {
      final row = await (_database.select(
        _database.focusSessions,
      )..where((session) => session.id.equals(id))).getSingleOrNull();
      if (row == null) throw FocusSessionNotFoundException(id);

      final intervalRows = await _intervalRowsFor({id});
      final current = FocusSessionRepositorySupport.transitionFromRows(
        row,
        intervalRows,
      );
      final next = operation(current.session, current.intervals, atMs);

      if (current.session.status == FocusSessionStatus.running &&
          next.session.status != FocusSessionStatus.running) {
        final openRow = intervalRows.singleWhere(
          (interval) => interval.endedAtMs == null,
        );
        final updatedIntervals =
            await (_database.update(_database.focusSessionIntervals)..where(
                  (interval) =>
                      interval.id.equals(openRow.id) &
                      interval.sessionId.equals(id) &
                      interval.endedAtMs.isNull(),
                ))
                .write(FocusSessionIntervalsCompanion(endedAtMs: Value(atMs)));
        if (updatedIntervals != 1) {
          throw FocusSessionIntegrityException(
            id,
            'The open interval changed during the transition.',
          );
        }
      } else if (current.session.status == FocusSessionStatus.paused &&
          next.session.status == FocusSessionStatus.running) {
        await _database
            .into(_database.focusSessionIntervals)
            .insert(
              FocusSessionRepositorySupport.intervalCompanion(
                FocusSessionRepositorySupport.newUuid(),
                next.intervals.last,
              ),
            );
      }

      final updatedSession =
          await (_database.update(_database.focusSessions)..where(
                (session) =>
                    session.id.equals(id) &
                    session.status.equalsValue(current.session.status) &
                    session.updatedAtMs.equals(current.session.updatedAtMs),
              ))
              .write(
                FocusSessionsCompanion(
                  status: Value(next.session.status),
                  endedAtMs: Value(next.session.endedAtMs),
                  actualDurationMs: Value(next.session.actualDurationMs),
                  updatedAtMs: Value(next.session.updatedAtMs),
                ),
              );
      if (updatedSession != 1) {
        throw FocusSessionIntegrityException(
          id,
          'The session changed during the transition.',
        );
      }

      return next;
    });
  }

  Future<FocusSessionRow?> _unresolvedSessionRow() {
    return (_database.select(_database.focusSessions)..where(
          (session) => session.status.isInValues([
            FocusSessionStatus.running,
            FocusSessionStatus.paused,
          ]),
        ))
        .getSingleOrNull();
  }

  Future<List<FocusSessionIntervalRow>> _intervalRowsFor(
    Set<String> sessionIds,
  ) {
    return (_database.select(_database.focusSessionIntervals)
          ..where((interval) => interval.sessionId.isIn(sessionIds))
          ..orderBy([
            (interval) => OrderingTerm.asc(interval.startedAtMs),
            (interval) => OrderingTerm.asc(interval.id),
          ]))
        .get();
  }
}
