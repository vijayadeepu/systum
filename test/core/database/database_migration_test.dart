import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';

void main() {
  group('SystumDatabase schema version 2', () {
    test('creates the current schema in a fresh database', () async {
      final database = SystumDatabase.test(NativeDatabase.memory());
      addTearDown(database.close);

      expect(await _tableNames(database), containsAll(['goals', 'tasks']));
      expect(
        await _indexNames(database),
        containsAll(['tasks_goal_id_idx', 'tasks_parent_task_id_idx']),
      );
      expect(
        (await database.customSelect('PRAGMA foreign_keys').getSingle())
            .read<int>('foreign_keys'),
        1,
      );
      final now = DateTime(2026, 8, 1);
      await database
          .into(database.goals)
          .insert(
            GoalsCompanion.insert(
              id: 'fresh-goal',
              title: 'Fresh goal',
              description: const Value('Created in a fresh database'),
              targetDate: Value(DateTime(2026, 9, 1)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      final goal = await database.select(database.goals).getSingle();
      expect(goal.title, 'Fresh goal');
      expect(goal.description, 'Created in a fresh database');
      expect(goal.targetDate, DateTime(2026, 9, 1));
      expect(goal.createdAt, now);
      expect(goal.updatedAt, now);
    });

    test(
      'migrates a genuine version 1 schema without changing task data',
      () async {
        final database = SystumDatabase.test(
          NativeDatabase.memory(
            setup: (legacyDatabase) {
              legacyDatabase.execute('''
              CREATE TABLE tasks (
                id TEXT NOT NULL PRIMARY KEY,
                title TEXT NOT NULL CHECK (length(title) BETWEEN 1 AND 120),
                description TEXT,
                completed INTEGER NOT NULL DEFAULT 0
                  CHECK (completed IN (0, 1)),
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                due_date INTEGER,
                priority INTEGER NOT NULL DEFAULT 2,
                category TEXT CHECK (length(category) <= 80)
              )
            ''');
              for (final task in _version1Tasks) {
                legacyDatabase.execute(
                  '''
                INSERT INTO tasks (
                  id, title, description, completed, created_at, updated_at,
                  due_date, priority, category
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''',
                  [
                    task.id,
                    task.title,
                    task.description,
                    task.completed ? 1 : 0,
                    _toVersion1DateTime(task.createdAt),
                    task.updatedAt.millisecondsSinceEpoch ~/ 1000,
                    task.dueDate == null
                        ? null
                        : _toVersion1DateTime(task.dueDate!),
                    task.priority,
                    task.category,
                  ],
                );
              }
              legacyDatabase.execute('PRAGMA user_version = 1');
            },
          ),
        );
        addTearDown(database.close);

        final rows = await database.select(database.tasks).get();
        expect(rows, hasLength(_version1Tasks.length));
        for (var index = 0; index < _version1Tasks.length; index++) {
          final expected = _version1Tasks[index];
          final actual = rows.firstWhere((row) => row.id == expected.id);

          expect(actual.id, expected.id);
          expect(actual.title, expected.title);
          expect(actual.description, expected.description);
          expect(actual.completed, expected.completed);
          expect(actual.createdAt, expected.createdAt);
          expect(actual.updatedAt, expected.updatedAt);
          expect(actual.dueDate, expected.dueDate);
          expect(actual.priority, expected.priority);
          expect(actual.category, expected.category);
          expect(actual.goalId, isNull);
          expect(actual.parentTaskId, isNull);
        }
        expect(
          (await database.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          2,
        );
        expect(await _tableNames(database), containsAll(['goals', 'tasks']));
        expect(
          await _indexNames(database),
          containsAll(['tasks_goal_id_idx', 'tasks_parent_task_id_idx']),
        );
        expect(
          (await database.customSelect('PRAGMA foreign_keys').getSingle())
              .read<int>('foreign_keys'),
          1,
        );
        final foreignKeys = await database
            .customSelect('PRAGMA foreign_key_list(tasks)')
            .get();
        expect(
          foreignKeys.map((row) => row.read<String>('from')),
          containsAll(['goal_id', 'parent_task_id']),
        );

        final now = DateTime(2026, 8, 4);
        await database
            .into(database.goals)
            .insert(
              GoalsCompanion.insert(
                id: 'migrated-goal',
                title: 'Migration relationship check',
                createdAt: now,
                updatedAt: now,
              ),
            );
        await database.customStatement(
          "UPDATE tasks SET goal_id = 'migrated-goal' "
          "WHERE id = 'v1-incomplete-nullables'",
        );
        await database.customStatement(
          "DELETE FROM goals WHERE id = 'migrated-goal'",
        );
        final unassignedTask =
            await (database.select(database.tasks)
                  ..where((task) => task.id.equals('v1-incomplete-nullables')))
                .getSingle();
        expect(unassignedTask.goalId, isNull);
      },
    );

    test('enforces goal set-null and parent no-action foreign keys', () async {
      final database = SystumDatabase.test(NativeDatabase.memory());
      addTearDown(database.close);
      final now = DateTime(2026, 8, 1);
      await database
          .into(database.goals)
          .insert(
            GoalsCompanion.insert(
              id: 'goal-1',
              title: 'Goal',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await database
          .into(database.tasks)
          .insert(_taskCompanion('parent', goalId: const Value('goal-1')));
      await database
          .into(database.tasks)
          .insert(_taskCompanion('child', parentTaskId: const Value('parent')));

      await database.customStatement("DELETE FROM goals WHERE id = 'goal-1'");
      final parent = await (database.select(
        database.tasks,
      )..where((task) => task.id.equals('parent'))).getSingle();
      expect(parent.goalId, isNull);

      await expectLater(
        database.customStatement("DELETE FROM tasks WHERE id = 'parent'"),
        throwsA(anything),
      );
      expect(
        await (database.select(
          database.tasks,
        )..where((task) => task.id.equals('child'))).getSingleOrNull(),
        isNotNull,
      );
    });
  });
}

class _Version1Task {
  const _Version1Task({
    required this.id,
    required this.title,
    required this.description,
    required this.completed,
    required this.createdAt,
    required this.updatedAt,
    required this.dueDate,
    required this.priority,
    required this.category,
  });

  final String id;
  final String title;
  final String? description;
  final bool completed;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? dueDate;
  final int priority;
  final String? category;
}

final _version1Tasks = [
  _Version1Task(
    id: 'v1-completed-with-details',
    title: 'Archive project',
    description: 'Preserve the final documents',
    completed: true,
    createdAt: DateTime(2026, 8, 1, 9),
    updatedAt: DateTime(2026, 8, 2, 10),
    dueDate: DateTime(2026, 8, 5),
    priority: 4,
    category: 'Work',
  ),
  _Version1Task(
    id: 'v1-incomplete-nullables',
    title: 'Plan next week',
    description: null,
    completed: false,
    createdAt: DateTime(2026, 8, 3, 11),
    updatedAt: DateTime(2026, 8, 3, 11),
    dueDate: null,
    priority: 1,
    category: null,
  ),
];

int _toVersion1DateTime(DateTime dateTime) =>
    dateTime.millisecondsSinceEpoch ~/ 1000;

TasksCompanion _taskCompanion(
  String id, {
  Value<String?> goalId = const Value.absent(),
  Value<String?> parentTaskId = const Value.absent(),
}) {
  final now = DateTime(2026, 8, 1);
  return TasksCompanion.insert(
    id: id,
    title: id,
    createdAt: now,
    updatedAt: now,
    goalId: goalId,
    parentTaskId: parentTaskId,
  );
}

Future<Set<String>> _tableNames(SystumDatabase database) async {
  final rows = await database
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  return rows.map((row) => row.read<String>('name')).toSet();
}

Future<Set<String>> _indexNames(SystumDatabase database) async {
  final rows = await database
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  return rows.map((row) => row.read<String>('name')).toSet();
}
