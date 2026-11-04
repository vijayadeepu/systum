import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:systum/core/backup/automatic_backup.dart';
import 'package:systum/core/backup/backup_service.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/focus/repository/pomodoro_settings_store.dart';

void main() {
  late SystumDatabase database;
  late Directory root;
  late DateTime now;
  late int sequence;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = SystumDatabase.test(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('systum_auto_backup_');
    now = DateTime.utc(2026, 11, 3, 9);
    sequence = 0;
  });

  tearDown(() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  AutomaticBackupService buildService({
    AutomaticBackupStore? store,
    int retention = 2,
  }) {
    return AutomaticBackupService(
      BackupService(database, PomodoroSettingsStore()),
      store:
          store ?? LocalAutomaticBackupStore(rootDirectory: () async => root),
      clock: () => now,
      idGenerator: () => 'id-${sequence++}',
      retention: retention,
    );
  }

  test(
    'creates a verified app-private backup without touching current data',
    () async {
      final service = buildService();

      final status = await service.runIfDue(force: true);

      expect(status.hasError, isFalse);
      expect(status.lastSuccessAt, now);
      expect(status.lastFileName, isNotNull);
      expect(status.lastSizeBytes, greaterThan(0));
      expect(await database.select(database.tasks).get(), isEmpty);

      final files = await service.listBackups();
      expect(files, hasLength(1));
      final encoded = utf8.decode(await File(files.single.path).readAsBytes());
      final validation = await BackupService(
        database,
        PomodoroSettingsStore(),
      ).validate(encoded);
      expect(validation.isVerified, isTrue);
      expect(await service.storageUsageBytes(), files.single.sizeBytes);
    },
  );

  test(
    'does not create a duplicate backup before the interval elapses',
    () async {
      final service = buildService();
      await service.runIfDue(force: true);
      final firstFile = (await service.status()).lastFileName;

      now = now.add(const Duration(hours: 1));
      final second = await service.runIfDue();

      expect(second.lastFileName, firstFile);
      expect(await service.listBackups(), hasLength(1));
    },
  );

  test(
    'rotates old backups but preserves the current and previous good copy',
    () async {
      final service = buildService(retention: 1);

      await service.runIfDue(force: true);
      now = now.add(const Duration(days: 1));
      await service.runIfDue(force: true);

      expect(await service.listBackups(), hasLength(2));

      now = now.add(const Duration(days: 1));
      await service.runIfDue(force: true);

      final files = await service.listBackups();
      expect(files, hasLength(2));
      expect(files.map((file) => file.name), contains(contains('id-2')));
    },
  );

  test('records a failure without deleting the previous backup', () async {
    final service = buildService();
    await service.runIfDue(force: true);
    final previous = await service.listBackups();

    final failing = buildService(store: _FailingStore());
    now = now.add(const Duration(days: 1));
    final status = await failing.runIfDue(force: true);

    expect(status.hasError, isTrue);
    expect(status.lastError, contains('disk full'));
    expect(status.consecutiveFailures, 1);
    expect(await service.listBackups(), hasLength(previous.length));
  });

  test('catalogues, restores, and deletes selected backups', () async {
    await database
        .into(database.tasks)
        .insert(
          TasksCompanion.insert(
            id: 't1',
            title: 'Task',
            createdAt: DateTime.utc(2026, 11, 1),
            updatedAt: DateTime.utc(2026, 11, 1),
          ),
        );
    final service = buildService();
    await service.runIfDue(force: true);

    final entries = await service.catalogue();
    expect(entries, hasLength(1));
    expect(entries.single.isVerified, isTrue);
    expect(entries.single.preview!.taskCount, 1);
    expect(entries.single.preview!.createdAt, isNotNull);

    await database.delete(database.tasks).go();
    expect(await database.select(database.tasks).get(), isEmpty);

    await service.restoreBackup(entries.single.file);
    expect(await database.select(database.tasks).get(), hasLength(1));

    await service.deleteBackup(entries.single.file);
    expect(await service.listBackups(), isEmpty);
  });

  test('keeps unreadable files visible with an error', () async {
    final directory = Directory('${root.path}/systum_backups');
    await directory.create(recursive: true);
    await File(
      '${directory.path}/${LocalAutomaticBackupStore.filePrefix}broken.json',
    ).writeAsString('not-json');

    final entries = await buildService().catalogue();

    expect(entries, hasLength(1));
    expect(entries.single.preview, isNull);
    expect(entries.single.error, isNotNull);
  });

  test('reconciles interrupted temporary writes only', () async {
    final directory = Directory('${root.path}/systum_backups');
    await directory.create(recursive: true);
    final temporary = File(
      '${directory.path}/.${LocalAutomaticBackupStore.filePrefix}partial.json'
      '${LocalAutomaticBackupStore.temporarySuffix}',
    );
    final owned = File(
      '${directory.path}/${LocalAutomaticBackupStore.filePrefix}kept.json',
    );
    await temporary.writeAsString('partial');
    await owned.writeAsString('{}');

    final service = buildService();
    await service.reconcileInterruptedWrites();

    expect(await temporary.exists(), isFalse);
    expect(await owned.exists(), isTrue);
  });

  test('reports malformed persisted status instead of hiding it', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesAutomaticBackupStatusStore.key: 'not-json',
    });

    final status = await buildService().status();

    expect(status.hasError, isTrue);
    expect(status.lastError, contains('could not be read'));
  });
}

final class _FailingStore implements AutomaticBackupStore {
  @override
  Future<List<AutomaticBackupFile>> list() async => const [];

  @override
  Future<AutomaticBackupFile> writeAtomic(String name, List<int> bytes) {
    throw const FileSystemException('disk full');
  }

  @override
  Future<List<int>> read(String path) async => const [];

  @override
  Future<void> delete(AutomaticBackupFile file) async {}

  @override
  Future<void> cleanTemporaryFiles() async {}

  @override
  Future<int> totalSizeBytes() async => 0;
}
