import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'focus_provider.dart';
import '../models/focus_session.dart';
import '../repository/focus_repository.dart';

/// Centralized recovery of persisted Focus state.
///
/// Recovery is:
/// - Deterministic: same persisted state + same current time → same result.
/// - Idempotent: safe to call multiple times; it only reads from SQLite and
///   never creates, updates, or deletes sessions or intervals.
/// - Transaction-safe: reads use the existing repository mechanisms.
/// - Non-destructive: never deletes valid Focus history. Inconsistent
///   persisted state surfaces as an error rather than being silently repaired
///   or deleted.
/// - Centralized: one recovery path rather than scattered lifecycle-specific
///   implementations.
///
/// It does not create a second timer engine, persistence layer, or state
/// machine. Elapsed time is derived from persisted timestamps and intervals,
/// not from UI timer ticks.
class FocusRecovery {
  FocusRecovery({required this.repository});

  final FocusRepository repository;

  /// Recovers the single unresolved (running or paused) Focus session, if any.
  ///
  /// Returns [null] when no session is active. The result is derived entirely
  /// from persisted SQLite state; elapsed time is calculated from persisted
  /// timestamps, not from UI timer ticks.
  ///
  /// Calling this method multiple times is safe: it only reads from the
  /// database and never mutates persisted state. If persisted state is
  /// inconsistent (for example, a running session with no open interval), a
  /// [FocusSessionIntegrityException] is thrown and no history is deleted.
  Future<FocusSessionTransition?> recover() async {
    return repository.getUnresolvedSession();
  }
}

/// Provides the centralized Focus recovery instance.
final focusRecoveryProvider = Provider<FocusRecovery>((ref) {
  return FocusRecovery(repository: ref.watch(focusRepositoryProvider));
});

/// Runs Focus recovery at application startup.
///
/// The result is observed but never gates startup: a transient database read
/// failure cannot prevent the user from opening the app. Recovery is
/// non-blocking and non-destructive; it reads persisted state and surfaces any
/// integrity issues without deleting valid history. Later lifecycle actions
/// (app resume, opening the Focus page) reconcile through the same idempotent
/// path.
final focusStartupRecoveryProvider = FutureProvider<void>((ref) async {
  final recovery = ref.watch(focusRecoveryProvider);
  await recovery.recover();
});
