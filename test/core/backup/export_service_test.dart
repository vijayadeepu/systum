import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:systum/core/backup/backup_service.dart';
import 'package:systum/core/backup/export_journal.dart';
import 'package:systum/core/backup/export_service.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/focus/repository/pomodoro_settings_store.dart';

void main() {
  late SystumDatabase database;
  late BackupService backupService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = SystumDatabase.test(NativeDatabase.memory());
    backupService = BackupService(database, PomodoroSettingsStore());
  });

  tearDown(() => database.close());

  test(
    'stages, verifies, publishes, and cleans a destination-verified export',
    () async {
      final storage = _MemoryExportStorage();
      final publisher = _MemoryPublisher(readback: true);
      final journal = _MemoryExportJournalStore();
      final service = ExportService(
        backupService,
        storage: storage,
        publisher: publisher,
        journalStore: journal,
        operationIdGenerator: () => 'operation-1',
      );

      final result = await service.export(
        selectDestination: () async => 'destination-1',
      );

      expect(result.outcome, ExportOutcome.completed);
      expect(
        result.verificationLevel,
        ExportVerificationLevel.destinationVerified,
      );
      expect(publisher.destinations, contains('destination-1'));
      expect(storage.files, isEmpty);
      expect(journal.value, isNull);
    },
  );

  test(
    'retains a verified staged copy when destination readback is unavailable',
    () async {
      final storage = _MemoryExportStorage();
      final publisher = _MemoryPublisher(readback: false);
      final journal = _MemoryExportJournalStore();
      final service = ExportService(
        backupService,
        storage: storage,
        publisher: publisher,
        journalStore: journal,
        operationIdGenerator: () => 'operation-2',
      );

      final result = await service.export(
        selectDestination: () async => 'provider-document',
      );

      expect(result.outcome, ExportOutcome.stagedOnly);
      expect(
        result.verificationLevel,
        ExportVerificationLevel.destinationWriteCompleted,
      );
      expect(result.stagingPath, isNotNull);
      expect(storage.files, isNotEmpty);
      expect(journal.value?.status, ExportJournalStatus.recoveryRequired);
    },
  );

  test('retains staging when destination readback fails', () async {
    final storage = _MemoryExportStorage();
    final publisher = _MemoryPublisher(readback: true)
      ..readbackResult = const ExportReadback.failed('provider disconnected');
    final journal = _MemoryExportJournalStore();
    final service = ExportService(
      backupService,
      storage: storage,
      publisher: publisher,
      journalStore: journal,
      operationIdGenerator: () => 'operation-readback-failure',
    );

    await expectLater(
      service.export(selectDestination: () async => 'destination'),
      throwsA(isA<ExportException>()),
    );
    expect(storage.files, isNotEmpty);
    expect(journal.value?.status, ExportJournalStatus.recoveryRequired);
  });

  test('resumes a retained staged export after startup recovery', () async {
    final storage = _MemoryExportStorage();
    final publisher = _MemoryPublisher(readback: true);
    final journal = _MemoryExportJournalStore();
    final encoded = await backupService.createBackup();
    final bytes = utf8.encode(encoded);
    storage.files['retained.staging'] = [...bytes];
    journal.value = ExportJournal(
      operationId: 'retained-operation',
      schemaVersion: ExportJournal.currentSchemaVersion,
      status: ExportJournalStatus.recoveryRequired,
      createdAtMs: 1,
      updatedAtMs: 1,
      stagingPath: 'retained.staging',
      expectedLength: bytes.length,
      expectedSha256: _sha256(bytes),
    );
    final service = ExportService(
      backupService,
      storage: storage,
      publisher: publisher,
      journalStore: journal,
      operationIdGenerator: () => 'new-operation',
    );

    final result = await service.export(
      selectDestination: () async => 'resumed-destination',
    );

    expect(result.outcome, ExportOutcome.completed);
    expect(result.operationId, 'retained-operation');
    expect(journal.value, isNull);
    expect(storage.files, isEmpty);
  });

  test('publication failure preserves a verified staged copy', () async {
    final storage = _MemoryExportStorage();
    final publisher = _MemoryPublisher(readback: true)..failPublish = true;
    final journal = _MemoryExportJournalStore();
    final service = ExportService(
      backupService,
      storage: storage,
      publisher: publisher,
      journalStore: journal,
      operationIdGenerator: () => 'publication-failure',
    );

    await expectLater(
      service.export(selectDestination: () async => 'destination'),
      throwsA(isA<ExportException>()),
    );
    expect(storage.files, isNotEmpty);
    expect(journal.value?.status, ExportJournalStatus.recoveryRequired);
  });

  test(
    'destination checksum mismatch retains staging and recovery journal',
    () async {
      final storage = _MemoryExportStorage();
      final publisher = _MemoryPublisher(readback: true)
        ..readbackResult = const ExportReadback.available([1, 2, 3]);
      final journal = _MemoryExportJournalStore();
      final service = ExportService(
        backupService,
        storage: storage,
        publisher: publisher,
        journalStore: journal,
        operationIdGenerator: () => 'destination-mismatch',
      );

      await expectLater(
        service.export(selectDestination: () async => 'destination'),
        throwsA(isA<ExportException>()),
      );
      expect(storage.files, isNotEmpty);
      expect(journal.value?.status, ExportJournalStatus.recoveryRequired);
    },
  );

  test('corrupt and unsupported export journals are not ignored', () async {
    final storage = _MemoryExportStorage();
    final journal = _MemoryExportJournalStore()..throwOnLoad = true;
    final service = ExportService(
      backupService,
      storage: storage,
      journalStore: journal,
    );

    await expectLater(
      service.reconcilePendingExport(),
      throwsA(isA<ExportJournalException>()),
    );

    expect(
      () => ExportJournal.fromJson({
        'operationId': 'unsupported',
        'schemaVersion': 99,
        'status': 'staging',
        'createdAtMs': 1,
        'updatedAtMs': 1,
        'stagingPath': 'unsupported.staging',
        'expectedLength': 0,
        'expectedSha256':
            '0000000000000000000000000000000000000000000000000000000000000000',
      }),
      throwsA(isA<ExportJournalException>()),
    );
  });

  test('cancellation removes only the staged operation', () async {
    final storage = _MemoryExportStorage();
    final journal = _MemoryExportJournalStore();
    final service = ExportService(
      backupService,
      storage: storage,
      journalStore: journal,
      operationIdGenerator: () => 'operation-3',
    );

    final result = await service.export(selectDestination: () async => null);

    expect(result.outcome, ExportOutcome.cancelled);
    expect(storage.files, isEmpty);
    expect(journal.value, isNull);
  });

  test('startup recovery preserves a valid staged file idempotently', () async {
    final storage = _MemoryExportStorage();
    final journal = _MemoryExportJournalStore();
    final encoded = await backupService.createBackup();
    final bytes = utf8.encode(encoded);
    storage.files['stale.staging'] = bytes;
    final checksum = _sha256(bytes);
    journal.value = ExportJournal(
      operationId: 'operation-4',
      schemaVersion: ExportJournal.currentSchemaVersion,
      status: ExportJournalStatus.publishing,
      createdAtMs: 1,
      updatedAtMs: 1,
      stagingPath: 'stale.staging',
      expectedLength: bytes.length,
      expectedSha256: checksum,
    );
    final service = ExportService(
      backupService,
      storage: storage,
      journalStore: journal,
    );

    await expectLater(
      service.reconcilePendingExport(),
      throwsA(isA<ExportRecoveryRequiredException>()),
    );
    await expectLater(
      service.reconcilePendingExport(),
      throwsA(isA<ExportRecoveryRequiredException>()),
    );

    expect(storage.files, contains('stale.staging'));
    expect(journal.value?.status, ExportJournalStatus.recoveryRequired);
  });

  test('startup recovery removes an incomplete staged file', () async {
    final storage = _MemoryExportStorage()..files['broken.staging'] = [1, 2, 3];
    final journal = _MemoryExportJournalStore();
    journal.value = const ExportJournal(
      operationId: 'operation-5',
      schemaVersion: ExportJournal.currentSchemaVersion,
      status: ExportJournalStatus.staging,
      createdAtMs: 1,
      updatedAtMs: 1,
      stagingPath: 'broken.staging',
      expectedLength: 10,
      expectedSha256:
          '0000000000000000000000000000000000000000000000000000000000000000',
    );
    final service = ExportService(
      backupService,
      storage: storage,
      journalStore: journal,
    );

    await service.reconcilePendingExport();

    expect(storage.files, isEmpty);
    expect(journal.value, isNull);
  });

  test('startup cleanup removes strictly-owned orphan staging files', () async {
    final storage = _MemoryExportStorage()
      ..files['orphan.staging'] = [1, 2, 3]
      ..files['user-selected.json'] = [4, 5, 6];
    final journal = _MemoryExportJournalStore();
    final service = ExportService(
      backupService,
      storage: storage,
      journalStore: journal,
    );

    await service.reconcilePendingExport();

    expect(storage.files, {
      'user-selected.json': [4, 5, 6],
    });
  });
}

String _sha256(List<int> bytes) {
  return sha256.convert(bytes).toString();
}

final class _MemoryExportStorage implements ExportStorage {
  final files = <String, List<int>>{};

  @override
  Future<String> createStagingPath(String operationId) async =>
      '$operationId.staging';

  @override
  Future<void> write(String path, List<int> bytes) async {
    if (files.containsKey(path)) throw StateError('already exists');
    files[path] = [...bytes];
  }

  @override
  Future<List<int>> read(String path) async => [...files[path]!];

  @override
  Future<bool> exists(String path) async => files.containsKey(path);

  @override
  Future<void> delete(String path) async => files.remove(path);

  @override
  Future<List<String>> listStagingPaths() async =>
      files.keys.where((path) => path.endsWith('.staging')).toList();
}

final class _MemoryPublisher implements ExportPublisher {
  _MemoryPublisher({required this.readback});

  final bool readback;
  final destinations = <String, List<int>>{};
  ExportReadback? readbackResult;
  bool failPublish = false;

  @override
  Future<void> publish(List<int> bytes, String destination) async {
    if (failPublish) throw const ExportException('provider write failed');
    destinations[destination] = [...bytes];
  }

  @override
  Future<ExportReadback> readBack(String destination) async =>
      readbackResult ??
      (readback
          ? ExportReadback.available([...destinations[destination]!])
          : const ExportReadback.unavailable());
}

final class _MemoryExportJournalStore implements ExportJournalStore {
  ExportJournal? value;
  bool throwOnLoad = false;

  @override
  Future<ExportJournal?> load() async {
    if (throwOnLoad) throw const ExportJournalException('corrupt journal');
    return value;
  }

  @override
  Future<void> save(ExportJournal journal) async => value = journal;

  @override
  Future<void> clear() async => value = null;
}
