/// A continuous period during which a focus session was running.
///
/// Timestamps are UTC epoch milliseconds. A null [endedAtMs] means the
/// interval is currently open.
final class FocusSessionInterval {
  FocusSessionInterval({
    required this.sessionId,
    required this.startedAtMs,
    this.endedAtMs,
  }) {
    if (endedAtMs case final endedAtMs? when endedAtMs < startedAtMs) {
      throw ArgumentError.value(
        endedAtMs,
        'endedAtMs',
        'Must not precede startedAtMs.',
      );
    }
  }

  final String sessionId;
  final int startedAtMs;
  final int? endedAtMs;

  bool get isOpen => endedAtMs == null;

  int durationAt(int atMs) {
    final end = endedAtMs ?? atMs;
    if (end < startedAtMs) {
      throw ArgumentError.value(atMs, 'atMs', 'Must not precede startedAtMs.');
    }
    return end - startedAtMs;
  }

  FocusSessionInterval closeAt(int atMs) {
    if (!isOpen) {
      throw StateError('Only an open interval can be closed.');
    }
    return FocusSessionInterval(
      sessionId: sessionId,
      startedAtMs: startedAtMs,
      endedAtMs: atMs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FocusSessionInterval &&
          sessionId == other.sessionId &&
          startedAtMs == other.startedAtMs &&
          endedAtMs == other.endedAtMs;

  @override
  int get hashCode => Object.hash(sessionId, startedAtMs, endedAtMs);
}
