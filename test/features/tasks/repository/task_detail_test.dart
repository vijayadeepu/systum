import 'package:drift/drift.dart' show driftRuntimeOptions, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/focus/models/focus_session_mode.dart';
import 'package:systum/features/focus/models/focus_session_status.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/repository/task_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('TaskRepository.getFocusSessionsForTask', () {
    late SystumDatabase database;
    late TaskRepository repository;

    setUp(() {
      database = SystumDatabase.test(NativeDatabase.memory());
      repository = TaskRepository(database);
    });

    tearDown(() async {
      await database.close();
    });

    Future<void> insertTaskAndSessions() async {
      // Insert a task
      await repository.insert(
        Task(
          id: 'task-1',
          title: 'Test task',
          createdAt: DateTime(2026, 8, 10, 8),
          updatedAt: DateTime(2026, 8, 10, 8),
        ),
      );

      // Insert focus sessions linked to the task
      await database
          .into(database.focusSessions)
          .insert(
            FocusSessionsCompanion.insert(
              id: 'session-1',
              taskId: const Value('task-1'),
              mode: FocusSessionMode.standard,
              status: FocusSessionStatus.completed,
              startedAtMs: 1000,
              endedAtMs: const Value(2000),
              actualDurationMs: const Value(1000),
              updatedAtMs: 2000,
            ),
          );
      await database
          .into(database.focusSessions)
          .insert(
            FocusSessionsCompanion.insert(
              id: 'session-2',
              taskId: const Value('task-1'),
              mode: FocusSessionMode.pomodoro,
              status: FocusSessionStatus.running,
              startedAtMs: 3000,
              updatedAtMs: 3000,
            ),
          );
    }

    test('returns focus sessions linked to the task', () async {
      await insertTaskAndSessions();

      final sessions = await repository.getFocusSessionsForTask('task-1');

      expect(sessions, hasLength(2));
      expect(
        sessions.map((s) => s.id).toSet(),
        equals({'session-1', 'session-2'}),
      );
    });

    test('returns sessions ordered by startedAtMs descending', () async {
      await insertTaskAndSessions();

      final sessions = await repository.getFocusSessionsForTask('task-1');

      expect(
        sessions.map((s) => s.id).toList(),
        equals(['session-2', 'session-1']),
      );
    });

    test('returns empty list when task has no focus sessions', () async {
      await repository.insert(
        Task(
          id: 'task-1',
          title: 'Test task',
          createdAt: DateTime(2026, 8, 10, 8),
          updatedAt: DateTime(2026, 8, 10, 8),
        ),
      );

      final sessions = await repository.getFocusSessionsForTask('task-1');

      expect(sessions, isEmpty);
    });

    test('returns empty list for nonexistent task', () async {
      final sessions = await repository.getFocusSessionsForTask('nonexistent');

      expect(sessions, isEmpty);
    });

    test('does not return sessions for other tasks', () async {
      // Insert the other task first to satisfy the foreign key constraint
      await repository.insert(
        Task(
          id: 'other-task',
          title: 'Other task',
          createdAt: DateTime(2026, 8, 10, 8),
          updatedAt: DateTime(2026, 8, 10, 8),
        ),
      );
      await database
          .into(database.focusSessions)
          .insert(
            FocusSessionsCompanion.insert(
              id: 'session-3',
              taskId: const Value('other-task'),
              mode: FocusSessionMode.standard,
              status: FocusSessionStatus.completed,
              startedAtMs: 4000,
              endedAtMs: const Value(5000),
              actualDurationMs: const Value(1000),
              updatedAtMs: 5000,
            ),
          );

      final sessions = await repository.getFocusSessionsForTask('other-task');

      expect(sessions, hasLength(1));
      expect(sessions.first.id, 'session-3');
    });
  });
}
