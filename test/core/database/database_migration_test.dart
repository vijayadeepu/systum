import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/goals/models/goal_date.dart';

void main() {
  group('SystumDatabase schema version 5', () {
    test('creates the current schema in a fresh database', () async {
      final database = SystumDatabase.test(NativeDatabase.memory());
      addTearDown(database.close);

      expect(
        await _tableNames(database),
        containsAll([
          'goals',
          'tasks',
          'focus_sessions',
          'focus_session_intervals',
        ]),
      );
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
              targetDate: Value(GoalDate.fromDateTime(DateTime(2026, 9, 1))),
              createdAt: now,
              updatedAt: now,
            ),
          );
      final goal = await database.select(database.goals).getSingle();
      expect(goal.title, 'Fresh goal');
      expect(goal.description, 'Created in a fresh database');
      expect(goal.targetDate, GoalDate.fromDateTime(DateTime(2026, 9, 1)));
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
          10,
        );
        expect(
          await _tableNames(database),
          containsAll([
            'goals',
            'tasks',
            'focus_sessions',
            'focus_session_intervals',
          ]),
        );
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

  test(
    'migrates version 2 target dates and preserves data across reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'systum_goal_date_migration_',
      );
      final databaseFile = File('${directory.path}/systum.sqlite');
      final firstLegacyDate = DateTime(2026, 9, 1);
      final secondLegacyDate = DateTime(2027, 1, 15, 23, 45);
      final expectedFirstDate = GoalDate.fromDateTime(
        DateTime.fromMillisecondsSinceEpoch(
          _toVersion2DateTime(firstLegacyDate) * 1000,
        ),
      );
      final expectedSecondDate = GoalDate.fromDateTime(
        DateTime.fromMillisecondsSinceEpoch(
          _toVersion2DateTime(secondLegacyDate) * 1000,
        ),
      );
      SystumDatabase? database;

      try {
        var migratedDatabase = SystumDatabase.test(
          NativeDatabase(
            databaseFile,
            setup: (legacyDatabase) {
              legacyDatabase.execute('''
                CREATE TABLE goals (
                  id TEXT NOT NULL PRIMARY KEY,
                  title TEXT NOT NULL CHECK (length(title) BETWEEN 1 AND 120),
                  description TEXT,
                  target_date INTEGER,
                  created_at INTEGER NOT NULL,
                  updated_at INTEGER NOT NULL
                )
              ''');
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
                  category TEXT CHECK (length(category) <= 80),
                  goal_id TEXT REFERENCES goals (id) ON DELETE SET NULL,
                  parent_task_id TEXT REFERENCES tasks (id)
                )
              ''');
              legacyDatabase.execute(
                'CREATE INDEX tasks_goal_id_idx ON tasks (goal_id)',
              );
              legacyDatabase.execute(
                'CREATE INDEX tasks_parent_task_id_idx '
                'ON tasks (parent_task_id)',
              );
              for (final goal in [
                (
                  id: 'dated-one',
                  title: 'First date',
                  description: null,
                  targetDate: firstLegacyDate,
                ),
                (
                  id: 'dated-two',
                  title: 'Second date',
                  description: 'Preserve this detail',
                  targetDate: secondLegacyDate,
                ),
                (
                  id: 'undated',
                  title: 'No target',
                  description: null,
                  targetDate: null,
                ),
              ]) {
                legacyDatabase.execute(
                  '''
                  INSERT INTO goals (
                    id, title, description, target_date, created_at, updated_at
                  ) VALUES (?, ?, ?, ?, ?, ?)
                  ''',
                  [
                    goal.id,
                    goal.title,
                    goal.description,
                    goal.targetDate == null
                        ? null
                        : _toVersion2DateTime(goal.targetDate!),
                    _toVersion2DateTime(DateTime(2026, 8, 1, 8)),
                    _toVersion2DateTime(DateTime(2026, 8, 2, 9)),
                  ],
                );
              }
              legacyDatabase.execute(
                '''
                INSERT INTO tasks (
                  id, title, description, completed, created_at, updated_at,
                  due_date, priority, category, goal_id, parent_task_id
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''',
                [
                  'parent-task',
                  'Preserve parent task',
                  'Task detail',
                  1,
                  _toVersion2DateTime(DateTime(2026, 8, 1, 9)),
                  _toVersion2DateTime(DateTime(2026, 8, 2, 10)),
                  _toVersion2DateTime(DateTime(2026, 8, 5)),
                  3,
                  'Work',
                  'dated-one',
                  null,
                ],
              );
              legacyDatabase.execute(
                '''
                INSERT INTO tasks (
                  id, title, created_at, updated_at, goal_id, parent_task_id
                ) VALUES (?, ?, ?, ?, ?, ?)
                ''',
                [
                  'child-task',
                  'Preserve child task',
                  _toVersion2DateTime(DateTime(2026, 8, 3)),
                  _toVersion2DateTime(DateTime(2026, 8, 3)),
                  'dated-one',
                  'parent-task',
                ],
              );
              legacyDatabase.execute('PRAGMA user_version = 2');
            },
          ),
        );
        database = migratedDatabase;
        final goals = await migratedDatabase
            .select(migratedDatabase.goals)
            .get();
        final first = goals.singleWhere((goal) => goal.id == 'dated-one');
        final second = goals.singleWhere((goal) => goal.id == 'dated-two');
        final undated = goals.singleWhere((goal) => goal.id == 'undated');

        expect(first.targetDate, expectedFirstDate);
        expect(first.title, 'First date');
        expect(first.description, isNull);
        expect(first.createdAt, DateTime(2026, 8, 1, 8));
        expect(first.updatedAt, DateTime(2026, 8, 2, 9));
        expect(second.targetDate, expectedSecondDate);
        expect(second.description, 'Preserve this detail');
        expect(second.createdAt, DateTime(2026, 8, 1, 8));
        expect(second.updatedAt, DateTime(2026, 8, 2, 9));
        expect(undated.title, 'No target');
        expect(undated.description, isNull);
        expect(undated.targetDate, isNull);
        expect(
          (await migratedDatabase
                  .customSelect('PRAGMA user_version')
                  .getSingle())
              .read<int>('user_version'),
          10,
        );

        final parent = await (migratedDatabase.select(
          migratedDatabase.tasks,
        )..where((task) => task.id.equals('parent-task'))).getSingle();
        final child = await (migratedDatabase.select(
          migratedDatabase.tasks,
        )..where((task) => task.id.equals('child-task'))).getSingle();
        expect(parent.title, 'Preserve parent task');
        expect(parent.description, 'Task detail');
        expect(parent.completed, isTrue);
        expect(parent.createdAt, DateTime(2026, 8, 1, 9));
        expect(parent.updatedAt, DateTime(2026, 8, 2, 10));
        expect(parent.dueDate, DateTime(2026, 8, 5));
        expect(parent.priority, 3);
        expect(parent.category, 'Work');
        expect(parent.goalId, 'dated-one');
        expect(parent.parentTaskId, isNull);
        expect(child.title, 'Preserve child task');
        expect(child.completed, isFalse);
        expect(child.createdAt, DateTime(2026, 8, 3));
        expect(child.updatedAt, DateTime(2026, 8, 3));
        expect(child.dueDate, isNull);
        expect(child.priority, 2);
        expect(child.category, isNull);
        expect(child.goalId, 'dated-one');
        expect(child.parentTaskId, 'parent-task');

        await migratedDatabase.close();
        database = null;
        migratedDatabase = SystumDatabase.test(NativeDatabase(databaseFile));
        database = migratedDatabase;
        expect(
          (await migratedDatabase.select(migratedDatabase.goals).get())
              .singleWhere((goal) => goal.id == 'dated-one')
              .targetDate,
          expectedFirstDate,
        );
        expect(
          (await migratedDatabase.select(migratedDatabase.tasks).get())
              .singleWhere((task) => task.id == 'child-task')
              .parentTaskId,
          'parent-task',
        );
      } finally {
        await database?.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test('migrates v6 recurrence dates, duplicates and indexes to v7', () async {
    final legacyStart = DateTime(2026, 1, 15).millisecondsSinceEpoch;
    final legacyEnd = DateTime(2026, 2, 15).millisecondsSinceEpoch;
    final legacyOccurrence = DateTime(2026, 1, 15).millisecondsSinceEpoch;
    final database = SystumDatabase.test(
      NativeDatabase.memory(
        setup: (legacy) {
          legacy.execute('''
              CREATE TABLE task_recurrence_rules (
                id TEXT NOT NULL PRIMARY KEY,
                parent_task_id TEXT,
                recurrence_type TEXT NOT NULL,
                interval INTEGER NOT NULL DEFAULT 1,
                weekdays INTEGER,
                start_date INTEGER NOT NULL,
                end_date INTEGER,
                max_occurrences INTEGER,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
              )
            ''');
          legacy.execute('''
              CREATE TABLE task_occurrences (
                id TEXT NOT NULL PRIMARY KEY,
                rule_id TEXT,
                occurrence_date INTEGER NOT NULL,
                due_date INTEGER,
                due_time INTEGER,
                due_timezone TEXT,
                completed INTEGER NOT NULL DEFAULT 0,
                is_deleted INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
              )
            ''');
          legacy.execute(
            'CREATE INDEX task_recurrence_rules_parent_task_id_idx '
            'ON task_recurrence_rules (parent_task_id)',
          );
          legacy.execute(
            'CREATE INDEX task_occurrences_rule_id_idx '
            'ON task_occurrences (rule_id)',
          );
          legacy.execute(
            'CREATE INDEX task_occurrences_occurrence_date_idx '
            'ON task_occurrences (occurrence_date)',
          );
          for (final ruleId in ['rule-keep', 'rule-duplicate']) {
            legacy.execute(
              'INSERT INTO task_recurrence_rules '
              '(id, parent_task_id, recurrence_type, interval, '
              'start_date, end_date, created_at, updated_at) '
              'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
              [
                ruleId,
                'parent',
                'daily',
                1,
                legacyStart,
                legacyEnd,
                1000,
                2000,
              ],
            );
          }
          legacy.execute(
            'INSERT INTO task_occurrences '
            '(id, rule_id, occurrence_date, due_date, created_at, updated_at) '
            'VALUES (?, ?, ?, ?, ?, ?)',
            [
              'occ-keep',
              'rule-keep',
              legacyOccurrence,
              legacyOccurrence,
              1000,
              2000,
            ],
          );
          legacy.execute(
            'INSERT INTO task_occurrences '
            '(id, rule_id, occurrence_date, due_date, created_at, updated_at) '
            'VALUES (?, ?, ?, ?, ?, ?)',
            [
              'occ-duplicate',
              'rule-keep',
              legacyOccurrence,
              legacyOccurrence,
              1001,
              2001,
            ],
          );
          legacy.execute(
            'INSERT INTO task_occurrences '
            '(id, rule_id, occurrence_date, due_date, created_at, updated_at) '
            'VALUES (?, ?, ?, ?, ?, ?)',
            [
              'occ-discarded-rule',
              'rule-duplicate',
              legacyOccurrence,
              legacyOccurrence,
              1002,
              2002,
            ],
          );
          legacy.execute('PRAGMA user_version = 6');
        },
      ),
    );
    addTearDown(database.close);

    final rules = await database.select(database.taskRecurrenceRules).get();
    expect(rules.map((rule) => rule.id), ['rule-keep']);
    final rule = rules.single;
    expect(rule.isActive, isTrue);
    expect(rule.startDate, DateTime.utc(2026, 1, 15).millisecondsSinceEpoch);
    expect(rule.endDate, DateTime.utc(2026, 2, 15).millisecondsSinceEpoch);

    final occurrences = await database.select(database.taskOccurrences).get();
    expect(occurrences.map((occurrence) => occurrence.id), ['occ-keep']);
    expect(
      occurrences.single.occurrenceDate,
      DateTime.utc(2026, 1, 15).millisecondsSinceEpoch,
    );
    expect(
      occurrences.single.dueDate,
      DateTime.utc(2026, 1, 15).millisecondsSinceEpoch,
    );

    expect(
      await _indexNames(database),
      containsAll([
        'task_recurrence_rules_parent_unique_idx',
        'task_occurrences_rule_date_unique_idx',
      ]),
    );
    expect(
      (await database.customSelect('PRAGMA user_version').getSingle())
          .read<int>('user_version'),
      10,
    );
  });

  test('migrates version 7 to reminders without changing task data', () async {
    final database = SystumDatabase.test(
      NativeDatabase.memory(
        setup: (legacyDatabase) {
          legacyDatabase.execute('''
            CREATE TABLE tasks (
              id TEXT NOT NULL PRIMARY KEY,
              title TEXT NOT NULL,
              completed INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          legacyDatabase.execute(
            "INSERT INTO tasks (id, title, completed, created_at, updated_at) "
            "VALUES ('task-1', 'Keep me', 0, 1000, 2000)",
          );
          legacyDatabase.execute('PRAGMA user_version = 7');
        },
      ),
    );
    addTearDown(database.close);

    expect(await _tableNames(database), contains('reminders'));
    expect(
      await _indexNames(database),
      containsAll(['reminders_task_id_idx', 'reminders_status_idx']),
    );

    final task = await database
        .customSelect(
          "SELECT id, title, completed FROM tasks WHERE id = 'task-1'",
        )
        .getSingle();
    expect(task.read<String>('title'), 'Keep me');
    expect(task.read<int>('completed'), 0);

    await database.customStatement(
      'INSERT INTO reminders '
      '(id, task_id, schedule_type, scheduled_at_utc_ms, local_time_seconds, '
      'interval, weekdays, start_date, end_date, max_occurrences, status, '
      'cancellation_reason, cancelled_at_ms, created_at_ms, updated_at_ms) '
      "VALUES ('reminder-1', 'task-1', 'once', 5000, NULL, 1, NULL, NULL, "
      "NULL, NULL, 'scheduled', NULL, NULL, 1000, 2000)",
    );
    final reminder = await database.select(database.reminders).getSingle();
    expect(reminder.taskId, 'task-1');
    expect(reminder.scheduledAtUtcMs, 5000);

    await database.customStatement("DELETE FROM tasks WHERE id = 'task-1'");
    expect(await database.select(database.reminders).get(), isEmpty);
    expect(
      (await database.customSelect('PRAGMA user_version').getSingle())
          .read<int>('user_version'),
      10,
    );
  });

  test('migrates version 8 to create hydration tables', () async {
    final database = SystumDatabase.test(
      NativeDatabase.memory(
        setup: (legacyDatabase) {
          legacyDatabase.execute('''
            CREATE TABLE tasks (
              id TEXT NOT NULL PRIMARY KEY,
              title TEXT NOT NULL,
              completed INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          legacyDatabase.execute('PRAGMA user_version = 8');
        },
      ),
    );
    addTearDown(database.close);

    expect(
      await _tableNames(database),
      containsAll(['hydration_entries', 'hydration_settings_table']),
    );
    expect(
      await database.customSelect("PRAGMA table_info(hydration_entries)").get(),
      isNotEmpty,
    );
    expect(
      await database
          .customSelect("PRAGMA table_info(hydration_settings_table)")
          .get(),
      isNotEmpty,
    );
    expect(
      (await database.customSelect('PRAGMA user_version').getSingle())
          .read<int>('user_version'),
      10,
    );
  });
}

int _toVersion2DateTime(DateTime dateTime) =>
    dateTime.millisecondsSinceEpoch ~/ 1000;

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
