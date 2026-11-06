import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../features/focus/models/focus_session.dart';
import '../../features/focus/models/focus_session_interval.dart';
import '../../features/focus/models/focus_session_mode.dart';
import '../../features/focus/models/focus_session_status.dart';
import '../../features/focus/models/pomodoro_settings.dart';
import '../../features/focus/repository/focus_session_repository_support.dart';
import '../../features/focus/repository/pomodoro_settings_store.dart';
import '../../features/goals/models/goal_date.dart';
import '../../features/reminders/models/reminder.dart';
import '../../features/tasks/models/task_recurrence.dart';
import '../../core/database/database.dart';
import 'restore_journal.dart';

/// Whether a structurally valid backup has verifiable payload integrity.
enum BackupVerificationStatus { verified, legacyUnverified }

final class BackupValidationResult {
  const BackupValidationResult(this.status);

  final BackupVerificationStatus status;

  bool get isVerified => status == BackupVerificationStatus.verified;
}

/// Non-destructive metadata used by the backup catalogue.
final class BackupPreview {
  const BackupPreview({
    required this.verification,
    required this.createdAt,
    required this.appVersion,
    required this.schemaVersion,
    required this.taskCount,
    required this.goalCount,
    required this.focusSessionCount,
    required this.focusIntervalCount,
    this.reminderCount = 0,
  });

  final BackupVerificationStatus verification;
  final DateTime? createdAt;
  final String? appVersion;
  final int schemaVersion;
  final int taskCount;
  final int goalCount;
  final int focusSessionCount;
  final int focusIntervalCount;
  final int reminderCount;

  bool get isVerified => verification == BackupVerificationStatus.verified;
}

/// Versioned, local-only export and restore for all user-owned Systum data.
final class BackupService {
  BackupService(
    this._database,
    this._settingsStore, {
    RestoreJournalStore? journalStore,
    String Function()? operationIdGenerator,
    DateTime Function()? clock,
  }) : _journalStore = journalStore ?? SharedPreferencesRestoreJournalStore(),
       _operationIdGenerator = operationIdGenerator ?? _defaultOperationId,
       _clock = clock ?? DateTime.now;

  static const format = 'systum-backup';
  static const currentVersion = 1;
  static const appVersion = '0.1.0+1';
  static const payloadEncoding = 'utf-8-json';
  static const integrityAlgorithm = 'sha256';

  /// Upper bound for an import document.
  ///
  /// A local file is still untrusted input: rejecting oversized documents
  /// before JSON decoding prevents an accidental or malicious file from
  /// exhausting memory while the database transaction has not started.
  static const maxImportBytes = 64 * 1024 * 1024;

  static bool isDocumentWithinLimit(int length) =>
      length >= 0 && length <= maxImportBytes;

  final SystumDatabase _database;
  final PomodoroSettingsStore _settingsStore;
  final RestoreJournalStore _journalStore;
  final String Function() _operationIdGenerator;
  final DateTime Function() _clock;

  Future<String> createBackup() async {
    final data = await _database.transaction(() async {
      final goals = await _database.select(_database.goals).get();
      final tasks = await _database.select(_database.tasks).get();
      final sessions = await _database.select(_database.focusSessions).get();
      final intervals = await _database
          .select(_database.focusSessionIntervals)
          .get();
      final rules = await _database.select(_database.taskRecurrenceRules).get();
      final occurrences = await _database
          .select(_database.taskOccurrences)
          .get();
      final reminders = await _database.select(_database.reminders).get();
      return {
        'goals': goals.map(_goalToJson).toList(growable: false),
        'tasks': tasks.map(_taskToJson).toList(growable: false),
        'focusSessions': sessions.map(_sessionToJson).toList(growable: false),
        'focusIntervals': intervals
            .map(_intervalToJson)
            .toList(growable: false),
        'taskRecurrenceRules': rules
            .map(_recurrenceRuleToJson)
            .toList(growable: false),
        'taskOccurrences': occurrences
            .map(_occurrenceToJson)
            .toList(growable: false),
        'reminders': reminders.map(_reminderToJson).toList(growable: false),
      };
    });
    final preferences = await _settingsStore.exportData();
    final payload = _canonicalPayload(data: data, preferences: preferences);
    final payloadBytes = utf8.encode(payload);
    final document = {
      'format': format,
      'version': currentVersion,
      'appVersion': appVersion,
      'createdAtUtc': _clock().toUtc().toIso8601String(),
      'databaseSchemaVersion': _schemaVersion,
      'exportState': 'complete',
      'payloadEncoding': payloadEncoding,
      'payloadHashAlgorithm': integrityAlgorithm,
      'payloadLengthBytes': payloadBytes.length,
      'payloadSha256': sha256.convert(payloadBytes).toString(),
      'data': data,
      'preferences': preferences,
    };
    final encoded = const JsonEncoder.withIndent('  ').convert(document);
    // Validate generated output through the same path used by imports.
    await validate(encoded);
    return encoded;
  }

  /// Validates the complete document without touching the current database.
  Future<BackupValidationResult> validate(String encoded) async {
    final document = _decode(encoded);
    _validateRows(document);
    return BackupValidationResult(_verifyIntegrity(document));
  }

  /// Returns catalogue metadata from a validated backup document.
  ///
  /// The current database is never modified.
  Future<BackupPreview> inspect(String encoded) async {
    final document = _decode(encoded);
    final rows = _validateRows(document);
    final verification = _verifyIntegrity(document);
    final rawCreatedAt = document['createdAtUtc'];
    final appVersion = document['appVersion'];
    return BackupPreview(
      verification: verification,
      createdAt: rawCreatedAt is String
          ? DateTime.tryParse(rawCreatedAt)
          : null,
      appVersion: appVersion is String && appVersion.isNotEmpty
          ? appVersion
          : null,
      schemaVersion: document['databaseSchemaVersion'] as int,
      taskCount: rows.tasks.length,
      goalCount: rows.goals.length,
      focusSessionCount: rows.sessions.length,
      focusIntervalCount: rows.intervals.length,
      reminderCount: rows.reminders.length,
    );
  }

  /// Replaces local data only after the caller has obtained explicit consent.
  /// All SQLite changes are committed as one transaction.
  Future<void> restore(
    String encoded, {
    required bool overwriteExisting,
  }) async {
    if (!overwriteExisting) {
      throw const BackupRestoreException(
        'Restore requires explicit overwrite confirmation.',
      );
    }
    final document = _decode(encoded);
    final rows = _validateRows(document);
    _verifyIntegrity(document);
    final pending = await _journalStore.load();
    if (pending != null) {
      throw const BackupRestoreException(
        'A previous restore requires recovery before another restore can start.',
      );
    }
    final journal = RestoreJournal(
      operationId: _operationIdGenerator(),
      schemaVersion: RestoreJournal.currentSchemaVersion,
      status: RestoreJournalStatus.prepared,
      createdAtMs: _clock().toUtc().millisecondsSinceEpoch,
      databaseFingerprint: _fingerprint(rows),
      incomingPreferences: rows.preferences,
      previousPreferences: await _settingsStore.exportData(),
    );
    await _journalStore.save(journal);

    var databaseCommitted = false;
    try {
      await _replaceDatabase(rows);
      databaseCommitted = true;
      await _journalStore.save(
        journal.copyWith(status: RestoreJournalStatus.databaseCommitted),
      );
      await _settingsStore.importData(rows.preferences);
      await _journalStore.save(
        journal.copyWith(status: RestoreJournalStatus.preferencesApplied),
      );
      await _journalStore.save(
        journal.copyWith(status: RestoreJournalStatus.completed),
      );
      await _journalStore.clear();
    } catch (error, stackTrace) {
      if (!databaseCommitted) {
        // The SQLite transaction rolled back. The prepared journal is safe to
        // clear; if clearing fails, startup reconciliation will compare the
        // fingerprint and remove it without applying preferences.
        try {
          await _journalStore.clear();
        } catch (_) {
          // Preserve the journal for deterministic startup reconciliation.
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Reconciles a restore interrupted between SQLite and SharedPreferences.
  /// This method is idempotent and must run before normal app interaction.
  Future<void> reconcilePendingRestore() async {
    final journal = await _journalStore.load();
    if (journal == null) return;
    switch (journal.status) {
      case RestoreJournalStatus.prepared:
        final fingerprint = await _currentDatabaseFingerprint();
        if (fingerprint != journal.databaseFingerprint) {
          await _journalStore.clear();
          return;
        }
        await _journalStore.save(
          journal.copyWith(status: RestoreJournalStatus.databaseCommitted),
        );
        await _finishPendingRestore(journal);
      case RestoreJournalStatus.databaseCommitted:
        await _finishPendingRestore(journal);
      case RestoreJournalStatus.preferencesApplied:
        await _journalStore.save(
          journal.copyWith(status: RestoreJournalStatus.completed),
        );
        await _journalStore.clear();
      case RestoreJournalStatus.completed:
        await _journalStore.clear();
    }
  }

  Future<void> _finishPendingRestore(RestoreJournal journal) async {
    await _settingsStore.importData(journal.incomingPreferences);
    await _journalStore.save(
      journal.copyWith(status: RestoreJournalStatus.preferencesApplied),
    );
    await _journalStore.save(
      journal.copyWith(status: RestoreJournalStatus.completed),
    );
    await _journalStore.clear();
  }

  Future<void> _replaceDatabase(_BackupRows rows) {
    return _database.transaction(() async {
      await _database.delete(_database.reminders).go();
      await _database.delete(_database.focusSessionIntervals).go();
      await _database.delete(_database.focusSessions).go();
      await _database.delete(_database.taskOccurrences).go();
      await _database.delete(_database.taskRecurrenceRules).go();
      await _database.delete(_database.tasks).go();
      await _database.delete(_database.goals).go();

      for (final goal in rows.goals) {
        await _database.into(_database.goals).insert(goal.toCompanion(true));
      }
      for (final task in rows.tasks) {
        await _database.into(_database.tasks).insert(task.toCompanion(true));
      }
      for (final session in rows.sessions) {
        await _database
            .into(_database.focusSessions)
            .insert(FocusSessionRepositorySupport.sessionCompanion(session));
      }
      for (final interval in rows.intervals) {
        await _database
            .into(_database.focusSessionIntervals)
            .insert(
              FocusSessionRepositorySupport.intervalCompanion(
                interval.id,
                interval.value,
              ),
            );
      }
      for (final rule in rows.rules) {
        await _database
            .into(_database.taskRecurrenceRules)
            .insert(rule.toCompanion());
      }
      for (final occurrence in rows.occurrences) {
        await _database
            .into(_database.taskOccurrences)
            .insert(occurrence.toCompanion());
      }
      for (final reminder in rows.reminders) {
        await _database
            .into(_database.reminders)
            .insert(reminder.toCompanion());
      }
    });
  }

  Future<String> _currentDatabaseFingerprint() async {
    final data = await _database.transaction(() async {
      final goals = await _database.select(_database.goals).get();
      final tasks = await _database.select(_database.tasks).get();
      final sessions = await _database.select(_database.focusSessions).get();
      final intervals = await _database
          .select(_database.focusSessionIntervals)
          .get();
      final rules = await _database.select(_database.taskRecurrenceRules).get();
      final occurrences = await _database
          .select(_database.taskOccurrences)
          .get();
      final reminders = await _database.select(_database.reminders).get();
      return {
        'goals': goals.map(_goalToJson).toList(),
        'tasks': tasks.map(_taskToJson).toList(),
        'focusSessions': sessions.map(_sessionToJson).toList(),
        'focusIntervals': intervals.map(_intervalToJson).toList(),
        'taskRecurrenceRules': rules.map(_recurrenceRuleToJson).toList(),
        'taskOccurrences': occurrences.map(_occurrenceToJson).toList(),
        'reminders': reminders.map(_reminderToJson).toList(),
      };
    });
    return _fingerprintData(data);
  }

  static String _fingerprint(_BackupRows rows) => _fingerprintData({
    'goals': rows.goals.map(_goalToJson).toList(),
    'tasks': rows.tasks.map(_taskToJson).toList(),
    'focusSessions': rows.sessions.map(_sessionToJsonFromDomain).toList(),
    'focusIntervals': rows.intervals
        .map((row) => _intervalToJsonFromDomain(row.id, row.value))
        .toList(),
    'taskRecurrenceRules': rows.rules
        .map(_recurrenceRuleToJsonFromDomain)
        .toList(),
    'taskOccurrences': rows.occurrences
        .map(_occurrenceToJsonFromDomain)
        .toList(),
    'reminders': rows.reminders.map(_reminderToJsonFromDomain).toList(),
  });

  static String _fingerprintData(Map<String, dynamic> data) {
    final canonical = <String, dynamic>{};
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is List) {
        final sorted = [...value]
          ..sort((first, second) {
            final firstId = first is Map ? first['id']?.toString() ?? '' : '';
            final secondId = second is Map
                ? second['id']?.toString() ?? ''
                : '';
            return firstId.compareTo(secondId);
          });
        canonical[entry.key] = sorted;
      } else {
        canonical[entry.key] = value;
      }
    }
    final encoded = jsonEncode(canonical);
    var hash = 0xcbf29ce484222325;
    for (final byte in utf8.encode(encoded)) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0xffffffffffffffff;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  static String _defaultOperationId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_randomSuffix()}';

  static String _randomSuffix() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36);

  static const _schemaVersion = 8;

  /// Schema versions recorded by older backup releases that remain readable.
  ///
  /// Version 4 predates recurrence and due-time columns in the envelope but is
  /// still accepted for legacy/unverified backups. Version 7 predates reminder
  /// persistence and restores with an empty reminder list.
  static const _legacySchemaVersions = {4, 7};

  static Map<String, Object?> _goalToJson(GoalRow goal) => {
    'id': goal.id,
    'title': goal.title,
    'description': goal.description,
    'targetDateEpochDay': goal.targetDate?.epochDay,
    'createdAtMs': goal.createdAt.toUtc().millisecondsSinceEpoch,
    'updatedAtMs': goal.updatedAt.toUtc().millisecondsSinceEpoch,
  };

  static Map<String, Object?> _taskToJson(TaskRow task) => {
    'id': task.id,
    'title': task.title,
    'description': task.description,
    'completed': task.completed,
    'createdAtMs': task.createdAt.toUtc().millisecondsSinceEpoch,
    'updatedAtMs': task.updatedAt.toUtc().millisecondsSinceEpoch,
    'dueDateMs': task.dueDate?.toUtc().millisecondsSinceEpoch,
    'dueTimeSeconds': task.dueTime,
    'dueTimezone': task.dueTimezone,
    'priority': task.priority,
    'category': task.category,
    'goalId': task.goalId,
    'parentTaskId': task.parentTaskId,
  };

  static Map<String, Object?> _sessionToJson(FocusSessionRow session) => {
    'id': session.id,
    'taskId': session.taskId,
    'taskIdAtStart': session.taskIdAtStart,
    'taskTitleAtStart': session.taskTitleAtStart,
    'mode': session.mode.name,
    'status': session.status.name,
    'startedAtMs': session.startedAtMs,
    'endedAtMs': session.endedAtMs,
    'plannedDurationMs': session.plannedDurationMs,
    'actualDurationMs': session.actualDurationMs,
    'cycleId': session.cycleId,
    'cycleRound': session.cycleRound,
    'updatedAtMs': session.updatedAtMs,
  };

  static Map<String, Object?> _sessionToJsonFromDomain(FocusSession session) =>
      {
        'id': session.id,
        'taskId': session.taskId,
        'taskIdAtStart': session.taskIdSnapshot,
        'taskTitleAtStart': session.taskTitleSnapshot,
        'mode': session.mode.name,
        'status': session.status.name,
        'startedAtMs': session.startedAtMs,
        'endedAtMs': session.endedAtMs,
        'plannedDurationMs': session.plannedDurationMs,
        'actualDurationMs': session.actualDurationMs,
        'cycleId': session.cycleId,
        'cycleRound': session.cycleRound,
        'updatedAtMs': session.updatedAtMs,
      };

  static Map<String, Object?> _intervalToJson(
    FocusSessionIntervalRow interval,
  ) => {
    'id': interval.id,
    'sessionId': interval.sessionId,
    'startedAtMs': interval.startedAtMs,
    'endedAtMs': interval.endedAtMs,
  };

  static Map<String, Object?> _intervalToJsonFromDomain(
    String id,
    FocusSessionInterval interval,
  ) => {
    'id': id,
    'sessionId': interval.sessionId,
    'startedAtMs': interval.startedAtMs,
    'endedAtMs': interval.endedAtMs,
  };

  static Map<String, Object?> _recurrenceRuleToJson(
    TaskRecurrenceRuleRow rule,
  ) => {
    'id': rule.id,
    'parentTaskId': rule.parentTaskId,
    'recurrenceType': rule.recurrenceType,
    'interval': rule.interval,
    'weekdays': rule.weekdays,
    'startDateMs': rule.startDate,
    'endDateMs': rule.endDate,
    'maxOccurrences': rule.maxOccurrences,
    'isActive': rule.isActive,
    'createdAtMs': rule.createdAt,
    'updatedAtMs': rule.updatedAt,
  };

  static Map<String, Object?> _occurrenceToJson(TaskOccurrenceRow occurrence) =>
      {
        'id': occurrence.id,
        'ruleId': occurrence.ruleId,
        'occurrenceDateMs': occurrence.occurrenceDate,
        'dueDateMs': occurrence.dueDate,
        'dueTimeSeconds': occurrence.dueTime,
        'dueTimezone': occurrence.dueTimezone,
        'completed': occurrence.completed,
        'isDeleted': occurrence.isDeleted,
        'createdAtMs': occurrence.createdAt,
        'updatedAtMs': occurrence.updatedAt,
      };

  static Map<String, Object?> _reminderToJson(ReminderRow reminder) => {
    'id': reminder.id,
    'taskId': reminder.taskId,
    'scheduleType': reminder.scheduleType,
    'timezoneId': reminder.timezoneId,
    'scheduledAtUtcMs': reminder.scheduledAtUtcMs,
    'localTimeSeconds': reminder.localTimeSeconds,
    'interval': reminder.interval,
    'weekdays': reminder.weekdays,
    'startDateMs': reminder.startDate,
    'endDateMs': reminder.endDate,
    'maxOccurrences': reminder.maxOccurrences,
    'status': reminder.status,
    'cancellationReason': reminder.cancellationReason,
    'cancelledAtMs': reminder.cancelledAtMs,
    'createdAtMs': reminder.createdAtMs,
    'updatedAtMs': reminder.updatedAtMs,
  };

  static Map<String, Object?> _reminderToJsonFromDomain(Reminder reminder) => {
    'id': reminder.id,
    'taskId': reminder.taskId,
    'scheduleType': reminder.scheduleType.name,
    'timezoneId': reminder.timezoneId,
    'scheduledAtUtcMs': reminder.scheduledAtUtc?.toUtc().millisecondsSinceEpoch,
    'localTimeSeconds': reminder.localTimeSeconds,
    'interval': reminder.interval,
    'weekdays': reminder.weekdays,
    'startDateMs': reminder.startDate == null
        ? null
        : recurrenceDateToEpochMs(reminder.startDate!),
    'endDateMs': reminder.endDate == null
        ? null
        : recurrenceDateToEpochMs(reminder.endDate!),
    'maxOccurrences': reminder.maxOccurrences,
    'status': reminder.status.name,
    'cancellationReason': reminder.cancellationReason?.name,
    'cancelledAtMs': reminder.cancelledAtUtc?.toUtc().millisecondsSinceEpoch,
    'createdAtMs': reminder.createdAt.toUtc().millisecondsSinceEpoch,
    'updatedAtMs': reminder.updatedAt.toUtc().millisecondsSinceEpoch,
  };

  static Map<String, Object?> _recurrenceRuleToJsonFromDomain(
    TaskRecurrenceRule rule,
  ) => {
    'id': rule.id,
    'parentTaskId': rule.parentTaskId,
    'recurrenceType': rule.recurrenceType.name,
    'interval': rule.interval,
    'weekdays': rule.weekdays,
    'startDateMs': recurrenceDateToEpochMs(rule.startDate),
    'endDateMs': rule.endDate == null
        ? null
        : recurrenceDateToEpochMs(rule.endDate!),
    'maxOccurrences': rule.maxOccurrences,
    'isActive': rule.isActive,
    'createdAtMs': rule.createdAt.toUtc().millisecondsSinceEpoch,
    'updatedAtMs': rule.updatedAt.toUtc().millisecondsSinceEpoch,
  };

  static Map<String, Object?> _occurrenceToJsonFromDomain(
    TaskOccurrence occurrence,
  ) => {
    'id': occurrence.id,
    'ruleId': occurrence.ruleId,
    'occurrenceDateMs': recurrenceDateToEpochMs(occurrence.occurrenceDate),
    'dueDateMs': occurrence.dueDate == null
        ? null
        : recurrenceDateToEpochMs(occurrence.dueDate!),
    'dueTimeSeconds': occurrence.dueTime,
    'dueTimezone': occurrence.dueTimezone,
    'completed': occurrence.completed,
    'isDeleted': occurrence.isDeleted,
    'createdAtMs': occurrence.createdAt.toUtc().millisecondsSinceEpoch,
    'updatedAtMs': occurrence.updatedAt.toUtc().millisecondsSinceEpoch,
  };

  static Map<String, dynamic> _decode(String encoded) {
    if (!isDocumentWithinLimit(encoded.length)) {
      throw const BackupValidationException(
        'Backup file is too large to import safely.',
      );
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) {
        throw const BackupValidationException('Backup root must be an object.');
      }
      if (decoded['format'] != format) {
        throw const BackupValidationException('Unsupported backup format.');
      }
      if (decoded['version'] != currentVersion) {
        throw const BackupValidationException('Unsupported backup version.');
      }
      if (decoded['databaseSchemaVersion'] != _schemaVersion &&
          !_legacySchemaVersions.contains(decoded['databaseSchemaVersion'])) {
        throw const BackupValidationException(
          'Backup database schema is not supported by this version.',
        );
      }
      if (decoded['data'] is! Map<String, dynamic> ||
          decoded['preferences'] is! Map<String, dynamic>) {
        throw const BackupValidationException('Backup data is incomplete.');
      }
      _validateIntegrityEnvelope(decoded);
      return decoded;
    } on BackupValidationException {
      rethrow;
    } on FormatException catch (error) {
      throw BackupValidationException('Backup is not valid JSON: $error');
    } catch (error) {
      throw BackupValidationException('Backup could not be read: $error');
    }
  }

  static BackupVerificationStatus _verifyIntegrity(
    Map<String, dynamic> document,
  ) {
    final hasIntegrity = document.containsKey('payloadSha256');
    if (!hasIntegrity) return BackupVerificationStatus.legacyUnverified;
    final payload = _canonicalPayload(
      data: document['data'] as Map<String, dynamic>,
      preferences: document['preferences'] as Map<String, dynamic>,
    );
    final bytes = utf8.encode(payload);
    final checksum = sha256.convert(bytes).toString();
    if (bytes.length != document['payloadLengthBytes'] ||
        checksum != document['payloadSha256']) {
      throw const BackupValidationException(
        'Backup integrity verification failed.',
      );
    }
    return BackupVerificationStatus.verified;
  }

  static void _validateIntegrityEnvelope(Map<String, dynamic> document) {
    const fields = [
      'appVersion',
      'exportState',
      'payloadEncoding',
      'payloadHashAlgorithm',
      'payloadLengthBytes',
      'payloadSha256',
    ];
    final present = fields.where(document.containsKey).length;
    if (present == 0) return; // Existing v1 backup: legacy/unverified.
    if (present != fields.length) {
      throw const BackupValidationException(
        'Backup integrity metadata is incomplete.',
      );
    }
    if (document['appVersion'] is! String ||
        (document['appVersion'] as String).isEmpty ||
        document['exportState'] != 'complete' ||
        document['payloadEncoding'] != payloadEncoding ||
        document['payloadHashAlgorithm'] != integrityAlgorithm ||
        document['payloadLengthBytes'] is! int ||
        (document['payloadLengthBytes'] as int) < 0 ||
        document['payloadSha256'] is! String ||
        !RegExp(
          r'^[0-9a-f]{64}$',
        ).hasMatch(document['payloadSha256'] as String)) {
      throw const BackupValidationException(
        'Backup integrity metadata is invalid.',
      );
    }
  }

  /// Canonical payload bytes are UTF-8 JSON of exactly {data, preferences}.
  /// Map keys are recursively sorted lexicographically; list order is retained
  /// because list ordering is part of the persisted payload semantics. Dart's
  /// JSON number representation, null handling, and escaping are delegated to
  /// dart:convert's JSON encoder.
  static String _canonicalPayload({
    required Map<String, dynamic> data,
    required Map<String, dynamic> preferences,
  }) => jsonEncode(_canonicalize({'data': data, 'preferences': preferences}));

  static dynamic _canonicalize(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return <String, dynamic>{
        for (final key in keys) key: _canonicalize(value[key]),
      };
    }
    if (value is List) {
      return value.map(_canonicalize).toList(growable: false);
    }
    return value;
  }

  static _BackupRows _validateRows(Map<String, dynamic> document) {
    final data = document['data'] as Map<String, dynamic>;
    final preferences = document['preferences'] as Map<String, dynamic>;
    final goals = _list(data, 'goals').map(_goalFromJson).toList();
    final tasks = _list(data, 'tasks').map(_taskFromJson).toList();
    final sessions = _list(
      data,
      'focusSessions',
    ).map(_sessionFromJson).toList();
    final intervals = _list(
      data,
      'focusIntervals',
    ).map(_intervalFromJson).toList();
    // Older backups predate recurrence. Missing lists are treated as empty.
    final rules = _optionalList(
      data,
      'taskRecurrenceRules',
    ).map(_recurrenceRuleFromJson).toList();
    final occurrences = _optionalList(
      data,
      'taskOccurrences',
    ).map(_occurrenceFromJson).toList();
    // Older backups predate reminder persistence. Missing lists are empty.
    final reminders = _optionalList(
      data,
      'reminders',
    ).map(_reminderFromJson).toList();
    _requireUnique(goals.map((row) => row.id), 'goal');
    _requireUnique(tasks.map((row) => row.id), 'task');
    _requireUnique(sessions.map((row) => row.id), 'focus session');
    _requireUnique(intervals.map((row) => row.id), 'focus interval');
    _requireUnique(rules.map((row) => row.id), 'recurrence rule');
    _requireUnique(occurrences.map((row) => row.id), 'occurrence');
    _requireUnique(reminders.map((row) => row.id), 'reminder');
    final goalIds = goals.map((row) => row.id).toSet();
    final taskIds = tasks.map((row) => row.id).toSet();
    final sessionIds = sessions.map((row) => row.id).toSet();
    final ruleIds = rules.map((row) => row.id).toSet();
    if (tasks.any(
      (row) =>
          (row.goalId != null && !goalIds.contains(row.goalId)) ||
          (row.parentTaskId != null && !taskIds.contains(row.parentTaskId)),
    )) {
      throw const BackupValidationException(
        'A task references a missing goal or parent task.',
      );
    }
    _validateParentGraph(tasks);
    if (sessions.any(
      (row) => row.taskId != null && !taskIds.contains(row.taskId),
    )) {
      throw const BackupValidationException(
        'A focus session references a missing task.',
      );
    }
    if (intervals.any((row) => !sessionIds.contains(row.value.sessionId))) {
      throw const BackupValidationException(
        'A focus interval references a missing session.',
      );
    }
    final parentRuleIds = <String>{};
    for (final rule in rules) {
      final parentTaskId = rule.parentTaskId;
      if (parentTaskId == null || !taskIds.contains(parentTaskId)) {
        throw const BackupValidationException(
          'A recurrence rule references a missing parent task.',
        );
      }
      if (!parentRuleIds.add(parentTaskId)) {
        throw const BackupValidationException(
          'A task has more than one recurrence rule.',
        );
      }
      final errors = rule.validate();
      if (errors.isNotEmpty) {
        throw BackupValidationException(
          'Recurrence rule ${rule.id} is invalid: ${errors.join(' ')}',
        );
      }
    }
    final occurrenceKeys = <String>{};
    for (final occurrence in occurrences) {
      final ruleId = occurrence.ruleId;
      if (ruleId == null || !ruleIds.contains(ruleId)) {
        throw const BackupValidationException(
          'An occurrence references a missing recurrence rule.',
        );
      }
      final key = '$ruleId:${recurrenceDateKey(occurrence.occurrenceDate)}';
      if (!occurrenceKeys.add(key)) {
        throw const BackupValidationException(
          'A recurrence rule contains duplicate occurrence dates.',
        );
      }
    }
    if (reminders.any((reminder) => !taskIds.contains(reminder.taskId))) {
      throw const BackupValidationException(
        'A reminder references a missing task.',
      );
    }
    final intervalsBySession = <String, List<FocusSessionInterval>>{};
    for (final row in intervals) {
      intervalsBySession
          .putIfAbsent(row.value.sessionId, () => [])
          .add(row.value);
    }
    for (final session in sessions) {
      try {
        FocusSessionTransition(
          session: session,
          intervals: intervalsBySession[session.id] ?? const [],
        );
      } on ArgumentError catch (error) {
        throw BackupValidationException(
          'Focus session ${session.id} is invalid: ${error.message}',
        );
      }
    }
    _validatePreferences(preferences);
    return _BackupRows(
      goals,
      tasks,
      sessions,
      intervals,
      rules,
      occurrences,
      reminders,
      preferences,
    );
  }

  static List<dynamic> _list(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! List<dynamic>) {
      throw BackupValidationException('Backup field "$key" is invalid.');
    }
    return value;
  }

  static List<dynamic> _optionalList(Map<String, dynamic> data, String key) {
    if (!data.containsKey(key)) return const [];
    return _list(data, key);
  }

  static void _requireUnique(Iterable<String> ids, String label) {
    final values = ids.toList();
    if (values.toSet().length != values.length) {
      throw BackupValidationException('Backup contains duplicate $label IDs.');
    }
  }

  static GoalRow _goalFromJson(dynamic value) {
    final row = _map(value, 'goal');
    return GoalRow(
      id: _string(row, 'id'),
      title: _string(row, 'title'),
      description: _nullableString(row, 'description'),
      targetDate: _nullableInt(row, 'targetDateEpochDay') == null
          ? null
          : GoalDate(_nullableInt(row, 'targetDateEpochDay')!),
      createdAt: _date(row, 'createdAtMs'),
      updatedAt: _date(row, 'updatedAtMs'),
    );
  }

  static TaskRow _taskFromJson(dynamic value) {
    final row = _map(value, 'task');
    return TaskRow(
      id: _string(row, 'id'),
      title: _string(row, 'title'),
      description: _nullableString(row, 'description'),
      completed: _bool(row, 'completed'),
      createdAt: _date(row, 'createdAtMs'),
      updatedAt: _date(row, 'updatedAtMs'),
      dueDate: _nullableDate(row, 'dueDateMs'),
      dueTime: _nullableInt(row, 'dueTimeSeconds'),
      dueTimezone: _nullableString(row, 'dueTimezone'),
      priority: _int(row, 'priority'),
      category: _nullableString(row, 'category'),
      goalId: _nullableString(row, 'goalId'),
      parentTaskId: _nullableString(row, 'parentTaskId'),
    );
  }

  static FocusSession _sessionFromJson(dynamic value) {
    final row = _map(value, 'focus session');
    return FocusSession(
      id: _string(row, 'id'),
      taskId: _nullableString(row, 'taskId'),
      taskIdSnapshot: _nullableString(row, 'taskIdAtStart'),
      taskTitleSnapshot: _nullableString(row, 'taskTitleAtStart'),
      mode: _enumValue(FocusSessionMode.values, _string(row, 'mode'), 'mode'),
      status: _enumValue(
        FocusSessionStatus.values,
        _string(row, 'status'),
        'status',
      ),
      startedAtMs: _int(row, 'startedAtMs'),
      endedAtMs: _nullableInt(row, 'endedAtMs'),
      plannedDurationMs: _nullableInt(row, 'plannedDurationMs'),
      actualDurationMs: _nullableInt(row, 'actualDurationMs'),
      cycleId: _nullableString(row, 'cycleId'),
      cycleRound: _nullableInt(row, 'cycleRound'),
      updatedAtMs: _int(row, 'updatedAtMs'),
    );
  }

  static _BackupInterval _intervalFromJson(dynamic value) {
    final row = _map(value, 'focus interval');
    final interval = FocusSessionInterval(
      sessionId: _string(row, 'sessionId'),
      startedAtMs: _int(row, 'startedAtMs'),
      endedAtMs: _nullableInt(row, 'endedAtMs'),
    );
    return _BackupInterval(_string(row, 'id'), interval);
  }

  static TaskRecurrenceRule _recurrenceRuleFromJson(dynamic value) {
    final row = _map(value, 'recurrence rule');
    final recurrenceType = _enumValue(
      RecurrenceType.values,
      _string(row, 'recurrenceType'),
      'recurrenceType',
    );
    final rawStart = _int(row, 'startDateMs');
    final rawEnd = _nullableInt(row, 'endDateMs');
    _requireCanonicalRecurrenceDate(rawStart);
    if (rawEnd != null) _requireCanonicalRecurrenceDate(rawEnd);
    return TaskRecurrenceRule(
      id: _string(row, 'id'),
      parentTaskId: _nullableString(row, 'parentTaskId'),
      recurrenceType: recurrenceType,
      interval: _int(row, 'interval'),
      weekdays: _nullableInt(row, 'weekdays'),
      startDate: recurrenceDateFromEpochMs(rawStart),
      endDate: rawEnd == null ? null : recurrenceDateFromEpochMs(rawEnd),
      maxOccurrences: _nullableInt(row, 'maxOccurrences'),
      isActive: _bool(row, 'isActive'),
      createdAt: _date(row, 'createdAtMs'),
      updatedAt: _date(row, 'updatedAtMs'),
    );
  }

  static TaskOccurrence _occurrenceFromJson(dynamic value) {
    final row = _map(value, 'occurrence');
    final rawOccurrenceDate = _int(row, 'occurrenceDateMs');
    final rawDueDate = _nullableInt(row, 'dueDateMs');
    _requireCanonicalRecurrenceDate(rawOccurrenceDate);
    if (rawDueDate != null) _requireCanonicalRecurrenceDate(rawDueDate);
    return TaskOccurrence(
      id: _string(row, 'id'),
      ruleId: _nullableString(row, 'ruleId'),
      occurrenceDate: recurrenceDateFromEpochMs(rawOccurrenceDate),
      dueDate: rawDueDate == null
          ? null
          : recurrenceDateFromEpochMs(rawDueDate),
      dueTime: _nullableInt(row, 'dueTimeSeconds'),
      dueTimezone: _nullableString(row, 'dueTimezone'),
      completed: _bool(row, 'completed'),
      isDeleted: _bool(row, 'isDeleted'),
      createdAt: _date(row, 'createdAtMs'),
      updatedAt: _date(row, 'updatedAtMs'),
    );
  }

  static Reminder _reminderFromJson(dynamic value) {
    final row = _map(value, 'reminder');
    final rawStart = _nullableInt(row, 'startDateMs');
    final rawEnd = _nullableInt(row, 'endDateMs');
    if (rawStart != null) _requireCanonicalRecurrenceDate(rawStart);
    if (rawEnd != null) _requireCanonicalRecurrenceDate(rawEnd);
    final rawCancelledAt = _nullableInt(row, 'cancelledAtMs');
    final reminder = Reminder(
      id: _string(row, 'id'),
      taskId: _string(row, 'taskId'),
      scheduleType: _enumValue(
        ReminderScheduleType.values,
        _string(row, 'scheduleType'),
        'scheduleType',
      ),
      timezoneId: _nullableString(row, 'timezoneId'),
      scheduledAtUtc: _nullableDate(row, 'scheduledAtUtcMs'),
      localTimeSeconds: _nullableInt(row, 'localTimeSeconds'),
      interval: _int(row, 'interval'),
      weekdays: _nullableInt(row, 'weekdays'),
      startDate: rawStart == null ? null : recurrenceDateFromEpochMs(rawStart),
      endDate: rawEnd == null ? null : recurrenceDateFromEpochMs(rawEnd),
      maxOccurrences: _nullableInt(row, 'maxOccurrences'),
      status: _enumValue(
        ReminderStatus.values,
        _string(row, 'status'),
        'status',
      ),
      cancellationReason: _nullableEnumValue(
        ReminderCancellationReason.values,
        _nullableString(row, 'cancellationReason'),
        'cancellationReason',
      ),
      cancelledAtUtc: rawCancelledAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(rawCancelledAt, isUtc: true),
      createdAt: _date(row, 'createdAtMs'),
      updatedAt: _date(row, 'updatedAtMs'),
    );
    final errors = reminder.validate();
    if (errors.isNotEmpty) {
      throw BackupValidationException(
        'Reminder ${reminder.id} is invalid: ${errors.join(' ')}',
      );
    }
    return reminder;
  }

  static void _requireCanonicalRecurrenceDate(int milliseconds) {
    if (milliseconds % Duration.millisecondsPerDay != 0) {
      throw const BackupValidationException(
        'Recurrence dates must be stored as UTC midnight.',
      );
    }
  }

  static void _validatePreferences(Map<String, dynamic> preferences) {
    final settings = preferences['pomodoroSettings'];
    if (settings is! Map<String, dynamic>) {
      throw const BackupValidationException('Pomodoro settings are missing.');
    }
    try {
      PomodoroSettings(
        focusMinutes: settings['focusMinutes'] as int,
        shortBreakMinutes: settings['shortBreakMinutes'] as int,
        longBreakMinutes: settings['longBreakMinutes'] as int,
      );
    } on Object catch (error) {
      throw BackupValidationException('Pomodoro settings are invalid: $error');
    }
    final dismissed = preferences['dismissedCycleIds'];
    if (dismissed is! List<dynamic> ||
        dismissed.any((value) => value is! String)) {
      throw const BackupValidationException(
        'Dismissed Pomodoro cycles are invalid.',
      );
    }
  }

  static void _validateParentGraph(List<TaskRow> tasks) {
    final parents = {for (final task in tasks) task.id: task.parentTaskId};
    for (final task in tasks) {
      final visited = <String>{};
      String? current = task.id;
      while (current != null) {
        if (!visited.add(current)) {
          throw const BackupValidationException(
            'Task hierarchy contains a cycle.',
          );
        }
        current = parents[current];
      }
    }
  }

  static Map<String, dynamic> _map(dynamic value, String label) {
    if (value is! Map<String, dynamic>) {
      throw BackupValidationException('Backup $label is invalid.');
    }
    return value;
  }

  static String _string(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String || value.isEmpty) {
      throw BackupValidationException('Backup field "$key" is invalid.');
    }
    return value;
  }

  static String? _nullableString(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value != null && value is! String) {
      throw BackupValidationException('Backup field "$key" is invalid.');
    }
    return value as String?;
  }

  static int _int(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! int) {
      throw BackupValidationException('Backup field "$key" is invalid.');
    }
    return value;
  }

  static int? _nullableInt(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value != null && value is! int) {
      throw BackupValidationException('Backup field "$key" is invalid.');
    }
    return value as int?;
  }

  static bool _bool(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! bool) {
      throw BackupValidationException('Backup field "$key" is invalid.');
    }
    return value;
  }

  static DateTime _date(Map<String, dynamic> row, String key) =>
      DateTime.fromMillisecondsSinceEpoch(_int(row, key), isUtc: true);

  static DateTime? _nullableDate(Map<String, dynamic> row, String key) {
    final value = _nullableInt(row, key);
    return value == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }

  static T _enumValue<T extends Enum>(List<T> values, String name, String key) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw BackupValidationException('Backup field "$key" is invalid.');
  }

  static T? _nullableEnumValue<T extends Enum>(
    List<T> values,
    String? name,
    String key,
  ) {
    if (name == null) return null;
    return _enumValue(values, name, key);
  }
}

final class _BackupRows {
  const _BackupRows(
    this.goals,
    this.tasks,
    this.sessions,
    this.intervals,
    this.rules,
    this.occurrences,
    this.reminders,
    this.preferences,
  );

  final List<GoalRow> goals;
  final List<TaskRow> tasks;
  final List<FocusSession> sessions;
  final List<_BackupInterval> intervals;
  final List<TaskRecurrenceRule> rules;
  final List<TaskOccurrence> occurrences;
  final List<Reminder> reminders;
  final Map<String, dynamic> preferences;
}

final class _BackupInterval {
  const _BackupInterval(this.id, this.value);

  final String id;
  final FocusSessionInterval value;
}

class BackupValidationException implements Exception {
  const BackupValidationException(this.message);

  final String message;

  @override
  String toString() => 'BackupValidationException: $message';
}

class BackupRestoreException implements Exception {
  const BackupRestoreException(this.message);

  final String message;

  @override
  String toString() => 'BackupRestoreException: $message';
}
