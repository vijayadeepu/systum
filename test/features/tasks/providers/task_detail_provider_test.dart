import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/focus/models/focus_session_mode.dart';
import 'package:systum/features/focus/models/focus_session_status.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/providers/task_provider.dart';
import 'package:systum/shared/providers/database_provider.dart';

void main() {
  group('TaskDetailProvider', () {
    late SystumDatabase database;

    setUp(() {
      database = SystumDatabase.test(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    ProviderContainer createContainer() {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('returns task detail when task exists', () async {
      final container = createContainer();
      final repository = container.read(taskRepositoryProvider);

      await repository.insert(
        Task(
          id: 'task-1',
          title: 'Test task',
          description: 'A description',
          completed: false,
          createdAt: DateTime(2026, 8, 10, 8),
          updatedAt: DateTime(2026, 8, 10, 9),
          dueDate: DateTime(2026, 8, 12),
          priority: 3,
          category: 'Work',
        ),
      );

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

      final detail = await container.read(taskDetailProvider('task-1').future);

      expect(detail.task.id, 'task-1');
      expect(detail.task.title, 'Test task');
      expect(detail.task.description, 'A description');
      expect(detail.task.completed, isFalse);
      expect(detail.task.priority, 3);
      expect(detail.task.category, 'Work');
      expect(detail.focusSessions, hasLength(1));
      expect(detail.focusSessions.first.id, 'session-1');
      expect(detail.hasFocusSessions, isTrue);
    });

    test('returns empty focus sessions when task has none', () async {
      final container = createContainer();
      final repository = container.read(taskRepositoryProvider);

      await repository.insert(
        Task(
          id: 'task-1',
          title: 'Test task',
          createdAt: DateTime(2026, 8, 10, 8),
          updatedAt: DateTime(2026, 8, 10, 8),
        ),
      );

      final detail = await container.read(taskDetailProvider('task-1').future);

      expect(detail.focusSessions, isEmpty);
      expect(detail.hasFocusSessions, isFalse);
    });
  });
}
