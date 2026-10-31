import 'dart:convert';

import '../../features/focus/models/focus_session.dart';
import '../../features/focus/models/focus_session_interval.dart';
import '../../features/focus/models/focus_session_mode.dart';
import '../../features/focus/models/focus_session_status.dart';
import '../../features/focus/models/pomodoro_settings.dart';
import '../../features/focus/repository/focus_session_repository_support.dart';
import '../../features/focus/repository/pomodoro_settings_store.dart';
import '../../features/goals/models/goal_date.dart';
import '../../core/database/database.dart';
import 'restore_journal.dart';

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
      return {
        'goals': goals.map(_goalToJson).toList(growable: false),
        'tasks': tasks.map(_taskToJson).toList(growable: false),
        'focusSessions': sessions.map(_sessionToJson).toList(growable: false),
        'focusIntervals': intervals
            .map(_intervalToJson)
            .toList(growable: false),
      };
    });
    final preferences = await _settingsStore.exportData();
    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': currentVersion,
      'createdAtUtc': _clock().toUtc().toIso8601String(),
      'databaseSchemaVersion': _schemaVersion,
      'data': data,
      'preferences': preferences,
    });
  }

  /// Validates the complete document without touching the current database.
  Future<void> validate(String encoded) async {
    final document = _decode(encoded);
    _validateRows(document);
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
      await _database.delete(_database.focusSessionIntervals).go();
      await _database.delete(_database.focusSessions).go();
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
      return {
        'goals': goals.map(_goalToJson).toList(),
        'tasks': tasks.map(_taskToJson).toList(),
        'focusSessions': sessions.map(_sessionToJson).toList(),
        'focusIntervals': intervals.map(_intervalToJson).toList(),
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

  static const _schemaVersion = 4;

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

  static Map<String, dynamic> _decode(String encoded) {
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
      if (decoded['databaseSchemaVersion'] != _schemaVersion) {
        throw const BackupValidationException(
          'Backup database schema is not supported by this version.',
        );
      }
      if (decoded['data'] is! Map<String, dynamic> ||
          decoded['preferences'] is! Map<String, dynamic>) {
        throw const BackupValidationException('Backup data is incomplete.');
      }
      return decoded;
    } on BackupValidationException {
      rethrow;
    } on FormatException catch (error) {
      throw BackupValidationException('Backup is not valid JSON: $error');
    } catch (error) {
      throw BackupValidationException('Backup could not be read: $error');
    }
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
    _requireUnique(goals.map((row) => row.id), 'goal');
    _requireUnique(tasks.map((row) => row.id), 'task');
    _requireUnique(sessions.map((row) => row.id), 'focus session');
    _requireUnique(intervals.map((row) => row.id), 'focus interval');
    final goalIds = goals.map((row) => row.id).toSet();
    final taskIds = tasks.map((row) => row.id).toSet();
    final sessionIds = sessions.map((row) => row.id).toSet();
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
    return _BackupRows(goals, tasks, sessions, intervals, preferences);
  }

  static List<dynamic> _list(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! List<dynamic>) {
      throw BackupValidationException('Backup field "$key" is invalid.');
    }
    return value;
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
}

final class _BackupRows {
  const _BackupRows(
    this.goals,
    this.tasks,
    this.sessions,
    this.intervals,
    this.preferences,
  );

  final List<GoalRow> goals;
  final List<TaskRow> tasks;
  final List<FocusSession> sessions;
  final List<_BackupInterval> intervals;
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
