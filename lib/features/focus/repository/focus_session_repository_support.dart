import 'dart:math';

import 'package:drift/drift.dart' show Value;

import '../../../core/database/database.dart';
import '../models/focus_session.dart';
import '../models/focus_session_interval.dart';
import 'focus_repository_exceptions.dart';

abstract final class FocusSessionRepositorySupport {
  static FocusSessionTransition transitionFromRows(
    FocusSessionRow row,
    List<FocusSessionIntervalRow> intervalRows,
  ) {
    try {
      final session = FocusSession(
        id: row.id,
        taskId: row.taskId,
        taskIdSnapshot: row.taskIdAtStart,
        taskTitleSnapshot: row.taskTitleAtStart,
        mode: row.mode,
        status: row.status,
        startedAtMs: row.startedAtMs,
        endedAtMs: row.endedAtMs,
        plannedDurationMs: row.plannedDurationMs,
        actualDurationMs: row.actualDurationMs,
        cycleId: row.cycleId,
        cycleRound: row.cycleRound,
        updatedAtMs: row.updatedAtMs,
      );

      final orderedIntervals = [...intervalRows]
        ..sort((first, second) {
          final byStart = first.startedAtMs.compareTo(second.startedAtMs);
          if (byStart != 0) return byStart;

          // A closed interval precedes an interval resumed at the same ms.
          final byEnd = (first.endedAtMs ?? 0x7fffffffffffffff).compareTo(
            second.endedAtMs ?? 0x7fffffffffffffff,
          );
          if (byEnd != 0) return byEnd;
          return first.id.compareTo(second.id);
        });

      return FocusSessionTransition(
        session: session,
        intervals: orderedIntervals.map((row) => row.toDomain()),
      );
    } on ArgumentError catch (error) {
      throw FocusSessionIntegrityException(row.id, error.message.toString());
    } on StateError catch (error) {
      throw FocusSessionIntegrityException(row.id, error.message.toString());
    }
  }

  static FocusSessionsCompanion sessionCompanion(FocusSession session) =>
      FocusSessionsCompanion(
        id: Value(session.id),
        taskId: Value(session.taskId),
        taskIdAtStart: Value(session.taskIdSnapshot),
        taskTitleAtStart: Value(session.taskTitleSnapshot),
        mode: Value(session.mode),
        status: Value(session.status),
        startedAtMs: Value(session.startedAtMs),
        endedAtMs: Value(session.endedAtMs),
        plannedDurationMs: Value(session.plannedDurationMs),
        actualDurationMs: Value(session.actualDurationMs),
        cycleId: Value(session.cycleId),
        cycleRound: Value(session.cycleRound),
        updatedAtMs: Value(session.updatedAtMs),
      );

  static FocusSessionIntervalsCompanion intervalCompanion(
    String id,
    FocusSessionInterval interval,
  ) => FocusSessionIntervalsCompanion(
    id: Value(id),
    sessionId: Value(interval.sessionId),
    startedAtMs: Value(interval.startedAtMs),
    endedAtMs: Value(interval.endedAtMs),
  );

  static String newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
