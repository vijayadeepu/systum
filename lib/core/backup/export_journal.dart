import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum ExportJournalStatus {
  prepared,
  staging,
  stagingVerified,
  publishing,
  destinationWriteCompleted,
  destinationVerified,
  completed,
  recoveryRequired;

  String get wireValue => switch (this) {
    prepared => 'prepared',
    staging => 'staging',
    stagingVerified => 'staging_verified',
    publishing => 'publishing',
    destinationWriteCompleted => 'destination_write_completed',
    destinationVerified => 'destination_verified',
    completed => 'completed',
    recoveryRequired => 'recovery_required',
  };

  static ExportJournalStatus parse(String value) => switch (value) {
    'prepared' => prepared,
    'staging' => staging,
    'staging_verified' => stagingVerified,
    'publishing' => publishing,
    'destination_write_completed' => destinationWriteCompleted,
    'destination_verified' => destinationVerified,
    'completed' => completed,
    'recovery_required' => recoveryRequired,
    _ => throw ExportJournalException('Unknown export journal status.'),
  };
}

final class ExportJournal {
  const ExportJournal({
    required this.operationId,
    required this.schemaVersion,
    required this.status,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.stagingPath,
    required this.expectedLength,
    required this.expectedSha256,
    this.destinationPath,
    this.destinationVerification,
  });

  static const currentSchemaVersion = 1;

  final String operationId;
  final int schemaVersion;
  final ExportJournalStatus status;
  final int createdAtMs;
  final int updatedAtMs;
  final String stagingPath;
  final int expectedLength;
  final String expectedSha256;
  final String? destinationPath;
  final String? destinationVerification;

  ExportJournal copyWith({
    required ExportJournalStatus status,
    int? updatedAtMs,
    String? destinationPath,
    String? destinationVerification,
  }) => ExportJournal(
    operationId: operationId,
    schemaVersion: schemaVersion,
    status: status,
    createdAtMs: createdAtMs,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    stagingPath: stagingPath,
    expectedLength: expectedLength,
    expectedSha256: expectedSha256,
    destinationPath: destinationPath ?? this.destinationPath,
    destinationVerification:
        destinationVerification ?? this.destinationVerification,
  );

  Map<String, dynamic> toJson() => {
    'operationId': operationId,
    'schemaVersion': schemaVersion,
    'status': status.wireValue,
    'createdAtMs': createdAtMs,
    'updatedAtMs': updatedAtMs,
    'stagingPath': stagingPath,
    'expectedLength': expectedLength,
    'expectedSha256': expectedSha256,
    if (destinationPath != null) 'destinationPath': destinationPath,
    if (destinationVerification != null)
      'destinationVerification': destinationVerification,
  };

  static ExportJournal fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const ExportJournalException('Export journal is not an object.');
    }
    final schemaVersion = value['schemaVersion'];
    final createdAtMs = value['createdAtMs'];
    final updatedAtMs = value['updatedAtMs'];
    final expectedLength = value['expectedLength'];
    if (schemaVersion != currentSchemaVersion ||
        createdAtMs is! int ||
        updatedAtMs is! int ||
        expectedLength is! int ||
        expectedLength < 0) {
      throw const ExportJournalException('Export journal schema is invalid.');
    }
    final operationId = value['operationId'];
    final status = value['status'];
    final stagingPath = value['stagingPath'];
    final checksum = value['expectedSha256'];
    if (operationId is! String ||
        operationId.isEmpty ||
        status is! String ||
        stagingPath is! String ||
        stagingPath.isEmpty ||
        checksum is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(checksum)) {
      throw const ExportJournalException(
        'Export journal contents are invalid.',
      );
    }
    final destinationPath = value['destinationPath'];
    final destinationVerification = value['destinationVerification'];
    if (destinationPath != null && destinationPath is! String ||
        destinationVerification != null && destinationVerification is! String) {
      throw const ExportJournalException(
        'Export journal destination is invalid.',
      );
    }
    return ExportJournal(
      operationId: operationId,
      schemaVersion: schemaVersion,
      status: ExportJournalStatus.parse(status),
      createdAtMs: createdAtMs,
      updatedAtMs: updatedAtMs,
      stagingPath: stagingPath,
      expectedLength: expectedLength,
      expectedSha256: checksum,
      destinationPath: destinationPath as String?,
      destinationVerification: destinationVerification as String?,
    );
  }
}

abstract interface class ExportJournalStore {
  Future<ExportJournal?> load();

  Future<void> save(ExportJournal journal);

  Future<void> clear();
}

final class SharedPreferencesExportJournalStore implements ExportJournalStore {
  static const key = 'systum.backup.export_journal.v1';

  @override
  Future<ExportJournal?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(key);
    if (encoded == null) return null;
    try {
      return ExportJournal.fromJson(jsonDecode(encoded));
    } on FormatException catch (error) {
      throw ExportJournalException('Export journal JSON is invalid: $error');
    }
  }

  @override
  Future<void> save(ExportJournal journal) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(key, jsonEncode(journal.toJson()))) {
      throw const ExportJournalException('Could not save export journal.');
    }
  }

  @override
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    final removed = await preferences.remove(key);
    if (!removed && preferences.containsKey(key)) {
      throw const ExportJournalException('Could not clear export journal.');
    }
  }
}

class ExportJournalException implements Exception {
  const ExportJournalException(this.message);

  final String message;

  @override
  String toString() => 'ExportJournalException: $message';
}
