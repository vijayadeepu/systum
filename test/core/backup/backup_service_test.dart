import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:systum/core/backup/backup_service.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/focus/models/focus_session.dart';
import 'package:systum/features/focus/models/focus_session_mode.dart';
import 'package:systum/features/focus/models/pomodoro_settings.dart';
import 'package:systum/features/focus/repository/focus_session_repository_support.dart';
import 'package:systum/features/focus/repository/pomodoro_settings_store.dart';
import 'package:systum/core/backup/restore_journal.dart';

void main() {
  late SystumDatabase database;
  late BackupService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = SystumDatabase.test(NativeDatabase.memory());
    service = BackupService(database, PomodoroSettingsStore());
  });

  tearDown(() => database.close());

  test('exports an empty versioned backup and validates it', () async {
    final encoded = await service.createBackup();
    final document = jsonDecode(encoded) as Map<String, dynamic>;

    expect(document['format'], BackupService.format);
    expect(document['version'], BackupService.currentVersion);
    expect(document['appVersion'], BackupService.appVersion);
    expect(document['exportState'], 'complete');
    expect(document['payloadEncoding'], BackupService.payloadEncoding);
    expect(document['payloadHashAlgorithm'], BackupService.integrityAlgorithm);
    expect(document['payloadLengthBytes'], isA<int>());
    expect(document['payloadSha256'], hasLength(64));
    expect((document['data'] as Map)['tasks'], isEmpty);
    final validation = await service.validate(encoded);
    expect(validation.status, BackupVerificationStatus.verified);
  });

  test('checksum is deterministic regardless of envelope timestamp', () async {
    final first = await service.createBackup();
    final second = await BackupService(
      database,
      PomodoroSettingsStore(),
      clock: () => DateTime.utc(2030, 1, 1),
    ).createBackup();
    final firstDocument = jsonDecode(first) as Map<String, dynamic>;
    final secondDocument = jsonDecode(second) as Map<String, dynamic>;

    expect(
      firstDocument['createdAtUtc'],
      isNot(secondDocument['createdAtUtc']),
    );
    expect(firstDocument['payloadSha256'], secondDocument['payloadSha256']);
    expect(
      firstDocument['payloadLengthBytes'],
      secondDocument['payloadLengthBytes'],
    );
  });

  test('rejects corrupted integrity metadata and payload', () async {
    final base =
        jsonDecode(await service.createBackup()) as Map<String, dynamic>;
    for (final mutation in <void Function(Map<String, dynamic>)>[
      (document) => document['payloadSha256'] = '0' * 64,
      (document) => document['payloadLengthBytes'] =
          (document['payloadLengthBytes'] as int) + 1,
      (document) => document['payloadHashAlgorithm'] = 'sha512',
      (document) => document.remove('exportState'),
      (document) => document.remove('payloadSha256'),
    ]) {
      final mutated = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
      mutation(mutated);
      await expectLater(
        service.validate(jsonEncode(mutated)),
        throwsA(isA<BackupValidationException>()),
      );
    }
  });

  test('integrity failure does not mutate persistent data', () async {
    final now = DateTime.utc(2026, 1, 1);
    await database
        .into(database.tasks)
        .insert(
          TasksCompanion.insert(
            id: 'existing',
            title: 'Keep me',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final mutated =
        jsonDecode(await service.createBackup()) as Map<String, dynamic>;
    final tasks = mutated['data'] as Map<String, dynamic>;
    (tasks['tasks'] as List).single['title'] = 'Tampered';

    await expectLater(
      service.validate(jsonEncode(mutated)),
      throwsA(isA<BackupValidationException>()),
    );
    expect(
      (await database.select(database.tasks).get()).single.title,
      'Keep me',
    );
  });

  test(
    'restore rejects an integrity failure before creating a journal',
    () async {
      final now = DateTime.utc(2026, 1, 1);
      await database
          .into(database.tasks)
          .insert(
            TasksCompanion.insert(
              id: 'existing',
              title: 'Keep me',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final mutated =
          jsonDecode(await service.createBackup()) as Map<String, dynamic>;
      (mutated['data'] as Map<String, dynamic>)['tasks'] = [
        {
          'id': 'replacement',
          'title': 'Replacement',
          'description': null,
          'completed': false,
          'createdAtMs': 0,
          'updatedAtMs': 0,
          'dueDateMs': null,
          'priority': 0,
          'category': null,
          'goalId': null,
          'parentTaskId': null,
        },
      ];

      await expectLater(
        service.restore(jsonEncode(mutated), overwriteExisting: true),
        throwsA(isA<BackupValidationException>()),
      );
      expect(
        (await database.select(database.tasks).get()).single.id,
        'existing',
      );
    },
  );

  test('accepts legacy v1 backups as unverified', () async {
    final legacy =
        jsonDecode(await service.createBackup()) as Map<String, dynamic>;
    for (final key in [
      'appVersion',
      'exportState',
      'payloadEncoding',
      'payloadHashAlgorithm',
      'payloadLengthBytes',
      'payloadSha256',
    ]) {
      legacy.remove(key);
    }

    final result = await service.validate(jsonEncode(legacy));
    expect(result.status, BackupVerificationStatus.legacyUnverified);
  });

  test(
    'canonical payload remains stable for unicode and escaped text',
    () async {
      final now = DateTime.utc(2026, 1, 1);
      await database
          .into(database.tasks)
          .insert(
            TasksCompanion.insert(
              id: 'unicode',
              title: 'Résumé 🚀 \\"quoted\\"',
              description: const Value('नमस्ते\n世界'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      final first =
          jsonDecode(await service.createBackup()) as Map<String, dynamic>;
      final second =
          jsonDecode(await service.createBackup()) as Map<String, dynamic>;

      expect(first['payloadSha256'], second['payloadSha256']);
      await service.validate(jsonEncode(first));
    },
  );

  test('round trips goals, hierarchy, focus intervals, and settings', () async {
    final now = DateTime.utc(2026, 1, 1, 10);
    await database
        .into(database.goals)
        .insert(
          GoalsCompanion.insert(
            id: 'goal',
            title: 'Ship',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.tasks)
        .insert(
          TasksCompanion.insert(
            id: 'parent',
            title: 'Parent',
            createdAt: now,
            updatedAt: now,
            goalId: const Value('goal'),
          ),
        );
    await database
        .into(database.tasks)
        .insert(
          TasksCompanion.insert(
            id: 'child',
            title: 'Child',
            createdAt: now,
            updatedAt: now,
            goalId: const Value('goal'),
            parentTaskId: const Value('parent'),
          ),
        );
    final started = FocusSession.start(
      id: 'session',
      taskId: 'parent',
      taskIdSnapshot: 'parent',
      taskTitleSnapshot: 'Parent',
      mode: FocusSessionMode.standard,
      startedAtMs: 100,
    );
    final completed = started.session.complete(
      intervals: started.intervals,
      atMs: 250,
    );
    await database
        .into(database.focusSessions)
        .insert(
          FocusSessionRepositorySupport.sessionCompanion(completed.session),
        );
    await database
        .into(database.focusSessionIntervals)
        .insert(
          FocusSessionRepositorySupport.intervalCompanion(
            'interval',
            completed.intervals.single,
          ),
        );
    await PomodoroSettingsStore().save(
      PomodoroSettings(
        focusMinutes: 50,
        shortBreakMinutes: 10,
        longBreakMinutes: 20,
      ),
    );

    final encoded = await service.createBackup();
    await database.delete(database.focusSessionIntervals).go();
    await database.delete(database.focusSessions).go();
    await database.delete(database.tasks).go();
    await database.delete(database.goals).go();
    await service.restore(encoded, overwriteExisting: true);

    expect((await database.select(database.goals).get()).single.title, 'Ship');
    final tasks = await database.select(database.tasks).get();
    expect(tasks.map((task) => task.id), containsAll(['parent', 'child']));
    expect(
      tasks.singleWhere((task) => task.id == 'child').parentTaskId,
      'parent',
    );
    expect(
      (await database.select(database.focusSessions).get()).single.id,
      'session',
    );
    expect(
      (await database.select(database.focusSessionIntervals).get())
          .single
          .endedAtMs,
      250,
    );
    expect((await PomodoroSettingsStore().load()).focusMinutes, 50);
  });

  test('requires explicit overwrite confirmation', () async {
    await expectLater(
      service.restore(await service.createBackup(), overwriteExisting: false),
      throwsA(isA<BackupRestoreException>()),
    );
  });

  test(
    'rejects malformed, unsupported, duplicate, and relationally invalid backups',
    () async {
      await expectLater(
        service.validate('{'),
        throwsA(isA<BackupValidationException>()),
      );
      final base =
          jsonDecode(await service.createBackup()) as Map<String, dynamic>;

      final unsupported = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
      unsupported['version'] = 99;
      await expectLater(
        service.validate(jsonEncode(unsupported)),
        throwsA(isA<BackupValidationException>()),
      );

      final duplicate = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
      (duplicate['data'] as Map<String, dynamic>)['goals'] = [
        {
          'id': 'g',
          'title': 'One',
          'description': null,
          'targetDateEpochDay': null,
          'createdAtMs': 0,
          'updatedAtMs': 0,
        },
        {
          'id': 'g',
          'title': 'Two',
          'description': null,
          'targetDateEpochDay': null,
          'createdAtMs': 0,
          'updatedAtMs': 0,
        },
      ];
      await expectLater(
        service.validate(jsonEncode(duplicate)),
        throwsA(isA<BackupValidationException>()),
      );

      final missingGoal = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
      (missingGoal['data'] as Map<String, dynamic>)['tasks'] = [
        {
          'id': 't',
          'title': 'Task',
          'description': null,
          'completed': false,
          'createdAtMs': 0,
          'updatedAtMs': 0,
          'dueDateMs': null,
          'priority': 2,
          'category': null,
          'goalId': 'missing',
          'parentTaskId': null,
        },
      ];
      await expectLater(
        service.validate(jsonEncode(missingGoal)),
        throwsA(isA<BackupValidationException>()),
      );
    },
  );

  test(
    'persists deterministic journal states and clears after completion',
    () async {
      final journalStore = _MemoryJournalStore();
      final settingsStore = _FakeSettingsStore();
      final journaled = BackupService(
        database,
        settingsStore,
        journalStore: journalStore,
        operationIdGenerator: () => 'operation-1',
        clock: () => DateTime.utc(2026, 1, 1),
      );

      await journaled.restore(
        await journaled.createBackup(),
        overwriteExisting: true,
      );

      expect(journalStore.statuses, [
        RestoreJournalStatus.prepared,
        RestoreJournalStatus.databaseCommitted,
        RestoreJournalStatus.preferencesApplied,
        RestoreJournalStatus.completed,
      ]);
      expect(journalStore.journal, isNull);
      expect(settingsStore.imported, isNotNull);
    },
  );

  test(
    'preference failure leaves a journal and startup reconciliation resumes',
    () async {
      final journalStore = _MemoryJournalStore();
      final settingsStore = _FakeSettingsStore()..failImport = true;
      final journaled = BackupService(
        database,
        settingsStore,
        journalStore: journalStore,
        operationIdGenerator: () => 'operation-2',
      );
      final encoded = await journaled.createBackup();

      await expectLater(
        journaled.restore(encoded, overwriteExisting: true),
        throwsA(isA<StateError>()),
      );
      expect(
        journalStore.journal?.status,
        RestoreJournalStatus.databaseCommitted,
      );
      await expectLater(
        journaled.restore(encoded, overwriteExisting: true),
        throwsA(isA<BackupRestoreException>()),
      );

      settingsStore.failImport = false;
      await journaled.reconcilePendingRestore();
      expect(journalStore.journal, isNull);
      expect(settingsStore.importCount, 2);
    },
  );

  test(
    'a prepared journal for an uncommitted database is discarded safely',
    () async {
      final journalStore = _MemoryJournalStore();
      final settingsStore = _FakeSettingsStore();
      final journaled = BackupService(
        database,
        settingsStore,
        journalStore: journalStore,
        operationIdGenerator: () => 'operation-3',
      );
      final encoded = await journaled.createBackup();
      final document = jsonDecode(encoded) as Map<String, dynamic>;
      final prepared = RestoreJournal(
        operationId: 'prepared',
        schemaVersion: RestoreJournal.currentSchemaVersion,
        status: RestoreJournalStatus.prepared,
        createdAtMs: 1,
        databaseFingerprint: 'not-the-current-database',
        incomingPreferences: document['preferences'] as Map<String, dynamic>,
        previousPreferences: document['preferences'] as Map<String, dynamic>,
      );
      await journalStore.save(prepared);

      await journaled.reconcilePendingRestore();
      expect(journalStore.journal, isNull);
      expect(settingsStore.importCount, 0);
    },
  );

  test(
    'corrupted journal blocks reconciliation instead of being ignored',
    () async {
      final service = BackupService(
        database,
        _FakeSettingsStore(),
        journalStore: _CorruptJournalStore(),
      );
      await expectLater(
        service.reconcilePendingRestore(),
        throwsA(isA<RestoreJournalException>()),
      );
    },
  );

  test(
    'SQLite failure rolls back existing data and clears prepared journal',
    () async {
      await database
          .into(database.goals)
          .insert(
            GoalsCompanion.insert(
              id: 'existing',
              title: 'Keep me',
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          );
      final document =
          jsonDecode(await service.createBackup()) as Map<String, dynamic>;
      (document['data'] as Map<String, dynamic>)['goals'] = [
        {
          'id': 'incoming',
          'title': 'Incoming',
          'description': null,
          'targetDateEpochDay': null,
          'createdAtMs': 0,
          'updatedAtMs': 0,
        },
      ];
      await database.customStatement('''
        CREATE TRIGGER fail_restore_goal BEFORE INSERT ON goals
        BEGIN SELECT RAISE(ABORT, 'restore failure'); END
      ''');

      await expectLater(
        service.restore(jsonEncode(document), overwriteExisting: true),
        throwsA(isA<Object>()),
      );
      expect(
        (await database.select(database.goals).get()).single.id,
        'existing',
      );
    },
  );

  test(
    'journal state-write failure is recovered using the database fingerprint',
    () async {
      final journalStore = _MemoryJournalStore()
        ..failAt = RestoreJournalStatus.databaseCommitted;
      final journaled = BackupService(
        database,
        _FakeSettingsStore(),
        journalStore: journalStore,
        operationIdGenerator: () => 'operation-4',
      );
      final encoded = await journaled.createBackup();

      await expectLater(
        journaled.restore(encoded, overwriteExisting: true),
        throwsA(isA<RestoreJournalException>()),
      );
      expect(journalStore.journal?.status, RestoreJournalStatus.prepared);
      journalStore.failAt = null;
      await journaled.reconcilePendingRestore();
      expect(journalStore.journal, isNull);
    },
  );

  test('journal deletion failure leaves completed state recoverable', () async {
    final journalStore = _MemoryJournalStore()..failClear = true;
    final journaled = BackupService(
      database,
      _FakeSettingsStore(),
      journalStore: journalStore,
    );
    await expectLater(
      journaled.restore(
        await journaled.createBackup(),
        overwriteExisting: true,
      ),
      throwsA(isA<RestoreJournalException>()),
    );
    expect(journalStore.journal?.status, RestoreJournalStatus.completed);
    journalStore.failClear = false;
    await journaled.reconcilePendingRestore();
    expect(journalStore.journal, isNull);
  });
}

class _MemoryJournalStore implements RestoreJournalStore {
  RestoreJournal? journal;
  final statuses = <RestoreJournalStatus>[];
  RestoreJournalStatus? failAt;
  bool failClear = false;

  @override
  Future<RestoreJournal?> load() async => journal;

  @override
  Future<void> save(RestoreJournal value) async {
    if (value.status == failAt) {
      throw const RestoreJournalException('journal write failure');
    }
    journal = value;
    statuses.add(value.status);
  }

  @override
  Future<void> clear() async {
    if (failClear) {
      throw const RestoreJournalException('journal clear failure');
    }
    journal = null;
  }
}

class _CorruptJournalStore implements RestoreJournalStore {
  @override
  Future<RestoreJournal?> load() async {
    throw const RestoreJournalException('corrupt');
  }

  @override
  Future<void> save(RestoreJournal journal) async {}

  @override
  Future<void> clear() async {}
}

class _FakeSettingsStore extends PomodoroSettingsStore {
  bool failImport = false;
  Map<String, dynamic>? imported;
  int importCount = 0;

  @override
  Future<Map<String, dynamic>> exportData() async => {
    'pomodoroSettings': {
      'focusMinutes': 25,
      'shortBreakMinutes': 5,
      'longBreakMinutes': 15,
    },
    'dismissedCycleIds': <String>[],
  };

  @override
  Future<void> importData(Map<String, dynamic> data) async {
    importCount++;
    if (failImport) throw StateError('preference failure');
    imported = data;
  }
}
