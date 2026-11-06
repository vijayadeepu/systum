import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/database_provider.dart';
import '../repository/reminder_repository.dart';

/// Persistence boundary shared by reminder state and delivery.
///
/// Kept separate from [remindersProvider] so delivery can depend on the
/// repository without importing task-list state.
final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepository(ref.watch(databaseProvider));
});
