import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

import 'android_document_export.dart';
import 'backup_service.dart';
import 'export_journal.dart';

enum ExportVerificationLevel {
  stagingVerified,
  destinationWriteCompleted,
  destinationVerified,
}

enum ExportOutcome { completed, stagedOnly, cancelled }

enum ExportReadbackStatus { available, unavailable, failed }

final class ExportReadback {
  const ExportReadback._(this.status, this.bytes, this.error);

  const ExportReadback.available(List<int> bytes)
    : this._(ExportReadbackStatus.available, bytes, null);

  const ExportReadback.unavailable()
    : this._(ExportReadbackStatus.unavailable, null, null);

  const ExportReadback.failed(Object error)
    : this._(ExportReadbackStatus.failed, null, error);

  final ExportReadbackStatus status;
  final List<int>? bytes;
  final Object? error;
}

final class ExportResult {
  const ExportResult({
    required this.outcome,
    required this.verificationLevel,
    required this.operationId,
    this.stagingPath,
  });

  final ExportOutcome outcome;
  final ExportVerificationLevel verificationLevel;
  final String operationId;
  final String? stagingPath;
}

abstract interface class ExportStorage {
  Future<String> createStagingPath(String operationId);

  Future<void> write(String path, List<int> bytes);

  Future<List<int>> read(String path);

  Future<bool> exists(String path);

  Future<void> delete(String path);

  Future<List<String>> listStagingPaths();
}

abstract interface class ExportPublisher {
  Future<void> publish(List<int> bytes, String destination);

  /// Returns an explicit capability/result classification for destination
  /// readback. Providers may accept writes without exposing a reopenable path.
  Future<ExportReadback> readBack(String destination);
}

final class LocalExportStorage implements ExportStorage {
  static const _directoryName = 'systum_backup_exports';
  static const _prefix = 'systum-export-';
  static const _suffix = '.staging';

  Future<Directory> _directory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/$_directoryName');
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<String> createStagingPath(String operationId) async {
    final directory = await _directory();
    return '${directory.path}/$_prefix$operationId$_suffix';
  }

  @override
  Future<void> write(String path, List<int> bytes) async {
    await File(path).writeAsBytes(bytes, flush: true);
  }

  @override
  Future<List<int>> read(String path) => File(path).readAsBytes();

  @override
  Future<bool> exists(String path) => File(path).exists();

  @override
  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<List<String>> listStagingPaths() async {
    final directory = await _directory();
    return directory
        .list()
        .where(
          (entity) =>
              entity is File &&
              entity.uri.pathSegments.last.startsWith(_prefix) &&
              entity.path.endsWith(_suffix),
        )
        .map((entity) => entity.path)
        .toList();
  }
}

final class FileSelectorExportPublisher implements ExportPublisher {
  @override
  Future<void> publish(List<int> bytes, String destination) {
    return XFile.fromData(
      Uint8List.fromList(bytes),
      name: 'systum-backup.json',
      mimeType: 'application/json',
    ).saveTo(destination);
  }

  @override
  Future<ExportReadback> readBack(String destination) async {
    try {
      return ExportReadback.available(await XFile(destination).readAsBytes());
    } on Object {
      // Document providers may accept writes without exposing a reopenable
      // filesystem path. This is an explicit Level 2 outcome.
      return const ExportReadback.unavailable();
    }
  }
}

ExportPublisher createDefaultExportPublisher() {
  if (Platform.isAndroid) return AndroidExportPublisher();
  return FileSelectorExportPublisher();
}

final class ExportService {
  ExportService(
    this._backupService, {
    ExportStorage? storage,
    ExportPublisher? publisher,
    ExportJournalStore? journalStore,
    String Function()? operationIdGenerator,
    DateTime Function()? clock,
  }) : _storage = storage ?? LocalExportStorage(),
       _publisher = publisher ?? createDefaultExportPublisher(),
       _journalStore = journalStore ?? SharedPreferencesExportJournalStore(),
       _operationIdGenerator = operationIdGenerator ?? _defaultOperationId,
       _clock = clock ?? DateTime.now;

  final BackupService _backupService;
  final ExportStorage _storage;
  final ExportPublisher _publisher;
  final ExportJournalStore _journalStore;
  final String Function() _operationIdGenerator;
  final DateTime Function() _clock;
  bool _busy = false;

  Future<ExportResult> export({
    required Future<String?> Function() selectDestination,
  }) async {
    if (_busy) {
      throw const ExportException('Another backup export is already running.');
    }
    _busy = true;
    final operationId = _operationIdGenerator();
    String? stagingPath;
    try {
      final pending = await _journalStore.load();
      if (pending != null &&
          pending.status == ExportJournalStatus.recoveryRequired) {
        return _resumePendingExport(pending, selectDestination);
      }
      if (pending != null) {
        throw const ExportException(
          'A previous export is awaiting recovery. Reopen the app to review it before exporting again.',
        );
      }
      final encoded = await _backupService.createBackup();
      final bytes = utf8.encode(encoded);
      final validation = await _backupService.validate(encoded);
      if (!validation.isVerified) {
        throw const ExportException(
          'Generated backup is not integrity verified.',
        );
      }
      final expectedLength = bytes.length;
      final expectedSha256 = sha256.convert(bytes).toString();
      var journal = ExportJournal(
        operationId: operationId,
        schemaVersion: ExportJournal.currentSchemaVersion,
        status: ExportJournalStatus.prepared,
        createdAtMs: _nowMs,
        updatedAtMs: _nowMs,
        stagingPath: '',
        expectedLength: bytes.length,
        expectedSha256: expectedSha256,
      );
      stagingPath = await _storage.createStagingPath(operationId);
      journal = ExportJournal(
        operationId: journal.operationId,
        schemaVersion: journal.schemaVersion,
        status: journal.status,
        createdAtMs: journal.createdAtMs,
        updatedAtMs: journal.updatedAtMs,
        stagingPath: stagingPath,
        expectedLength: journal.expectedLength,
        expectedSha256: journal.expectedSha256,
      );
      await _journalStore.save(journal);
      journal = journal.copyWith(
        status: ExportJournalStatus.staging,
        updatedAtMs: _nowMs,
      );
      await _journalStore.save(journal);
      await _storage.write(stagingPath, bytes);
      await _verifyBytes(stagingPath, expectedLength, expectedSha256);
      journal = journal.copyWith(
        status: ExportJournalStatus.stagingVerified,
        updatedAtMs: _nowMs,
      );
      await _journalStore.save(journal);
      final destination = await selectDestination();
      if (destination == null) {
        await _journalStore.clear();
        await _storage.delete(stagingPath);
        return ExportResult(
          outcome: ExportOutcome.cancelled,
          verificationLevel: ExportVerificationLevel.stagingVerified,
          operationId: operationId,
        );
      }
      journal = journal.copyWith(
        status: ExportJournalStatus.publishing,
        destinationPath: destination,
        updatedAtMs: _nowMs,
      );
      await _journalStore.save(journal);
      await _publisher.publish(bytes, destination);
      journal = journal.copyWith(
        status: ExportJournalStatus.destinationWriteCompleted,
        updatedAtMs: _nowMs,
        destinationVerification: 'write_completed',
      );
      await _journalStore.save(journal);
      final readback = await _publisher.readBack(destination);
      if (readback.status == ExportReadbackStatus.unavailable) {
        await _journalStore.save(
          journal.copyWith(
            status: ExportJournalStatus.recoveryRequired,
            updatedAtMs: _nowMs,
          ),
        );
        return ExportResult(
          outcome: ExportOutcome.stagedOnly,
          verificationLevel: ExportVerificationLevel.destinationWriteCompleted,
          operationId: operationId,
          stagingPath: stagingPath,
        );
      }
      if (readback.status == ExportReadbackStatus.failed) {
        throw ExportException(
          'Destination readback failed: ${readback.error ?? 'unknown error'}',
        );
      }
      _verifyByteList(readback.bytes!, expectedLength, expectedSha256);
      journal = journal.copyWith(
        status: ExportJournalStatus.destinationVerified,
        updatedAtMs: _nowMs,
        destinationVerification: 'verified',
      );
      await _journalStore.save(journal);
      await _journalStore.save(
        journal.copyWith(
          status: ExportJournalStatus.completed,
          updatedAtMs: _nowMs,
        ),
      );
      await _journalStore.clear();
      await _storage.delete(stagingPath);
      return ExportResult(
        outcome: ExportOutcome.completed,
        verificationLevel: ExportVerificationLevel.destinationVerified,
        operationId: operationId,
      );
    } catch (error, stackTrace) {
      if (stagingPath != null) {
        try {
          final exists = await _storage.exists(stagingPath);
          if (exists) {
            // Keep a verified staging file available after publication or
            // readback failure; it is safer than deleting the only good copy.
            final journal = await _journalStore.load();
            if (journal?.status == ExportJournalStatus.stagingVerified ||
                journal?.status == ExportJournalStatus.publishing ||
                journal?.status ==
                    ExportJournalStatus.destinationWriteCompleted) {
              await _journalStore.save(
                journal!.copyWith(
                  status: ExportJournalStatus.recoveryRequired,
                  updatedAtMs: _nowMs,
                ),
              );
            } else {
              await _storage.delete(stagingPath);
              await _journalStore.clear();
            }
          }
        } catch (_) {
          // Preserve the original failure and leave journal evidence intact.
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      _busy = false;
    }
  }

  Future<void> reconcilePendingExport() async {
    final journal = await _journalStore.load();
    if (journal == null) {
      // Under this subsystem's protocol, a journal is created before any
      // staging write and is cleared only after cancellation cleanup or a
      // destination-verified completion. Strictly named orphan files are
      // therefore abandoned export artifacts, not user-selected destinations.
      for (final path in await _storage.listStagingPaths()) {
        await _storage.delete(path);
      }
      return;
    }
    if (journal.stagingPath.isEmpty) {
      await _journalStore.clear();
      return;
    }
    final exists = await _storage.exists(journal.stagingPath);
    if (!exists) {
      await _journalStore.clear();
      return;
    }
    if (journal.status == ExportJournalStatus.destinationVerified ||
        journal.status == ExportJournalStatus.completed) {
      await _storage.delete(journal.stagingPath);
      await _journalStore.clear();
      return;
    }
    try {
      await _verifyBytes(
        journal.stagingPath,
        journal.expectedLength,
        journal.expectedSha256,
      );
    } catch (_) {
      await _storage.delete(journal.stagingPath);
      await _journalStore.clear();
      return;
    }
    // A verified staged file is intentionally retained. The next export can
    // proceed, while the user can still recover this known-good copy manually.
    await _journalStore.save(
      journal.copyWith(
        status: ExportJournalStatus.recoveryRequired,
        updatedAtMs: _nowMs,
      ),
    );
    throw const ExportRecoveryRequiredException(
      'A verified staged backup is available after an interrupted export.',
    );
  }

  Future<ExportResult> _resumePendingExport(
    ExportJournal journal,
    Future<String?> Function() selectDestination,
  ) async {
    if (!await _storage.exists(journal.stagingPath)) {
      await _journalStore.clear();
      throw const ExportException('The retained staged backup is unavailable.');
    }
    try {
      await _verifyBytes(
        journal.stagingPath,
        journal.expectedLength,
        journal.expectedSha256,
      );
    } catch (_) {
      await _storage.delete(journal.stagingPath);
      await _journalStore.clear();
      throw const ExportException('The retained staged backup is corrupt.');
    }
    final destination = await selectDestination();
    if (destination == null) {
      return ExportResult(
        outcome: ExportOutcome.cancelled,
        verificationLevel: ExportVerificationLevel.stagingVerified,
        operationId: journal.operationId,
        stagingPath: journal.stagingPath,
      );
    }
    final bytes = await _storage.read(journal.stagingPath);
    var current = journal.copyWith(
      status: ExportJournalStatus.publishing,
      destinationPath: destination,
      updatedAtMs: _nowMs,
    );
    await _journalStore.save(current);
    try {
      await _publisher.publish(bytes, destination);
      current = current.copyWith(
        status: ExportJournalStatus.destinationWriteCompleted,
        destinationVerification: 'write_completed',
        updatedAtMs: _nowMs,
      );
      await _journalStore.save(current);
      final readback = await _publisher.readBack(destination);
      if (readback.status == ExportReadbackStatus.unavailable) {
        await _journalStore.save(
          current.copyWith(
            status: ExportJournalStatus.recoveryRequired,
            updatedAtMs: _nowMs,
          ),
        );
        return ExportResult(
          outcome: ExportOutcome.stagedOnly,
          verificationLevel: ExportVerificationLevel.destinationWriteCompleted,
          operationId: journal.operationId,
          stagingPath: journal.stagingPath,
        );
      }
      if (readback.status == ExportReadbackStatus.failed) {
        throw ExportException(
          'Destination readback failed: ${readback.error ?? 'unknown error'}',
        );
      }
      _verifyByteList(
        readback.bytes!,
        journal.expectedLength,
        journal.expectedSha256,
      );
      current = current.copyWith(
        status: ExportJournalStatus.destinationVerified,
        destinationVerification: 'verified',
        updatedAtMs: _nowMs,
      );
      await _journalStore.save(current);
      await _journalStore.save(
        current.copyWith(
          status: ExportJournalStatus.completed,
          updatedAtMs: _nowMs,
        ),
      );
      await _journalStore.clear();
      await _storage.delete(journal.stagingPath);
      return ExportResult(
        outcome: ExportOutcome.completed,
        verificationLevel: ExportVerificationLevel.destinationVerified,
        operationId: journal.operationId,
      );
    } catch (error, stackTrace) {
      await _journalStore.save(
        current.copyWith(
          status: ExportJournalStatus.recoveryRequired,
          updatedAtMs: _nowMs,
        ),
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _verifyBytes(
    String path,
    int expectedLength,
    String expectedSha256,
  ) async {
    final bytes = await _storage.read(path);
    _verifyByteList(bytes, expectedLength, expectedSha256);
  }

  static void _verifyByteList(
    List<int> bytes,
    int expectedLength,
    String expectedSha256,
  ) {
    if (bytes.length != expectedLength) {
      throw const ExportException('Backup byte length verification failed.');
    }
    if (sha256.convert(bytes).toString() != expectedSha256) {
      throw const ExportException('Backup checksum verification failed.');
    }
  }

  int get _nowMs => _clock().toUtc().millisecondsSinceEpoch;

  static String _defaultOperationId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${DateTime.now().millisecond}';
}

class ExportException implements Exception {
  const ExportException(this.message);

  final String message;

  @override
  String toString() => 'ExportException: $message';
}

class ExportRecoveryRequiredException implements Exception {
  const ExportRecoveryRequiredException(this.message);

  final String message;

  @override
  String toString() => 'ExportRecoveryRequiredException: $message';
}
