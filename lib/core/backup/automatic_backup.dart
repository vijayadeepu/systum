import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/utils/id_generator.dart';
import 'backup_service.dart';

/// Metadata for one app-private automatic backup file.
final class AutomaticBackupFile {
  const AutomaticBackupFile({
    required this.name,
    required this.path,
    required this.createdAt,
    required this.sizeBytes,
  });

  final String name;
  final String path;
  final DateTime createdAt;
  final int sizeBytes;
}

/// A catalogue entry with metadata read from the backup document.
final class AutomaticBackupEntry {
  const AutomaticBackupEntry({required this.file, this.preview, this.error});

  final AutomaticBackupFile file;
  final BackupPreview? preview;
  final String? error;

  bool get isVerified => preview?.isVerified ?? false;
}

/// Result of an automatic backup attempt, persisted outside the database.
final class AutomaticBackupStatus {
  const AutomaticBackupStatus({
    this.lastAttemptAt,
    this.lastSuccessAt,
    this.lastFileName,
    this.lastSizeBytes,
    this.lastError,
    this.consecutiveFailures = 0,
    this.retentionWarning,
  });

  const AutomaticBackupStatus.empty() : this();

  final DateTime? lastAttemptAt;
  final DateTime? lastSuccessAt;
  final String? lastFileName;
  final int? lastSizeBytes;
  final String? lastError;
  final int consecutiveFailures;
  final String? retentionWarning;

  bool get hasError => lastError != null;
  bool get hasRetentionWarning => retentionWarning != null;

  AutomaticBackupStatus withAttempt(DateTime at) => AutomaticBackupStatus(
    lastAttemptAt: at,
    lastSuccessAt: lastSuccessAt,
    lastFileName: lastFileName,
    lastSizeBytes: lastSizeBytes,
    lastError: lastError,
    consecutiveFailures: consecutiveFailures,
    retentionWarning: retentionWarning,
  );

  AutomaticBackupStatus withSuccess({
    required DateTime at,
    required AutomaticBackupFile file,
    String? retentionWarning,
  }) => AutomaticBackupStatus(
    lastAttemptAt: at,
    lastSuccessAt: at,
    lastFileName: file.name,
    lastSizeBytes: file.sizeBytes,
    consecutiveFailures: 0,
    retentionWarning: retentionWarning,
  );

  AutomaticBackupStatus withFailure({
    required DateTime at,
    required String message,
  }) => AutomaticBackupStatus(
    lastAttemptAt: at,
    lastSuccessAt: lastSuccessAt,
    lastFileName: lastFileName,
    lastSizeBytes: lastSizeBytes,
    lastError: message,
    consecutiveFailures: consecutiveFailures + 1,
    retentionWarning: retentionWarning,
  );

  Map<String, Object?> toJson() => {
    'lastAttemptAtMs': lastAttemptAt?.toUtc().millisecondsSinceEpoch,
    'lastSuccessAtMs': lastSuccessAt?.toUtc().millisecondsSinceEpoch,
    'lastFileName': lastFileName,
    'lastSizeBytes': lastSizeBytes,
    'lastError': lastError,
    'consecutiveFailures': consecutiveFailures,
    'retentionWarning': retentionWarning,
  };

  factory AutomaticBackupStatus.fromJson(Map<String, Object?> json) {
    DateTime? readDate(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! int) {
        throw const FormatException('Automatic backup date is invalid.');
      }
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }

    String? readString(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! String) {
        throw const FormatException('Automatic backup status is invalid.');
      }
      return value;
    }

    final failures = json['consecutiveFailures'] ?? 0;
    final size = json['lastSizeBytes'];
    if (failures is! int || failures < 0) {
      throw const FormatException('Automatic backup failure count is invalid.');
    }
    if (size != null && (size is! int || size < 0)) {
      throw const FormatException('Automatic backup size is invalid.');
    }
    return AutomaticBackupStatus(
      lastAttemptAt: readDate('lastAttemptAtMs'),
      lastSuccessAt: readDate('lastSuccessAtMs'),
      lastFileName: readString('lastFileName'),
      lastSizeBytes: size as int?,
      lastError: readString('lastError'),
      consecutiveFailures: failures,
      retentionWarning: readString('retentionWarning'),
    );
  }
}

abstract interface class AutomaticBackupStatusStore {
  Future<AutomaticBackupStatus> load();
  Future<void> save(AutomaticBackupStatus status);
}

final class SharedPreferencesAutomaticBackupStatusStore
    implements AutomaticBackupStatusStore {
  static const key = 'systum.backup.automatic_status.v1';

  @override
  Future<AutomaticBackupStatus> load() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(key);
    if (value == null) return const AutomaticBackupStatus.empty();
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Automatic backup status is invalid.');
    }
    return AutomaticBackupStatus.fromJson(decoded);
  }

  @override
  Future<void> save(AutomaticBackupStatus status) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(key, jsonEncode(status.toJson()));
    if (!saved) {
      throw StateError('Could not save automatic backup status.');
    }
  }
}

/// App-private storage for automatic backups.
abstract interface class AutomaticBackupStore {
  Future<List<AutomaticBackupFile>> list();
  Future<AutomaticBackupFile> writeAtomic(String name, List<int> bytes);
  Future<List<int>> read(String path);
  Future<void> delete(AutomaticBackupFile file);
  Future<void> cleanTemporaryFiles();
  Future<int> totalSizeBytes();
}

final class LocalAutomaticBackupStore implements AutomaticBackupStore {
  LocalAutomaticBackupStore({
    Future<Directory> Function()? rootDirectory,
    this.folderName = 'systum_backups',
  }) : _rootDirectory = rootDirectory ?? getApplicationSupportDirectory;

  static const filePrefix = 'systum-auto-';
  static const fileSuffix = '.json';
  static const temporarySuffix = '.tmp';

  final Future<Directory> Function() _rootDirectory;
  final String folderName;

  Future<Directory> _directory() async {
    final root = await _rootDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}$folderName',
    );
    await directory.create(recursive: true);
    return directory;
  }

  bool _isOwnedName(String name) =>
      name.startsWith(filePrefix) && name.endsWith(fileSuffix);

  bool _isTemporaryName(String name) =>
      name.startsWith('.$filePrefix') && name.endsWith(temporarySuffix);

  @override
  Future<List<AutomaticBackupFile>> list() async {
    final directory = await _directory();
    if (!await directory.exists()) return const [];
    final files = <AutomaticBackupFile>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!_isOwnedName(name)) continue;
      final stat = await entity.stat();
      files.add(
        AutomaticBackupFile(
          name: name,
          path: entity.path,
          createdAt: stat.modified,
          sizeBytes: stat.size,
        ),
      );
    }
    files.sort((a, b) => b.name.compareTo(a.name));
    return files;
  }

  @override
  Future<AutomaticBackupFile> writeAtomic(String name, List<int> bytes) async {
    if (!_isOwnedName(name) || name.contains(Platform.pathSeparator)) {
      throw ArgumentError.value(name, 'name', 'Unsupported backup file name.');
    }
    final directory = await _directory();
    final target = File('${directory.path}${Platform.pathSeparator}$name');
    final temporary = File(
      '${directory.path}${Platform.pathSeparator}.$name$temporarySuffix',
    );
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      if (await target.exists()) {
        throw StateError('Automatic backup file already exists: $name');
      }
      await temporary.rename(target.path);
    } on Object {
      if (await temporary.exists()) {
        await temporary.delete();
      }
      rethrow;
    }
    final stat = await target.stat();
    return AutomaticBackupFile(
      name: name,
      path: target.path,
      createdAt: stat.modified,
      sizeBytes: stat.size,
    );
  }

  @override
  Future<List<int>> read(String path) => File(path).readAsBytes();

  @override
  Future<void> delete(AutomaticBackupFile file) async {
    if (!_isOwnedName(file.name)) {
      throw ArgumentError.value(
        file.name,
        'file',
        'Refusing to delete a non-automatic backup file.',
      );
    }
    final target = File(file.path);
    if (await target.exists()) await target.delete();
  }

  @override
  Future<void> cleanTemporaryFiles() async {
    final directory = await _directory();
    if (!await directory.exists()) return;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (_isTemporaryName(name)) await entity.delete();
    }
  }

  @override
  Future<int> totalSizeBytes() async {
    final files = await list();
    return files.fold<int>(0, (total, file) => total + file.sizeBytes);
  }
}

/// Creates verified, app-private automatic backups and rotates old copies.
///
/// This is deliberately lifecycle-driven rather than a background service.
/// Callers run it at startup and may force it from user-facing controls.
final class AutomaticBackupService {
  AutomaticBackupService(
    this._backupService, {
    AutomaticBackupStore? store,
    AutomaticBackupStatusStore? statusStore,
    DateTime Function()? clock,
    String Function()? idGenerator,
    this.minimumInterval = const Duration(hours: 24),
    this.retryBackoff = const Duration(minutes: 15),
    this.retention = 5,
  }) : _store = store ?? LocalAutomaticBackupStore(),
       _statusStore =
           statusStore ?? SharedPreferencesAutomaticBackupStatusStore(),
       _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? generateId;

  final BackupService _backupService;
  final AutomaticBackupStore _store;
  final AutomaticBackupStatusStore _statusStore;
  final DateTime Function() _clock;
  final String Function() _idGenerator;
  final Duration minimumInterval;
  final Duration retryBackoff;
  final int retention;

  Future<AutomaticBackupStatus>? _inFlight;

  Future<AutomaticBackupStatus> status() async {
    try {
      return await _statusStore.load();
    } on Object catch (error) {
      return AutomaticBackupStatus(
        lastError:
            'Automatic backup status could not be read: '
            '${_describe(error)}',
      );
    }
  }

  Future<void> reconcileInterruptedWrites() => _store.cleanTemporaryFiles();

  Future<List<AutomaticBackupFile>> listBackups() => _store.list();

  Future<int> storageUsageBytes() => _store.totalSizeBytes();

  /// Reads and validates every retained backup for display. Invalid files stay
  /// visible so the user can identify and delete them.
  Future<List<AutomaticBackupEntry>> catalogue() async {
    final files = await _store.list();
    final entries = <AutomaticBackupEntry>[];
    for (final file in files) {
      try {
        final preview = await _backupService.inspect(
          utf8.decode(await _store.read(file.path)),
        );
        entries.add(AutomaticBackupEntry(file: file, preview: preview));
      } on Object catch (error) {
        entries.add(AutomaticBackupEntry(file: file, error: _describe(error)));
      }
    }
    return entries;
  }

  Future<void> restoreBackup(AutomaticBackupFile file) async {
    final encoded = utf8.decode(await _store.read(file.path));
    await _backupService.restore(encoded, overwriteExisting: true);
  }

  Future<void> deleteBackup(AutomaticBackupFile file) => _store.delete(file);

  /// Runs at most one automatic backup at a time.
  ///
  /// A failure is stored in [AutomaticBackupStatus.lastError] instead of
  /// escaping, so startup recovery can continue and the Backup screen can show
  /// an actionable message.
  Future<AutomaticBackupStatus> runIfDue({bool force = false}) async {
    if (_inFlight case final running?) return running;
    final future = _run(force: force);
    _inFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight, future)) _inFlight = null;
    }
  }

  Future<AutomaticBackupStatus> _run({required bool force}) async {
    AutomaticBackupStatus status;
    try {
      status = await _statusStore.load();
    } on Object catch (error) {
      status = AutomaticBackupStatus(
        lastError:
            'Automatic backup status could not be read: '
            '${_describe(error)}',
      );
    }

    final now = _clock().toUtc();
    if (!force && !_isDue(status, now)) return status;

    final attempt = status.withAttempt(now);
    try {
      await _statusStore.save(attempt);
    } on Object catch (error) {
      return attempt.withFailure(
        at: now,
        message: 'Could not record the backup attempt: ${_describe(error)}',
      );
    }

    try {
      await _store.cleanTemporaryFiles();
      final encoded = await _backupService.createBackup();
      final bytes = utf8.encode(encoded);
      final name =
          '${LocalAutomaticBackupStore.filePrefix}'
          '${_timestamp(now)}_${_idGenerator()}'
          '${LocalAutomaticBackupStore.fileSuffix}';
      final file = await _store.writeAtomic(name, bytes);

      // Verify the app-private copy through the same reader used by restore.
      final readBack = await _store.read(file.path);
      final validation = await _backupService.validate(utf8.decode(readBack));
      if (!validation.isVerified) {
        throw const BackupValidationException(
          'The automatic backup could not be integrity verified.',
        );
      }

      final retentionWarning = await _rotate(
        current: file,
        previousLastGoodName: status.lastFileName,
      );
      final success = attempt.withSuccess(
        at: now,
        file: file,
        retentionWarning: retentionWarning,
      );
      await _statusStore.save(success);
      return success;
    } on Object catch (error) {
      final failure = attempt.withFailure(at: now, message: _describe(error));
      try {
        await _statusStore.save(failure);
      } on Object {
        // The original failure is more actionable than a status write error.
      }
      return failure;
    }
  }

  bool _isDue(AutomaticBackupStatus status, DateTime now) {
    final lastSuccess = status.lastSuccessAt;
    if (lastSuccess == null) return true;
    final elapsed = now.difference(lastSuccess);
    if (elapsed.isNegative || elapsed >= minimumInterval) return true;
    final lastAttempt = status.lastAttemptAt;
    if (status.hasError &&
        lastAttempt != null &&
        now.difference(lastAttempt) >= retryBackoff) {
      return true;
    }
    return false;
  }

  Future<String?> _rotate({
    required AutomaticBackupFile current,
    required String? previousLastGoodName,
  }) async {
    final files = await _store.list();
    if (files.length <= 1) return null;

    final protectedNames = {current.name, ?previousLastGoodName};
    final keep = <String>{};
    for (final file in files) {
      if (keep.length < retention || protectedNames.contains(file.name)) {
        keep.add(file.name);
      }
    }
    if (keep.isEmpty) keep.add(current.name);

    String? warning;
    for (final file in files) {
      if (keep.contains(file.name)) continue;
      try {
        await _store.delete(file);
      } on Object catch (error) {
        warning =
            'An older automatic backup could not be removed: ${_describe(error)}';
      }
    }
    return warning;
  }

  String _timestamp(DateTime value) {
    final utc = value.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}'
        '${utc.month.toString().padLeft(2, '0')}'
        '${utc.day.toString().padLeft(2, '0')}T'
        '${utc.hour.toString().padLeft(2, '0')}'
        '${utc.minute.toString().padLeft(2, '0')}'
        '${utc.second.toString().padLeft(2, '0')}'
        '${utc.millisecond.toString().padLeft(3, '0')}Z';
  }

  String _describe(Object error) => switch (error) {
    BackupValidationException(:final message) => message,
    FileSystemException(:final message, :final path) =>
      path == null ? message : '$message ($path)',
    _ => error.toString(),
  };
}
