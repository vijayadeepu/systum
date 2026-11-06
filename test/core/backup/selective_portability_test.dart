import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:systum/core/backup/backup_service.dart';
import 'package:systum/core/backup/selective_portability.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/focus/models/focus_session_mode.dart';
import 'package:systum/features/focus/repository/focus_repository.dart';
import 'package:systum/features/focus/repository/pomodoro_settings_store.dart';

void main() {
  late SystumDatabase database;
  late SelectivePortabilityService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = SystumDatabase.test(NativeDatabase.memory());
    service = SelectivePortabilityService(
      database,
      BackupService(database, PomodoroSettingsStore()),
    );
  });

  tearDown(() => database.close());

  Future<void> seed() async {
    await database
        .into(database.goals)
        .insert(
          GoalsCompanion.insert(
            id: 'goal',
            title: 'Goal',
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
    await database
        .into(database.tasks)
        .insert(
          TasksCompanion.insert(
            id: 'task',
            title: 'Task',
            goalId: const Value('goal'),
            createdAt: DateTime.utc(2026, 1, 2),
            updatedAt: DateTime.utc(2026, 1, 2),
          ),
        );
    await database
        .into(database.tasks)
        .insert(
          TasksCompanion.insert(
            id: 'child',
            title: 'Child',
            goalId: const Value('goal'),
            parentTaskId: const Value('task'),
            createdAt: DateTime.utc(2026, 1, 3),
            updatedAt: DateTime.utc(2026, 1, 3),
          ),
        );
    final repository = FocusRepository(database);
    final session = await repository.startSession(
      taskId: 'task',
      mode: FocusSessionMode.standard,
      startedAtMs: 1000,
    );
    await repository.completeSession(session.session.id, atMs: 61000);
  }

  SystumDatabase newTargetDatabase() {
    final target = SystumDatabase.test(NativeDatabase.memory());
    addTearDown(target.close);
    return target;
  }

  SelectivePortabilityService serviceFor(SystumDatabase target) {
    return SelectivePortabilityService(
      target,
      BackupService(target, PomodoroSettingsStore()),
    );
  }

  test(
    'exports only the selected datasets and drops unselected relations',
    () async {
      await seed();

      final tasksOnly =
          jsonDecode(await service.exportJson({SelectiveDataset.tasks}))
              as Map<String, dynamic>;
      final taskData = tasksOnly['data'] as Map<String, dynamic>;
      expect(tasksOnly['datasets'], ['tasks']);
      expect(taskData['goals'], isEmpty);
      expect(taskData['tasks'], hasLength(2));
      for (final task in taskData['tasks'] as List) {
        expect((task as Map)['goalId'], isNull);
      }
      expect((taskData['tasks'][1] as Map)['parentTaskId'], 'task');

      final focusOnly =
          jsonDecode(await service.exportJson({SelectiveDataset.focusHistory}))
              as Map<String, dynamic>;
      final focusData = focusOnly['data'] as Map<String, dynamic>;
      expect(focusData['tasks'], isEmpty);
      expect(focusData['focusSessions'], hasLength(1));
      expect((focusData['focusSessions'][0] as Map)['taskId'], isNull);
      expect(
        (focusData['focusSessions'][0] as Map)['taskTitleAtStart'],
        'Task',
      );
      expect(focusData['focusIntervals'], hasLength(1));
    },
  );

  test('keeps reminders out of selective task exports', () async {
    await seed();
    await database
        .into(database.reminders)
        .insert(
          RemindersCompanion.insert(
            id: 'reminder',
            taskId: 'task',
            scheduleType: 'once',
            scheduledAtUtcMs: const Value(1000),
            createdAtMs: 0,
            updatedAtMs: 0,
          ),
        );

    final encoded = await service.exportJson({
      SelectiveDataset.tasks,
      SelectiveDataset.goals,
      SelectiveDataset.focusHistory,
    });
    final data =
        (jsonDecode(encoded) as Map<String, dynamic>)['data']
            as Map<String, dynamic>;

    expect(data.containsKey('reminders'), isFalse);
    expect((data['tasks'] as List), isNotEmpty);
  });

  test(
    'keeps goal and hierarchy references when those datasets are selected',
    () async {
      await seed();

      final encoded = await service.exportJson({
        SelectiveDataset.tasks,
        SelectiveDataset.goals,
        SelectiveDataset.focusHistory,
      });
      final document = jsonDecode(encoded) as Map<String, dynamic>;
      final data = document['data'] as Map<String, dynamic>;

      expect(document['format'], SelectivePortabilityService.format);
      expect(data['goals'], hasLength(1));
      expect((data['tasks'][0] as Map)['goalId'], 'goal');
      expect((data['focusSessions'][0] as Map)['taskId'], 'task');
    },
  );

  test(
    'exports CSV with correct escaping and deterministic ordering',
    () async {
      await database
          .into(database.tasks)
          .insert(
            TasksCompanion.insert(
              id: 'csv',
              title: 'Comma, "quote"\nline',
              createdAt: DateTime.utc(2026, 1, 1),
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      final csv = await service.exportCsv(SelectiveDataset.tasks);

      expect(csv.split('\r\n').first, contains('id,title,description'));
      expect(csv, contains('"Comma, ""quote""\nline"'));
    },
  );

  test('previews and imports selected data transactionally', () async {
    await seed();
    final encoded = await service.exportJson({
      SelectiveDataset.tasks,
      SelectiveDataset.goals,
      SelectiveDataset.focusHistory,
    });
    final targetService = serviceFor(newTargetDatabase());

    final preview = await targetService.preview(encoded);
    expect(preview.canImport, isTrue);
    expect(preview.taskCount, 2);
    expect(preview.goalCount, 1);
    expect(preview.focusSessionCount, 1);
    expect(preview.focusIntervalCount, 1);
    expect(preview.existingTaskCount, 0);

    final result = await targetService.import(encoded, confirmed: true);

    expect(result.tasksImported, 2);
    expect(result.goalsImported, 1);
    expect(result.focusSessionsImported, 1);
    expect(
      await targetService.preview(encoded).then((p) => p.existingTaskCount),
      2,
    );
  });

  test('requires confirmation and skips conflicts by default', () async {
    await seed();
    final encoded = await service.exportJson({
      SelectiveDataset.tasks,
      SelectiveDataset.goals,
    });
    final targetDatabase = newTargetDatabase();
    final targetService = serviceFor(targetDatabase);
    await targetDatabase
        .into(targetDatabase.goals)
        .insert(
          GoalsCompanion.insert(
            id: 'goal',
            title: 'Old goal',
            createdAt: DateTime.utc(2025, 1, 1),
            updatedAt: DateTime.utc(2025, 1, 1),
          ),
        );
    await targetDatabase
        .into(targetDatabase.tasks)
        .insert(
          TasksCompanion.insert(
            id: 'task',
            title: 'Old task',
            createdAt: DateTime.utc(2025, 1, 1),
            updatedAt: DateTime.utc(2025, 1, 1),
          ),
        );

    await expectLater(
      targetService.import(encoded, confirmed: false),
      throwsA(isA<SelectiveImportException>()),
    );

    final preview = await targetService.preview(encoded);
    expect(preview.existingTaskCount, 1);
    expect(preview.existingGoalCount, 1);

    final result = await targetService.import(encoded, confirmed: true);
    expect(result.tasksSkipped, 1);
    expect(result.goalsSkipped, 1);
    expect(result.tasksImported, 1);
    final task = await (targetDatabase.select(
      targetDatabase.tasks,
    )..where((row) => row.id.equals('task'))).getSingle();
    expect(task.title, 'Old task');
  });

  test('overwrites selected tasks and goals when requested', () async {
    await seed();
    final encoded = await service.exportJson({
      SelectiveDataset.tasks,
      SelectiveDataset.goals,
    });
    final targetDatabase = newTargetDatabase();
    final targetService = serviceFor(targetDatabase);
    await targetDatabase
        .into(targetDatabase.goals)
        .insert(
          GoalsCompanion.insert(
            id: 'goal',
            title: 'Old goal',
            createdAt: DateTime.utc(2025, 1, 1),
            updatedAt: DateTime.utc(2025, 1, 1),
          ),
        );
    await targetDatabase
        .into(targetDatabase.tasks)
        .insert(
          TasksCompanion.insert(
            id: 'task',
            title: 'Old task',
            createdAt: DateTime.utc(2025, 1, 1),
            updatedAt: DateTime.utc(2025, 1, 1),
          ),
        );

    final result = await targetService.import(
      encoded,
      confirmed: true,
      overwriteExisting: true,
    );

    expect(result.tasksImported, 2);
    expect(result.goalsImported, 1);
    final task = await (targetDatabase.select(
      targetDatabase.tasks,
    )..where((row) => row.id.equals('task'))).getSingle();
    expect(task.title, 'Task');
    expect(task.goalId, 'goal');
  });

  test('blocks imports with missing relationship targets', () async {
    await seed();
    final encoded = await service.exportJson({
      SelectiveDataset.tasks,
      SelectiveDataset.goals,
    });
    final document = jsonDecode(encoded) as Map<String, dynamic>;
    document.remove('payloadLengthBytes');
    document.remove('payloadSha256');
    final data = document['data'] as Map<String, dynamic>;
    final tasks = data['tasks'] as List;
    (tasks.first as Map<String, dynamic>)['parentTaskId'] = 'missing-parent';
    final broken = jsonEncode(document);

    final preview = await serviceFor(newTargetDatabase()).preview(broken);

    expect(preview.canImport, isFalse);
    expect(
      preview.blockers,
      contains(contains('references missing parent "missing-parent"')),
    );
  });
}
