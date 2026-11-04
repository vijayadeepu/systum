import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../models/task_recurrence.dart';
import '../repository/task_repository.dart';
import 'task_provider.dart';

/// Inclusive date range used for occurrence queries.
class DateRange {
  const DateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateRange && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// A single recurrence rule by ID.
final taskRecurrenceRuleProvider =
    FutureProvider.family<TaskRecurrenceRule?, String>((ref, ruleId) async {
      final repository = ref.watch(taskRepositoryProvider);
      return repository.getRecurrenceRule(ruleId);
    });

/// Every rule for a parent task.
final taskRecurrenceRulesProvider =
    FutureProvider.family<List<TaskRecurrenceRule>, String>((
      ref,
      parentTaskId,
    ) async {
      final repository = ref.watch(taskRepositoryProvider);
      return repository.getRecurrenceRulesForParent(parentTaskId);
    });

/// The preferred rule for a parent task, or null when it does not recur.
final taskRecurrenceForTaskProvider =
    FutureProvider.family<TaskRecurrenceRule?, String>((
      ref,
      parentTaskId,
    ) async {
      final repository = ref.watch(taskRepositoryProvider);
      return repository.getRecurrenceRuleForParent(parentTaskId);
    });

/// Every recurrence rule keyed by parent task ID. Used for list badges.
final allTaskRecurrenceRulesProvider =
    FutureProvider<Map<String, TaskRecurrenceRule>>((ref) async {
      final repository = ref.watch(taskRepositoryProvider);
      final rules = await repository.getAllRecurrenceRules();
      return {
        for (final rule in rules)
          if (rule.parentTaskId != null) rule.parentTaskId!: rule,
      };
    });

/// Non-deleted occurrences of a rule, ordered by date.
final taskOccurrencesProvider =
    FutureProvider.family<List<TaskOccurrence>, String>((ref, ruleId) async {
      final repository = ref.watch(taskRepositoryProvider);
      return repository.getOccurrencesForRule(ruleId);
    });

/// Non-deleted occurrences in an inclusive date range.
final taskOccurrencesInRangeProvider =
    FutureProvider.family<List<TaskOccurrence>, DateRange>((ref, range) async {
      final repository = ref.watch(taskRepositoryProvider);
      return repository.getOccurrencesForDateRange(range.start, range.end);
    });

/// Runs bounded missed-occurrence recovery once after startup.
///
/// Failures are surfaced as provider errors (the app remains usable); the next
/// launch retries generation because generation is idempotent.
final recurrenceRecoveryProvider = FutureProvider<void>((ref) async {
  final repository = ref.watch(taskRepositoryProvider);
  await repository.generateAllOccurrences();
});

/// Coordinates recurrence mutations and invalidates the affected providers.
///
/// Widgets call these methods instead of reading repositories directly. The
/// action layer keeps task lists, detail views, rules and occurrence lists in
/// sync without duplicating invalidation logic in each screen.
final recurrenceActionsProvider = Provider<RecurrenceActions>((ref) {
  return RecurrenceActions(ref);
});

class RecurrenceActions {
  RecurrenceActions(this._ref);

  final Ref _ref;

  TaskRepository get _repository => _ref.read(taskRepositoryProvider);

  Future<void> createTaskWithRecurrence(
    Task task,
    RecurrenceDraft draft,
  ) async {
    await _ref
        .read(taskProvider.notifier)
        .createTaskWithRecurrence(task, draft);
    _invalidateForTask(task.id);
  }

  Future<void> createTaskInGoalWithRecurrence(
    Task task,
    String goalId,
    RecurrenceDraft draft,
  ) async {
    await _ref
        .read(taskProvider.notifier)
        .createTaskInGoalWithRecurrence(task, goalId, draft);
    _invalidateForTask(task.id);
  }

  Future<void> updateTaskWithRecurrence(
    Task task,
    RecurrenceDraft? draft, {
    TaskRecurrenceRule? existingRule,
  }) async {
    await _ref
        .read(taskProvider.notifier)
        .updateTaskWithRecurrence(
          task,
          draft,
          existingRuleId: existingRule?.id,
        );
    _invalidateForTask(task.id);
    if (existingRule != null) {
      _ref.invalidate(taskOccurrencesProvider(existingRule.id));
    }
  }

  Future<void> stopRecurrence(String parentTaskId, String ruleId) async {
    await _ref.read(taskProvider.notifier).stopRecurrence(ruleId);
    _invalidateForTask(parentTaskId);
    _ref.invalidate(taskOccurrencesProvider(ruleId));
  }

  Future<void> setOccurrenceCompleted(
    String ruleId,
    String occurrenceId,
    bool completed,
  ) async {
    await _repository.setOccurrenceCompleted(occurrenceId, completed);
    _ref.invalidate(taskOccurrencesProvider(ruleId));
    _ref.invalidate(taskOccurrencesInRangeProvider);
  }

  Future<void> deleteOccurrence(String ruleId, String occurrenceId) async {
    await _repository.deleteOccurrence(occurrenceId);
    _ref.invalidate(taskOccurrencesProvider(ruleId));
    _ref.invalidate(taskOccurrencesInRangeProvider);
  }

  Future<void> rescheduleOccurrence(
    String ruleId,
    String occurrenceId,
    DateTime dueDate,
  ) async {
    await _repository.rescheduleOccurrence(occurrenceId, dueDate);
    _ref.invalidate(taskOccurrencesProvider(ruleId));
    _ref.invalidate(taskOccurrencesInRangeProvider);
  }

  /// Generates every active rule and refreshes recurrence state.
  Future<int> generateAllOccurrences() async {
    final generated = await _repository.generateAllOccurrences();
    _ref.invalidate(allTaskRecurrenceRulesProvider);
    _ref.invalidate(taskOccurrencesProvider);
    _ref.invalidate(taskOccurrencesInRangeProvider);
    return generated;
  }

  void _invalidateForTask(String taskId) {
    _ref.invalidate(allTaskRecurrenceRulesProvider);
    _ref.invalidate(taskRecurrenceForTaskProvider(taskId));
    _ref.invalidate(taskRecurrenceRulesProvider(taskId));
    _ref.invalidate(taskDetailProvider(taskId));
  }
}
