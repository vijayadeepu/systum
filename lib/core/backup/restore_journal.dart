import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum RestoreJournalStatus {
  prepared,
  databaseCommitted,
  preferencesApplied,
  completed;

  static RestoreJournalStatus parse(String value) => switch (value) {
    'prepared' => prepared,
    'database_committed' => databaseCommitted,
    'preferences_applied' => preferencesApplied,
    'completed' => completed,
    _ => throw RestoreJournalException('Unknown restore journal status.'),
  };

  String get wireValue => switch (this) {
    prepared => 'prepared',
    databaseCommitted => 'database_committed',
    preferencesApplied => 'preferences_applied',
    completed => 'completed',
  };
}

final class RestoreJournal {
  const RestoreJournal({
    required this.operationId,
    required this.schemaVersion,
    required this.status,
    required this.createdAtMs,
    required this.databaseFingerprint,
    required this.incomingPreferences,
    required this.previousPreferences,
  });

  static const currentSchemaVersion = 1;

  final String operationId;
  final int schemaVersion;
  final RestoreJournalStatus status;
  final int createdAtMs;
  final String databaseFingerprint;
  final Map<String, dynamic> incomingPreferences;
  final Map<String, dynamic> previousPreferences;

  RestoreJournal copyWith({RestoreJournalStatus? status}) => RestoreJournal(
    operationId: operationId,
    schemaVersion: schemaVersion,
    status: status ?? this.status,
    createdAtMs: createdAtMs,
    databaseFingerprint: databaseFingerprint,
    incomingPreferences: incomingPreferences,
    previousPreferences: previousPreferences,
  );

  Map<String, dynamic> toJson() => {
    'operationId': operationId,
    'schemaVersion': schemaVersion,
    'status': status.wireValue,
    'createdAtMs': createdAtMs,
    'databaseFingerprint': databaseFingerprint,
    'incomingPreferences': incomingPreferences,
    'previousPreferences': previousPreferences,
  };

  static RestoreJournal fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const RestoreJournalException('Restore journal is not an object.');
    }
    final schemaVersion = value['schemaVersion'];
    final createdAtMs = value['createdAtMs'];
    if (schemaVersion != currentSchemaVersion || createdAtMs is! int) {
      throw const RestoreJournalException(
        'Restore journal schema is unsupported.',
      );
    }
    final operationId = value['operationId'];
    final fingerprint = value['databaseFingerprint'];
    final incoming = value['incomingPreferences'];
    final previous = value['previousPreferences'];
    if (operationId is! String ||
        operationId.isEmpty ||
        fingerprint is! String ||
        fingerprint.isEmpty ||
        incoming is! Map<String, dynamic> ||
        previous is! Map<String, dynamic>) {
      throw const RestoreJournalException(
        'Restore journal contents are invalid.',
      );
    }
    final status = value['status'];
    if (status is! String) {
      throw const RestoreJournalException('Restore journal status is invalid.');
    }
    return RestoreJournal(
      operationId: operationId,
      schemaVersion: schemaVersion,
      status: RestoreJournalStatus.parse(status),
      createdAtMs: createdAtMs,
      databaseFingerprint: fingerprint,
      incomingPreferences: incoming,
      previousPreferences: previous,
    );
  }
}

abstract interface class RestoreJournalStore {
  Future<RestoreJournal?> load();

  Future<void> save(RestoreJournal journal);

  Future<void> clear();
}

final class SharedPreferencesRestoreJournalStore
    implements RestoreJournalStore {
  static const key = 'systum.backup.restore_journal.v1';

  @override
  Future<RestoreJournal?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(key);
    if (encoded == null) return null;
    try {
      return RestoreJournal.fromJson(jsonDecode(encoded));
    } on FormatException catch (error) {
      throw RestoreJournalException('Restore journal JSON is invalid: $error');
    }
  }

  @override
  Future<void> save(RestoreJournal journal) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      key,
      jsonEncode(journal.toJson()),
    );
    if (!saved) {
      throw const RestoreJournalException('Could not save restore journal.');
    }
  }

  @override
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    final removed = await preferences.remove(key);
    if (!removed && preferences.containsKey(key)) {
      throw const RestoreJournalException('Could not clear restore journal.');
    }
  }
}

class RestoreJournalException implements Exception {
  const RestoreJournalException(this.message);

  final String message;

  @override
  String toString() => 'RestoreJournalException: $message';
}
