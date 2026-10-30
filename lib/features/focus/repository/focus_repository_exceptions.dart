class FocusSessionAlreadyUnresolvedException implements Exception {
  const FocusSessionAlreadyUnresolvedException(this.sessionId);

  final String sessionId;

  @override
  String toString() =>
      'FocusSessionAlreadyUnresolvedException: session "$sessionId" '
      'is still running or paused.';
}

class FocusSessionNotFoundException implements Exception {
  const FocusSessionNotFoundException(this.sessionId);

  final String sessionId;

  @override
  String toString() =>
      'FocusSessionNotFoundException: session "$sessionId" does not exist.';
}

class FocusTaskNotFoundException implements Exception {
  const FocusTaskNotFoundException(this.taskId);

  final String taskId;

  @override
  String toString() =>
      'FocusTaskNotFoundException: task "$taskId" does not exist.';
}

class FocusSessionIntegrityException implements Exception {
  const FocusSessionIntegrityException(this.sessionId, this.reason);

  final String sessionId;
  final String reason;

  @override
  String toString() =>
      'FocusSessionIntegrityException: session "$sessionId": $reason';
}
