import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../../features/focus/models/focus_session_mode.dart';
import '../../features/focus/models/focus_session_status.dart';
import '../../features/goals/models/goal_date.dart';
import '../database/database.dart';
import 'backup_service.dart';

enum SelectiveDataset {
  tasks('tasks', 'Tasks'),
  goals('goals', 'Goals'),
  focusHistory('focusHistory', 'Focus history');

  const SelectiveDataset(this.key, this.label);

  final String key;
  final String label;
}

final class SelectiveImportPreview {
  const SelectiveImportPreview({
    required this.datasets,
    required this.taskCount,
    required this.goalCount,
    required this.focusSessionCount,
    required this.focusIntervalCount,
    required this.existingTaskCount,
    required this.existingGoalCount,
    required this.existingFocusSessionCount,
    required this.warnings,
    required this.blockers,
    this.createdAt,
    this.appVersion,
  });

  final Set<SelectiveDataset> datasets;
  final int taskCount;
  final int goalCount;
  final int focusSessionCount;
  final int focusIntervalCount;
  final int existingTaskCount;
  final int existingGoalCount;
  final int existingFocusSessionCount;
  final List<String> warnings;
  final List<String> blockers;
  final DateTime? createdAt;
  final String? appVersion;

  bool get canImport => blockers.isEmpty;
}

final class SelectiveImportResult {
  const SelectiveImportResult({
    required this.tasksImported,
    required this.tasksSkipped,
    required this.goalsImported,
    required this.goalsSkipped,
    required this.focusSessionsImported,
    required this.focusSessionsSkipped,
    required this.warnings,
  });

  final int tasksImported;
  final int tasksSkipped;
  final int goalsImported;
  final int goalsSkipped;
  final int focusSessionsImported;
  final int focusSessionsSkipped;
  final List<String> warnings;
}

/// Type-selective JSON/CSV portability. Full database restore remains a
/// separate, explicit workflow in [BackupService].
///
/// Task selections export task templates only. Recurrence rules, their
/// generated occurrences, and task reminders are intentionally outside the
/// selective task dataset; importing a selective task selection therefore
/// restores standalone task templates without recurring behavior or reminder
/// scheduling intent. Use the full backup/restore workflow when recurrence
/// history or reminders must round trip.
final class SelectivePortabilityService {
  SelectivePortabilityService(
    this._database,
    this._backupService, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const format = 'systum-selective-export';
  static const currentVersion = 1;

  final SystumDatabase _database;
  final BackupService _backupService;
  final DateTime Function() _clock;

  Future<String> exportJson(Set<SelectiveDataset> selection) async {
    if (selection.isEmpty) {
      throw const SelectiveImportException('Select at least one data type.');
    }
    final full = jsonDecode(await _backupService.createBackup());
    if (full is! Map<String, dynamic> ||
        full['data'] is! Map<String, dynamic> ||
        full['databaseSchemaVersion'] is! int) {
      throw const SelectiveImportException(
        'The generated backup document is invalid.',
      );
    }
    final fullData = full['data'] as Map<String, dynamic>;
    final data = <String, dynamic>{
      'goals': <dynamic>[],
      'tasks': <dynamic>[],
      'focusSessions': <dynamic>[],
      'focusIntervals': <dynamic>[],
    };

    final includeGoals = selection.contains(SelectiveDataset.goals);
    final includeTasks = selection.contains(SelectiveDataset.tasks);
    final includeFocus = selection.contains(SelectiveDataset.focusHistory);

    if (includeGoals) {
      data['goals'] = List<dynamic>.from(fullData['goals'] as List);
    }
    if (includeTasks) {
      data['tasks'] = [
        for (final row in fullData['tasks'] as List)
          _normalizedTask(row as Map<String, dynamic>, includeGoals),
      ];
    }
    if (includeFocus) {
      data['focusSessions'] = [
        for (final row in fullData['focusSessions'] as List)
          _normalizedSession(row as Map<String, dynamic>, includeTasks),
      ];
      data['focusIntervals'] = List<dynamic>.from(
        fullData['focusIntervals'] as List,
      );
      if (!includeTasks) {
        // Interval rows have no task reference; session snapshots remain.
      }
    }

    final payload = jsonEncode(data);
    final payloadBytes = utf8.encode(payload);
    final document = {
      'format': format,
      'version': currentVersion,
      'appVersion': BackupService.appVersion,
      'createdAtUtc': _clock().toUtc().toIso8601String(),
      'databaseSchemaVersion': _database.schemaVersion,
      'datasets': [for (final dataset in selection) dataset.key]..sort(),
      'payloadLengthBytes': payloadBytes.length,
      'payloadSha256': sha256.convert(payloadBytes).toString(),
      'data': data,
    };
    return const JsonEncoder.withIndent('  ').convert(document);
  }

  Map<String, dynamic> _normalizedTask(
    Map<String, dynamic> row,
    bool includeGoals,
  ) {
    final copy = Map<String, dynamic>.from(row);
    if (!includeGoals) copy['goalId'] = null;
    return copy;
  }

  Map<String, dynamic> _normalizedSession(
    Map<String, dynamic> row,
    bool includeTasks,
  ) {
    final copy = Map<String, dynamic>.from(row);
    if (!includeTasks) copy['taskId'] = null;
    return copy;
  }

  Future<String> exportCsv(SelectiveDataset dataset) async {
    return switch (dataset) {
      SelectiveDataset.tasks => _tasksCsv(),
      SelectiveDataset.goals => _goalsCsv(),
      SelectiveDataset.focusHistory => _focusCsv(),
    };
  }

  Future<String> _tasksCsv() async {
    final rows =
        await (_database.select(_database.tasks)..orderBy([
              (task) => OrderingTerm.asc(task.createdAt),
              (task) => OrderingTerm.asc(task.id),
            ]))
            .get();
    return _csv([
      [
        'id',
        'title',
        'description',
        'completed',
        'priority',
        'category',
        'due_date_utc',
        'goal_id',
        'parent_task_id',
        'created_at_utc',
        'updated_at_utc',
      ],
      for (final row in rows)
        [
          row.id,
          row.title,
          row.description ?? '',
          row.completed.toString(),
          row.priority.toString(),
          row.category ?? '',
          row.dueDate?.toUtc().toIso8601String() ?? '',
          row.goalId ?? '',
          row.parentTaskId ?? '',
          row.createdAt.toUtc().toIso8601String(),
          row.updatedAt.toUtc().toIso8601String(),
        ],
    ]);
  }

  Future<String> _goalsCsv() async {
    final rows =
        await (_database.select(_database.goals)..orderBy([
              (goal) => OrderingTerm.asc(goal.createdAt),
              (goal) => OrderingTerm.asc(goal.id),
            ]))
            .get();
    return _csv([
      [
        'id',
        'title',
        'description',
        'target_date',
        'created_at_utc',
        'updated_at_utc',
      ],
      for (final row in rows)
        [
          row.id,
          row.title,
          row.description ?? '',
          row.targetDate?.toIso8601String() ?? '',
          row.createdAt.toUtc().toIso8601String(),
          row.updatedAt.toUtc().toIso8601String(),
        ],
    ]);
  }

  Future<String> _focusCsv() async {
    final rows =
        await (_database.select(_database.focusSessions)..orderBy([
              (session) => OrderingTerm.desc(session.startedAtMs),
              (session) => OrderingTerm.desc(session.id),
            ]))
            .get();
    return _csv([
      [
        'id',
        'task_id',
        'task_id_at_start',
        'task_title_at_start',
        'mode',
        'status',
        'started_at_ms',
        'ended_at_ms',
        'planned_duration_ms',
        'actual_duration_ms',
        'cycle_id',
        'cycle_round',
      ],
      for (final row in rows)
        [
          row.id,
          row.taskId ?? '',
          row.taskIdAtStart ?? '',
          row.taskTitleAtStart ?? '',
          row.mode.name,
          row.status.name,
          row.startedAtMs.toString(),
          row.endedAtMs?.toString() ?? '',
          row.plannedDurationMs?.toString() ?? '',
          row.actualDurationMs?.toString() ?? '',
          row.cycleId ?? '',
          row.cycleRound?.toString() ?? '',
        ],
    ]);
  }

  String _csv(List<List<String>> rows) {
    return rows.map((row) => row.map(_csvField).join(',')).join('\r\n');
  }

  String _csvField(String value) {
    if (!value.contains(RegExp(r'[",\r\n]'))) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  Future<SelectiveImportPreview> preview(String encoded) async {
    final document = _decode(encoded);
    final rows = _decodeRows(document);
    final warnings = <String>[];
    final blockers = <String>[];

    _checkDuplicateIds(rows, blockers);
    final taskIds = rows.tasks.map((row) => row['id'] as String).toSet();
    final goalIds = rows.goals.map((row) => row['id'] as String).toSet();
    final sessionIds = rows.sessions.map((row) => row['id'] as String).toSet();
    final intervalIds = rows.intervals
        .map((row) => row['id'] as String)
        .toSet();

    final existingTaskIds = await _existingIds(_database.tasks);
    final existingGoalIds = await _existingIds(_database.goals);
    final existingSessionIds = await _existingIds(_database.focusSessions);
    final existingIntervalIds = await _existingIds(
      _database.focusSessionIntervals,
    );

    for (final task in rows.tasks) {
      final id = task['id'] as String;
      final parentId = task['parentTaskId'] as String?;
      final goalId = task['goalId'] as String?;
      if (parentId != null &&
          !taskIds.contains(parentId) &&
          !existingTaskIds.contains(parentId)) {
        blockers.add('Task "$id" references missing parent "$parentId".');
      }
      if (goalId != null &&
          !goalIds.contains(goalId) &&
          !existingGoalIds.contains(goalId)) {
        blockers.add('Task "$id" references missing goal "$goalId".');
      }
    }
    _checkTaskCycles(rows.tasks, blockers);

    for (final interval in rows.intervals) {
      final sessionId = interval['sessionId'] as String;
      if (!sessionIds.contains(sessionId) &&
          !existingSessionIds.contains(sessionId)) {
        blockers.add(
          'Interval "${interval['id']}" references missing session "$sessionId".',
        );
      }
    }

    final importedUnresolved = rows.sessions.where((session) {
      final status = session['status'];
      return (status == 'running' || status == 'paused') &&
          !existingSessionIds.contains(session['id']);
    }).length;
    final existingUnresolved = await (_database.select(
      _database.focusSessions,
    )..where((session) => session.status.isIn(['running', 'paused']))).get();
    if (existingUnresolved.length + importedUnresolved > 1) {
      blockers.add(
        'Import would create more than one unresolved focus session. Finish '
        'the current session first.',
      );
    }

    final taskConflicts = taskIds.intersection(existingTaskIds).length;
    final goalConflicts = goalIds.intersection(existingGoalIds).length;
    final sessionConflicts = sessionIds.intersection(existingSessionIds).length;
    final intervalConflicts = intervalIds
        .intersection(existingIntervalIds)
        .length;
    if (taskConflicts > 0) {
      warnings.add(
        '$taskConflicts task(s) already exist and will be skipped unless '
        'overwrite is selected.',
      );
    }
    if (goalConflicts > 0) {
      warnings.add(
        '$goalConflicts goal(s) already exist and will be skipped unless '
        'overwrite is selected.',
      );
    }
    if (sessionConflicts > 0 || intervalConflicts > 0) {
      warnings.add(
        'Existing focus history is never overwritten. '
        '$sessionConflicts session(s) and $intervalConflicts interval(s) '
        'will be skipped.',
      );
    }

    final createdAt = document['createdAtUtc'];
    final appVersion = document['appVersion'];
    return SelectiveImportPreview(
      datasets: rows.datasets,
      taskCount: rows.tasks.length,
      goalCount: rows.goals.length,
      focusSessionCount: rows.sessions.length,
      focusIntervalCount: rows.intervals.length,
      existingTaskCount: taskConflicts,
      existingGoalCount: goalConflicts,
      existingFocusSessionCount: sessionConflicts,
      warnings: List.unmodifiable(warnings),
      blockers: List.unmodifiable(blockers),
      createdAt: createdAt is String ? DateTime.tryParse(createdAt) : null,
      appVersion: appVersion is String ? appVersion : null,
    );
  }

  Future<SelectiveImportResult> import(
    String encoded, {
    required bool confirmed,
    bool overwriteExisting = false,
  }) async {
    if (!confirmed) {
      throw const SelectiveImportException(
        'Selective import requires explicit confirmation.',
      );
    }
    final preview = await this.preview(encoded);
    if (!preview.canImport) {
      throw SelectiveImportException(
        'Selective import was blocked: ${preview.blockers.join(' ')}',
      );
    }
    final document = _decode(encoded);
    final rows = _decodeRows(document);
    final warnings = <String>[...preview.warnings];
    var tasksImported = 0;
    var tasksSkipped = 0;
    var goalsImported = 0;
    var goalsSkipped = 0;
    var sessionsImported = 0;
    var sessionsSkipped = 0;

    await _database.transaction(() async {
      for (final goal in rows.goals) {
        final exists = await _rowExists(_database.goals, goal['id'] as String);
        if (exists && !overwriteExisting) {
          goalsSkipped++;
          continue;
        }
        await _database
            .into(_database.goals)
            .insertOnConflictUpdate(_goalCompanion(goal));
        goalsImported++;
      }

      for (final task in rows.tasks) {
        final exists = await _rowExists(_database.tasks, task['id'] as String);
        if (exists && !overwriteExisting) {
          tasksSkipped++;
          continue;
        }
        await _database
            .into(_database.tasks)
            .insertOnConflictUpdate(_taskCompanion(task));
        tasksImported++;
      }

      for (final session in rows.sessions) {
        final sessionId = session['id'] as String;
        final exists = await _rowExists(_database.focusSessions, sessionId);
        if (exists) {
          sessionsSkipped++;
          continue;
        }
        await _database
            .into(_database.focusSessions)
            .insert(_sessionCompanion(session));
        sessionsImported++;
        for (final interval in rows.intervals.where(
          (row) => row['sessionId'] == sessionId,
        )) {
          final intervalExists = await _rowExists(
            _database.focusSessionIntervals,
            interval['id'] as String,
          );
          if (intervalExists) {
            warnings.add(
              'Interval "${interval['id']}" already exists and was skipped.',
            );
            continue;
          }
          await _database
              .into(_database.focusSessionIntervals)
              .insert(_intervalCompanion(interval));
        }
      }
    });

    return SelectiveImportResult(
      tasksImported: tasksImported,
      tasksSkipped: tasksSkipped,
      goalsImported: goalsImported,
      goalsSkipped: goalsSkipped,
      focusSessionsImported: sessionsImported,
      focusSessionsSkipped: sessionsSkipped,
      warnings: List.unmodifiable(warnings),
    );
  }

  Future<Set<String>> _existingIds<T extends Table, R>(
    TableInfo<T, R> table,
  ) async {
    final column = table.$primaryKey.single;
    final rows = await _database
        .customSelect('SELECT "${column.name}" FROM "${table.actualTableName}"')
        .get();
    return rows.map((row) => row.data.values.first!.toString()).toSet();
  }

  Future<bool> _rowExists<T extends Table, R>(
    TableInfo<T, R> table,
    String id,
  ) async {
    final column = table.$primaryKey.single;
    final rows = await _database
        .customSelect(
          'SELECT 1 FROM "${table.actualTableName}" '
          'WHERE "${column.name}" = ? LIMIT 1',
          variables: [Variable<String>(id)],
        )
        .get();
    return rows.isNotEmpty;
  }

  Map<String, dynamic> _decode(String encoded) {
    if (!BackupService.isDocumentWithinLimit(encoded.length)) {
      throw const SelectiveImportException(
        'Selective export is too large to import safely.',
      );
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) {
        throw const SelectiveImportException(
          'Selective export root must be an object.',
        );
      }
      if (decoded['format'] != format) {
        throw const SelectiveImportException(
          'This is not a Systum selective export. Use Import backup for full '
          'backups.',
        );
      }
      if (decoded['version'] != currentVersion) {
        throw const SelectiveImportException(
          'Unsupported selective export version.',
        );
      }
      if (decoded['databaseSchemaVersion'] != _database.schemaVersion) {
        throw const SelectiveImportException(
          'Selective export schema is not supported by this version.',
        );
      }
      if (decoded['data'] is! Map<String, dynamic>) {
        throw const SelectiveImportException(
          'Selective export data is incomplete.',
        );
      }
      _verifyPayload(decoded);
      return decoded;
    } on SelectiveImportException {
      rethrow;
    } on FormatException catch (error) {
      throw SelectiveImportException(
        'Selective export is not valid JSON: $error',
      );
    }
  }

  void _verifyPayload(Map<String, dynamic> document) {
    final length = document['payloadLengthBytes'];
    final hash = document['payloadSha256'];
    if (length == null && hash == null) return;
    if (length is! int || hash is! String) {
      throw const SelectiveImportException(
        'Selective export integrity metadata is invalid.',
      );
    }
    final payload = jsonEncode(document['data']);
    final bytes = utf8.encode(payload);
    if (bytes.length != length || sha256.convert(bytes).toString() != hash) {
      throw const SelectiveImportException(
        'Selective export integrity verification failed.',
      );
    }
  }

  _Rows _decodeRows(Map<String, dynamic> document) {
    final data = document['data'] as Map<String, dynamic>;
    final datasets = {
      for (final value in (document['datasets'] as List? ?? const []))
        if (value is String)
          for (final dataset in SelectiveDataset.values)
            if (dataset.key == value) dataset,
    };
    final tasks = _rows(data['tasks'], 'tasks');
    final goals = _rows(data['goals'], 'goals');
    final sessions = _rows(data['focusSessions'], 'focusSessions');
    final intervals = _rows(data['focusIntervals'], 'focusIntervals');
    _validateRows(
      tasks: tasks,
      goals: goals,
      sessions: sessions,
      intervals: intervals,
    );
    return _Rows(
      datasets: datasets,
      tasks: tasks,
      goals: goals,
      sessions: sessions,
      intervals: intervals,
    );
  }

  List<Map<String, dynamic>> _rows(dynamic value, String label) {
    if (value == null) return const [];
    if (value is! List) {
      throw SelectiveImportException('Selective export $label is invalid.');
    }
    return [
      for (final row in value)
        if (row is Map<String, dynamic>)
          row
        else
          throw SelectiveImportException(
            'Selective export $label contains an invalid row.',
          ),
    ];
  }

  void _validateRows({
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> goals,
    required List<Map<String, dynamic>> sessions,
    required List<Map<String, dynamic>> intervals,
  }) {
    for (final goal in goals) {
      _requireString(goal, 'id', 'goal');
      _requireString(goal, 'title', 'goal');
      _requireInt(goal, 'createdAtMs', 'goal');
      _requireInt(goal, 'updatedAtMs', 'goal');
      _optionalInt(goal, 'targetDateEpochDay', 'goal');
      _optionalString(goal, 'description', 'goal');
    }
    for (final task in tasks) {
      _requireString(task, 'id', 'task');
      _requireString(task, 'title', 'task');
      _requireBool(task, 'completed', 'task');
      _requireInt(task, 'createdAtMs', 'task');
      _requireInt(task, 'updatedAtMs', 'task');
      _requireInt(task, 'priority', 'task');
      _optionalInt(task, 'dueDateMs', 'task');
      _optionalInt(task, 'dueTimeSeconds', 'task');
      _optionalString(task, 'dueTimezone', 'task');
      _optionalString(task, 'description', 'task');
      _optionalString(task, 'category', 'task');
      _optionalString(task, 'goalId', 'task');
      _optionalString(task, 'parentTaskId', 'task');
    }
    for (final session in sessions) {
      _requireString(session, 'id', 'focus session');
      _requireString(session, 'mode', 'focus session');
      _requireString(session, 'status', 'focus session');
      _requireInt(session, 'startedAtMs', 'focus session');
      _requireInt(session, 'updatedAtMs', 'focus session');
      if (!FocusSessionMode.values.any(
        (mode) => mode.name == session['mode'],
      )) {
        throw const SelectiveImportException(
          'Selective export focus session mode is invalid.',
        );
      }
      if (!FocusSessionStatus.values.any(
        (status) => status.name == session['status'],
      )) {
        throw const SelectiveImportException(
          'Selective export focus session status is invalid.',
        );
      }
      _optionalInt(session, 'endedAtMs', 'focus session');
      _optionalInt(session, 'plannedDurationMs', 'focus session');
      _optionalInt(session, 'actualDurationMs', 'focus session');
      _optionalInt(session, 'cycleRound', 'focus session');
      _optionalString(session, 'taskId', 'focus session');
      _optionalString(session, 'taskIdAtStart', 'focus session');
      _optionalString(session, 'taskTitleAtStart', 'focus session');
      _optionalString(session, 'cycleId', 'focus session');
    }
    for (final interval in intervals) {
      _requireString(interval, 'id', 'focus interval');
      _requireString(interval, 'sessionId', 'focus interval');
      _requireInt(interval, 'startedAtMs', 'focus interval');
      _optionalInt(interval, 'endedAtMs', 'focus interval');
    }
  }

  void _checkDuplicateIds(_Rows rows, List<String> blockers) {
    void check(List<Map<String, dynamic>> values, String label) {
      final seen = <String>{};
      for (final row in values) {
        final id = row['id'] as String;
        if (!seen.add(id)) blockers.add('Duplicate $label id "$id".');
      }
    }

    check(rows.goals, 'goal');
    check(rows.tasks, 'task');
    check(rows.sessions, 'focus session');
    check(rows.intervals, 'focus interval');
  }

  void _checkTaskCycles(
    List<Map<String, dynamic>> tasks,
    List<String> blockers,
  ) {
    final parents = {
      for (final task in tasks)
        task['id'] as String: task['parentTaskId'] as String?,
    };
    for (final task in tasks) {
      final visited = <String>{};
      String? current = task['id'] as String;
      while (current != null) {
        if (!visited.add(current)) {
          blockers.add('Task hierarchy contains a cycle at "$current".');
          break;
        }
        current = parents[current];
      }
    }
  }

  String _requireString(Map<String, dynamic> row, String key, String label) {
    final value = row[key];
    if (value is! String || value.isEmpty) {
      throw SelectiveImportException(
        'Selective export $label field "$key" is invalid.',
      );
    }
    return value;
  }

  String? _optionalString(Map<String, dynamic> row, String key, String label) {
    final value = row[key];
    if (value != null && value is! String) {
      throw SelectiveImportException(
        'Selective export $label field "$key" is invalid.',
      );
    }
    return value as String?;
  }

  int _requireInt(Map<String, dynamic> row, String key, String label) {
    final value = row[key];
    if (value is! int) {
      throw SelectiveImportException(
        'Selective export $label field "$key" is invalid.',
      );
    }
    return value;
  }

  int? _optionalInt(Map<String, dynamic> row, String key, String label) {
    final value = row[key];
    if (value != null && value is! int) {
      throw SelectiveImportException(
        'Selective export $label field "$key" is invalid.',
      );
    }
    return value as int?;
  }

  bool _requireBool(Map<String, dynamic> row, String key, String label) {
    final value = row[key];
    if (value is! bool) {
      throw SelectiveImportException(
        'Selective export $label field "$key" is invalid.',
      );
    }
    return value;
  }

  GoalsCompanion _goalCompanion(Map<String, dynamic> row) {
    return GoalsCompanion(
      id: Value(row['id'] as String),
      title: Value(row['title'] as String),
      description: Value(row['description'] as String?),
      targetDate: Value(
        row['targetDateEpochDay'] == null
            ? null
            : GoalDate(row['targetDateEpochDay'] as int),
      ),
      createdAt: Value(_date(row['createdAtMs'] as int)),
      updatedAt: Value(_date(row['updatedAtMs'] as int)),
    );
  }

  TasksCompanion _taskCompanion(Map<String, dynamic> row) {
    return TasksCompanion(
      id: Value(row['id'] as String),
      title: Value(row['title'] as String),
      description: Value(row['description'] as String?),
      completed: Value(row['completed'] as bool),
      createdAt: Value(_date(row['createdAtMs'] as int)),
      updatedAt: Value(_date(row['updatedAtMs'] as int)),
      dueDate: Value(
        row['dueDateMs'] == null ? null : _date(row['dueDateMs'] as int),
      ),
      dueTime: Value(row['dueTimeSeconds'] as int?),
      dueTimezone: Value(row['dueTimezone'] as String?),
      priority: Value(row['priority'] as int),
      category: Value(row['category'] as String?),
      goalId: Value(row['goalId'] as String?),
      parentTaskId: Value(row['parentTaskId'] as String?),
    );
  }

  FocusSessionsCompanion _sessionCompanion(Map<String, dynamic> row) {
    return FocusSessionsCompanion(
      id: Value(row['id'] as String),
      taskId: Value(row['taskId'] as String?),
      taskIdAtStart: Value(row['taskIdAtStart'] as String?),
      taskTitleAtStart: Value(row['taskTitleAtStart'] as String?),
      mode: Value(
        FocusSessionMode.values.firstWhere((mode) => mode.name == row['mode']),
      ),
      status: Value(
        FocusSessionStatus.values.firstWhere(
          (status) => status.name == row['status'],
        ),
      ),
      startedAtMs: Value(row['startedAtMs'] as int),
      endedAtMs: Value(row['endedAtMs'] as int?),
      plannedDurationMs: Value(row['plannedDurationMs'] as int?),
      actualDurationMs: Value(row['actualDurationMs'] as int?),
      cycleId: Value(row['cycleId'] as String?),
      cycleRound: Value(row['cycleRound'] as int?),
      updatedAtMs: Value(row['updatedAtMs'] as int),
    );
  }

  FocusSessionIntervalsCompanion _intervalCompanion(Map<String, dynamic> row) {
    return FocusSessionIntervalsCompanion(
      id: Value(row['id'] as String),
      sessionId: Value(row['sessionId'] as String),
      startedAtMs: Value(row['startedAtMs'] as int),
      endedAtMs: Value(row['endedAtMs'] as int?),
    );
  }

  DateTime _date(int milliseconds) =>
      DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
}

final class _Rows {
  const _Rows({
    required this.datasets,
    required this.tasks,
    required this.goals,
    required this.sessions,
    required this.intervals,
  });

  final Set<SelectiveDataset> datasets;
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> goals;
  final List<Map<String, dynamic>> sessions;
  final List<Map<String, dynamic>> intervals;
}

class SelectiveImportException implements Exception {
  const SelectiveImportException(this.message);

  final String message;

  @override
  String toString() => 'SelectiveImportException: $message';
}
