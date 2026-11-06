import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../../../shared/utils/id_generator.dart';
import '../../reminders/models/reminder.dart';
import '../models/task.dart';
import '../models/task_filter.dart';
import '../models/task_recurrence.dart';
import '../models/task_sort.dart';

class TaskRepository {
  const TaskRepository(this._database);

  final SystumDatabase _database;

  Future<List<TaskRow>> getAll({TaskSort? sort}) {
    if (sort == null) {
      return _orderedTasks().get();
    }
    return _applySort(_database.select(_database.tasks), sort).get();
  }

  Future<TaskRow?> getById(String id) {
    return (_database.select(
      _database.tasks,
    )..where((tasks) => tasks.id.equals(id))).getSingleOrNull();
  }

  /// Returns tasks assigned to [goalId], ordered like [getAll].
  ///
  /// Returns an empty list when the goal has no tasks or when no goal with
  /// [goalId] exists. This read never creates goal or task data.
  Future<List<TaskRow>> getByGoalId(String goalId) {
    return (_orderedTasks()..where((tasks) => tasks.goalId.equals(goalId)))
        .get();
  }

  Future<void> insert(Task task) async {
    await _database.into(_database.tasks).insert(task.toCompanion());
  }

  /// Inserts [task] and assigns it to [goalId] in one transaction.
  ///
  /// This is the create-from-goal path. Unlike [assignToGoal], it is atomic:
  /// a missing goal rolls the insert back instead of leaving a standalone task.
  Future<void> insertInGoal(Task task, String goalId) async {
    await _database.transaction(() async {
      final goal = await (_database.select(
        _database.goals,
      )..where((goals) => goals.id.equals(goalId))).getSingleOrNull();
      if (goal == null) {
        throw TaskRelationshipException('Goal "$goalId" does not exist.');
      }

      await _database
          .into(_database.tasks)
          .insert(task.toCompanion().copyWith(goalId: Value(goalId)));
    });
  }

  Future<void> update(Task task) async {
    final updated = await _database
        .update(_database.tasks)
        .replace(task.toCompanion());
    if (!updated) {
      throw TaskRelationshipException('Task "${task.id}" does not exist.');
    }
  }

  /// Deletes the task with [id].
  ///
  /// Any direct subtasks are promoted to standalone tasks before the task is
  /// deleted. Promotion and deletion run in a single transaction.
  ///
  /// Deleting an ID that does not exist is intentionally a no-op so callers can
  /// retry deletes idempotently.
  Future<void> delete(String id) async {
    await _database.transaction(() async {
      final task = await getById(id);
      if (task == null) {
        return;
      }

      final children = await (_database.select(
        _database.tasks,
      )..where((tasks) => tasks.parentTaskId.equals(id))).get();
      if (children.isNotEmpty) {
        final promotedRows =
            await (_database.update(_database.tasks)
                  ..where((tasks) => tasks.parentTaskId.equals(id)))
                .write(const TasksCompanion(parentTaskId: Value(null)));
        if (promotedRows != children.length) {
          throw TaskRelationshipException(
            'Could not promote all subtasks of task "$id".',
          );
        }
      }

      final deletedRows = await (_database.delete(
        _database.tasks,
      )..where((tasks) => tasks.id.equals(id))).go();
      if (deletedRows == 0) {
        throw TaskRelationshipException('Task "$id" does not exist.');
      }
    });
  }

  Future<void> setCompleted(String id, bool completed) async {
    final now = DateTime.now().toUtc();
    await _database.transaction(() async {
      final updatedRows =
          await (_database.update(
            _database.tasks,
          )..where((tasks) => tasks.id.equals(id))).write(
            TasksCompanion(completed: Value(completed), updatedAt: Value(now)),
          );
      if (updatedRows == 0) {
        throw TaskRelationshipException('Task "$id" does not exist.');
      }

      // Reminder scheduling intent follows task lifecycle: completing a task
      // suppresses its scheduled reminders, and reopening it reactivates only
      // those suppressed by completion. Explicit user cancellations remain.
      if (completed) {
        await (_database.update(_database.reminders)..where(
              (reminder) =>
                  reminder.taskId.equals(id) &
                  reminder.status.equals(ReminderStatus.scheduled.name),
            ))
            .write(
              RemindersCompanion(
                status: Value(ReminderStatus.cancelled.name),
                cancellationReason: Value(
                  ReminderCancellationReason.taskCompleted.name,
                ),
                cancelledAtMs: Value(now.millisecondsSinceEpoch),
                updatedAtMs: Value(now.millisecondsSinceEpoch),
              ),
            );
      } else {
        await (_database.update(_database.reminders)..where(
              (reminder) =>
                  reminder.taskId.equals(id) &
                  reminder.status.equals(ReminderStatus.cancelled.name) &
                  reminder.cancellationReason.equals(
                    ReminderCancellationReason.taskCompleted.name,
                  ),
            ))
            .write(
              RemindersCompanion(
                status: Value(ReminderStatus.scheduled.name),
                cancellationReason: const Value(null),
                cancelledAtMs: const Value(null),
                updatedAtMs: Value(now.millisecondsSinceEpoch),
              ),
            );
      }
    });
  }

  /// Returns focus sessions linked to [taskId], newest first.
  ///
  /// Sessions are ordered by started timestamp descending with ID as a
  /// deterministic tie-breaker.
  Future<List<FocusSessionRow>> getFocusSessionsForTask(String taskId) {
    return (_database.select(_database.focusSessions)
          ..where((session) => session.taskId.equals(taskId))
          ..orderBy([
            (session) => OrderingTerm.desc(session.startedAtMs),
            (session) => OrderingTerm.desc(session.id),
          ]))
        .get();
  }

  /// Creates [subtask] beneath the existing [parentTaskId].
  ///
  /// Only one level of nesting is supported. The new subtask always inherits
  /// the parent's goal. If [goalId] is provided, it must match the parent's
  /// goal; the stored value is always the inherited one.
  Future<void> createSubtask(
    Task subtask,
    String parentTaskId, {
    String? goalId,
  }) async {
    await _database.transaction(() async {
      // Validation and insertion share a transaction so the parent cannot be
      // deleted or otherwise change between the hierarchy check and the write.
      final parent = await getById(parentTaskId);
      if (parent == null) {
        throw TaskRelationshipException(
          'Parent task "$parentTaskId" does not exist.',
        );
      }
      if (subtask.id == parentTaskId) {
        throw TaskRelationshipException(
          'Task "${subtask.id}" cannot be its own parent.',
        );
      }
      if (parent.parentTaskId != null) {
        throw TaskRelationshipException(
          'Task "$parentTaskId" is a subtask and cannot have subtasks.',
        );
      }
      if (goalId != null && goalId != parent.goalId) {
        final parentGoal = parent.goalId == null
            ? 'no goal'
            : 'goal "${parent.goalId}"';
        throw TaskRelationshipException(
          'Subtask goal "$goalId" conflicts with the parent\'s $parentGoal.',
        );
      }

      await _database
          .into(_database.tasks)
          .insert(
            subtask.toCompanion().copyWith(
              goalId: Value(parent.goalId),
              parentTaskId: Value(parentTaskId),
            ),
          );
    });
  }

  /// Assigns an existing top-level task and its direct subtasks to an existing
  /// goal.
  ///
  /// Subtasks inherit their parent's goal and cannot be assigned independently.
  /// The parent and its direct subtasks are updated in one transaction, so a
  /// failure leaves every goal assignment unchanged. The tasks' other fields,
  /// including their timestamps, are left unchanged.
  Future<void> assignToGoal(String taskId, String goalId) async {
    await _database.transaction(() async {
      final task = await getById(taskId);
      if (task == null) {
        throw TaskRelationshipException('Task "$taskId" does not exist.');
      }
      if (task.parentTaskId != null) {
        throw TaskRelationshipException(
          'Task "$taskId" is a subtask and cannot be assigned to a goal.',
        );
      }

      final goal = await (_database.select(
        _database.goals,
      )..where((goals) => goals.id.equals(goalId))).getSingleOrNull();
      if (goal == null) {
        throw TaskRelationshipException('Goal "$goalId" does not exist.');
      }

      final updatedRows =
          await (_database.update(_database.tasks)..where(
                (tasks) =>
                    tasks.id.equals(taskId) & tasks.parentTaskId.isNull(),
              ))
              .write(TasksCompanion(goalId: Value(goalId)));
      if (updatedRows == 0) {
        throw TaskRelationshipException(
          'Task "$taskId" no longer exists or is now a subtask.',
        );
      }

      await (_database.update(_database.tasks)
            ..where((tasks) => tasks.parentTaskId.equals(taskId)))
          .write(TasksCompanion(goalId: Value(goalId)));
    });
  }

  /// Removes a top-level task's goal assignment and clears the inherited goal
  /// from all of its direct subtasks.
  ///
  /// Subtasks inherit their parent's goal and cannot remove it independently.
  /// The parent and its direct subtasks are updated in one transaction, so a
  /// failure leaves every goal assignment unchanged.
  Future<void> removeFromGoal(String taskId) async {
    await _database.transaction(() async {
      final task = await getById(taskId);
      if (task == null) {
        throw TaskRelationshipException('Task "$taskId" does not exist.');
      }
      if (task.parentTaskId != null) {
        throw TaskRelationshipException(
          'Task "$taskId" is a subtask and cannot remove its inherited goal.',
        );
      }

      final updatedRows =
          await (_database.update(_database.tasks)..where(
                (tasks) =>
                    tasks.id.equals(taskId) & tasks.parentTaskId.isNull(),
              ))
              .write(const TasksCompanion(goalId: Value(null)));
      if (updatedRows == 0) {
        throw TaskRelationshipException(
          'Task "$taskId" no longer exists or is now a subtask.',
        );
      }

      await (_database.update(_database.tasks)
            ..where((tasks) => tasks.parentTaskId.equals(taskId)))
          .write(const TasksCompanion(goalId: Value(null)));
    });
  }

  /// Searches tasks by title and description using case-insensitive partial
  /// matching against persisted data.
  ///
  /// Results are ordered by [sort] (defaults to [TaskSort]).
  Future<List<TaskRow>> searchTasks(String query, {TaskSort? sort}) {
    final trimmed = query.trim();
    final statement = _database.select(_database.tasks);
    if (trimmed.isNotEmpty) {
      statement.where(
        (tasks) => Expression.or([
          tasks.title.contains(trimmed),
          tasks.description.contains(trimmed),
        ]),
      );
    }
    return _applySort(statement, sort ?? const TaskSort()).get();
  }

  /// Returns tasks matching [filter] and [view], ordered by [sort] (defaults
  /// to [TaskSort]).
  ///
  /// [view] and [filter] intersect logically: a task must match both the view
  /// constraints and every active filter dimension to be included.
  Future<List<TaskRow>> filterTasks(
    TaskFilter filter, {
    TaskSort? sort,
    TaskView? view,
  }) {
    return _applyFilter(
      _database.select(_database.tasks),
      filter,
      sort: sort,
      view: view,
    ).get();
  }

  /// Returns tasks matching both [query] (title/description search) and
  /// [filter], plus [view] constraints, ordered by [sort] (defaults to
  /// [TaskSort]).
  Future<List<TaskRow>> searchAndFilter(
    String query,
    TaskFilter filter, {
    TaskSort? sort,
    TaskView? view,
  }) {
    final trimmed = query.trim();
    final statement = _database.select(_database.tasks);
    if (trimmed.isNotEmpty) {
      statement.where(
        (tasks) => Expression.or([
          tasks.title.contains(trimmed),
          tasks.description.contains(trimmed),
        ]),
      );
    }
    return _applyFilter(statement, filter, sort: sort, view: view).get();
  }

  /// Applies every active dimension of [filter] and [view] to [statement] and
  /// returns the resulting query, ordered by [sort].
  ///
  /// Note: drift 2.x [SimpleSelectStatement.where] mutates the statement in
  /// place and returns void, so calls are not chained.
  SimpleSelectStatement<$TasksTable, TaskRow> _applyFilter(
    SimpleSelectStatement<$TasksTable, TaskRow> statement,
    TaskFilter filter, {
    TaskSort? sort,
    TaskView? view,
  }) {
    var query = statement;

    // View constraints. These intersect with filter dimensions.
    switch (view ?? TaskView.all) {
      case TaskView.today:
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final tomorrowStart = todayStart.add(const Duration(days: 1));
        query.where(
          (tasks) => Expression.and([
            tasks.dueDate.isBiggerOrEqualValue(todayStart),
            tasks.dueDate.isSmallerThanValue(tomorrowStart),
          ]),
        );
        break;
      case TaskView.upcoming:
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final tomorrowStart = todayStart.add(const Duration(days: 1));
        query.where(
          (tasks) => Expression.and([
            tasks.completed.equals(false),
            tasks.dueDate.isBiggerOrEqualValue(tomorrowStart),
          ]),
        );
        break;
      case TaskView.overdue:
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        query.where(
          (tasks) => Expression.and([
            tasks.completed.equals(false),
            tasks.dueDate.isSmallerThanValue(todayStart),
          ]),
        );
        break;
      case TaskView.completed:
        query.where((tasks) => tasks.completed.equals(true));
        break;
      case TaskView.all:
      case TaskView.byGoal:
      case TaskView.byPriority:
      case TaskView.recentlyUpdated:
        break;
    }

    // Status dimension.
    switch (filter.status) {
      case TaskStatusFilter.active:
        query.where((tasks) => tasks.completed.equals(false));
        break;
      case TaskStatusFilter.completed:
        query.where((tasks) => tasks.completed.equals(true));
        break;
      case TaskStatusFilter.all:
        break;
    }

    // Time dimension. Date boundaries use the local calendar date; tasks
    // without a due date never match a time-based filter.
    switch (filter.time) {
      case TaskTimeFilter.today:
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final tomorrowStart = todayStart.add(const Duration(days: 1));
        query.where(
          (tasks) => Expression.and([
            tasks.dueDate.isBiggerOrEqualValue(todayStart),
            tasks.dueDate.isSmallerThanValue(tomorrowStart),
          ]),
        );
        break;
      case TaskTimeFilter.overdue:
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        query.where(
          (tasks) => Expression.and([
            tasks.completed.equals(false),
            tasks.dueDate.isSmallerThanValue(todayStart),
          ]),
        );
        break;
      case TaskTimeFilter.upcoming:
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final tomorrowStart = todayStart.add(const Duration(days: 1));
        query.where(
          (tasks) => Expression.and([
            tasks.completed.equals(false),
            tasks.dueDate.isBiggerOrEqualValue(tomorrowStart),
          ]),
        );
        break;
      case TaskTimeFilter.custom:
        if (filter.startDate != null) {
          query.where(
            (tasks) => tasks.dueDate.isBiggerOrEqualValue(filter.startDate!),
          );
        }
        if (filter.endDate != null) {
          final endInclusive = filter.endDate!.add(const Duration(days: 1));
          query.where(
            (tasks) => tasks.dueDate.isSmallerThanValue(endInclusive),
          );
        }
        break;
      case TaskTimeFilter.all:
        break;
    }

    // Priority dimension.
    if (filter.priority != null) {
      query.where((tasks) => tasks.priority.equals(filter.priority!));
    }

    // Goal dimension.
    if (filter.goalId != null) {
      query.where((tasks) => tasks.goalId.equals(filter.goalId!));
    }

    // Parent task dimension (direct children only).
    if (filter.parentTaskId != null) {
      query.where((tasks) => tasks.parentTaskId.equals(filter.parentTaskId!));
    }

    // Subtask dimension.
    if (filter.includeSubtasks == true) {
      query.where((tasks) => tasks.parentTaskId.isNotNull());
    } else if (filter.includeSubtasks == false) {
      query.where((tasks) => tasks.parentTaskId.isNull());
    }

    // Category dimension.
    if (filter.category != null) {
      query.where((tasks) => tasks.category.equals(filter.category!));
    }

    return _applySort(query, sort ?? const TaskSort());
  }

  /// Returns [statement] with ordering terms for [sort] applied.
  ///
  /// A deterministic tie-breaker (createdAt DESC, then id ASC) is always
  /// appended so the same dataset and sort configuration always produces the
  /// same order. Null due dates sort last in both directions.
  SimpleSelectStatement<$TasksTable, TaskRow> _applySort(
    SimpleSelectStatement<$TasksTable, TaskRow> statement,
    TaskSort sort,
  ) {
    final terms = <OrderingTerm Function($TasksTable)>[];

    switch (sort.mode) {
      case TaskSortMode.creationDate:
        terms.add(
          (t) => sort.isDescending
              ? OrderingTerm.desc(t.createdAt)
              : OrderingTerm.asc(t.createdAt),
        );
        break;
      case TaskSortMode.updatedDate:
        terms.add(
          (t) => sort.isDescending
              ? OrderingTerm.desc(t.updatedAt)
              : OrderingTerm.asc(t.updatedAt),
        );
        break;
      case TaskSortMode.dueDate:
        // Null due dates sort last in both directions. Non-null rows are
        // grouped first using isNotNull() DESC (true sorts before false),
        // then ordered by the due date itself in the requested direction.
        terms.add(
          (t) => OrderingTerm(
            expression: t.dueDate.isNotNull(),
            mode: OrderingMode.desc,
          ),
        );
        if (sort.isDescending) {
          terms.add((t) => OrderingTerm.desc(t.dueDate));
        } else {
          terms.add((t) => OrderingTerm.asc(t.dueDate));
        }
        break;
      case TaskSortMode.priority:
        terms.add(
          (t) => sort.isDescending
              ? OrderingTerm.desc(t.priority)
              : OrderingTerm.asc(t.priority),
        );
        break;
      case TaskSortMode.alphabetical:
        terms.add(
          (t) => sort.isDescending
              ? OrderingTerm.desc(t.title)
              : OrderingTerm.asc(t.title),
        );
        break;
      case TaskSortMode.completionStatus:
        terms.add(
          (t) => sort.isDescending
              ? OrderingTerm.desc(t.completed)
              : OrderingTerm.asc(t.completed),
        );
        break;
    }

    // Deterministic tie-breaker: createdAt DESC, then id ASC.
    terms.add((t) => OrderingTerm.desc(t.createdAt));
    terms.add((t) => OrderingTerm.asc(t.id));

    return statement..orderBy(terms);
  }

  SimpleSelectStatement<$TasksTable, TaskRow> _orderedTasks() {
    return _database.select(_database.tasks)..orderBy([
      (tasks) => OrderingTerm.asc(tasks.completed),
      (tasks) => OrderingTerm.desc(tasks.priority),
      (tasks) => OrderingTerm.desc(tasks.createdAt),
    ]);
  }

  /// Returns tasks that have both a due date and a due time, and are not
  /// completed. These are the tasks eligible for a countdown display.
  Future<List<TaskRow>> getTasksWithDueTimes() {
    return (_database.select(_database.tasks)..where(
          (tasks) => Expression.and([
            tasks.dueDate.isNotNull(),
            tasks.dueTime.isNotNull(),
            tasks.completed.equals(false),
          ]),
        ))
        .get();
  }

  // =========================================================================
  // Recurrence rules
  // =========================================================================

  /// Default forward generation window. Occurrences beyond this window are
  /// created by a later generation run, keeping every run bounded.
  static const int defaultGenerationHorizonDays = 90;

  /// Hard cap on rows written by a single generation run. This bounds work on
  /// first launch after a long absence; subsequent runs continue from the
  /// latest persisted occurrence.
  static const int maxOccurrencesPerGenerationRun = 1000;

  /// Safety guard for unusual calendars. [horizonDays] is the primary bound.
  static const int maxGenerationIterationsPerRun = 10000;

  /// Returns every recurrence rule, ordered deterministically.
  Future<List<TaskRecurrenceRule>> getAllRecurrenceRules() async {
    final rows =
        await (_database.select(_database.taskRecurrenceRules)..orderBy([
              (rule) => OrderingTerm.desc(rule.isActive),
              (rule) => OrderingTerm.asc(rule.createdAt),
              (rule) => OrderingTerm.asc(rule.id),
            ]))
            .get();
    return rows.map(TaskRecurrenceRule.fromRow).toList(growable: false);
  }

  /// Creates a new recurrence rule.
  Future<void> createRecurrenceRule(TaskRecurrenceRule rule) async {
    _ensureValidRecurrence(rule);
    await _database
        .into(_database.taskRecurrenceRules)
        .insert(rule.toCompanion());
  }

  /// Returns the recurrence rule with [id], or null if not found.
  Future<TaskRecurrenceRule?> getRecurrenceRule(String id) async {
    final row = await (_database.select(
      _database.taskRecurrenceRules,
    )..where((rule) => rule.id.equals(id))).getSingleOrNull();
    return row == null ? null : TaskRecurrenceRule.fromRow(row);
  }

  /// Returns all recurrence rules for [parentTaskId].
  Future<List<TaskRecurrenceRule>> getRecurrenceRulesForParent(
    String parentTaskId,
  ) async {
    final rows =
        await (_database.select(_database.taskRecurrenceRules)
              ..where((rule) => rule.parentTaskId.equals(parentTaskId))
              ..orderBy([
                (rule) => OrderingTerm.desc(rule.isActive),
                (rule) => OrderingTerm.asc(rule.createdAt),
              ]))
            .get();
    return rows.map(TaskRecurrenceRule.fromRow).toList(growable: false);
  }

  /// Returns the preferred rule for [parentTaskId].
  ///
  /// A parent has at most one rule. Active rules are preferred if legacy data
  /// contains more than one.
  Future<TaskRecurrenceRule?> getRecurrenceRuleForParent(
    String parentTaskId,
  ) async {
    final rules = await getRecurrenceRulesForParent(parentTaskId);
    return rules.firstOrNull;
  }

  /// Updates an existing recurrence rule.
  ///
  /// Existing occurrences are never deleted or regenerated by this operation.
  /// The next generation run continues after the latest persisted occurrence.
  Future<void> updateRecurrenceRule(TaskRecurrenceRule rule) async {
    _ensureValidRecurrence(rule);
    final updated = await _database
        .update(_database.taskRecurrenceRules)
        .replace(rule.toCompanion());
    if (!updated) {
      throw TaskRelationshipException(
        'Recurrence rule "${rule.id}" does not exist.',
      );
    }
  }

  /// Stops future generation while preserving every occurrence and completion
  /// state already stored for this rule.
  Future<void> stopRecurrence(String id, {DateTime? updatedAt}) async {
    final updated =
        await (_database.update(
          _database.taskRecurrenceRules,
        )..where((rule) => rule.id.equals(id))).write(
          TaskRecurrenceRulesCompanion(
            isActive: const Value(false),
            updatedAt: Value(
              (updatedAt ?? DateTime.now()).toUtc().millisecondsSinceEpoch,
            ),
          ),
        );
    if (updated == 0) {
      throw TaskRelationshipException('Recurrence rule "$id" does not exist.');
    }
  }

  /// Reactivates a stopped rule. Future generation resumes after the latest
  /// existing occurrence, so history is never recreated.
  Future<void> resumeRecurrence(String id, {DateTime? updatedAt}) async {
    final updated =
        await (_database.update(
          _database.taskRecurrenceRules,
        )..where((rule) => rule.id.equals(id))).write(
          TaskRecurrenceRulesCompanion(
            isActive: const Value(true),
            updatedAt: Value(
              (updatedAt ?? DateTime.now()).toUtc().millisecondsSinceEpoch,
            ),
          ),
        );
    if (updated == 0) {
      throw TaskRelationshipException('Recurrence rule "$id" does not exist.');
    }
  }

  /// Deletes a recurrence rule and all its occurrences.
  ///
  /// User-facing "stop recurrence" must use [stopRecurrence] instead. This
  /// method exists for explicit destructive cleanup and parent deletion.
  Future<void> deleteRecurrenceRule(String id) async {
    await _database.transaction(() async {
      await (_database.delete(
        _database.taskOccurrences,
      )..where((occurrence) => occurrence.ruleId.equals(id))).go();
      await (_database.delete(
        _database.taskRecurrenceRules,
      )..where((rule) => rule.id.equals(id))).go();
    });
  }

  /// Creates a task, its recurrence rule and the first bounded batch of
  /// occurrences atomically.
  Future<void> createTaskWithRecurrence(
    Task task,
    RecurrenceDraft draft, {
    String? goalId,
  }) async {
    _ensureValidDraft(draft);
    await _database.transaction(() async {
      if (goalId != null) {
        final goal = await (_database.select(
          _database.goals,
        )..where((goals) => goals.id.equals(goalId))).getSingleOrNull();
        if (goal == null) {
          throw TaskRelationshipException('Goal "$goalId" does not exist.');
        }
        await _database
            .into(_database.tasks)
            .insert(task.toCompanion().copyWith(goalId: Value(goalId)));
      } else {
        await _database.into(_database.tasks).insert(task.toCompanion());
      }

      final now = DateTime.now();
      final rule = draft.toRule(
        id: generateId(),
        parentTaskId: task.id,
        createdAt: now,
        updatedAt: now,
      );
      await createRecurrenceRule(rule);
      await _generateOccurrences(rule);
    });
  }

  /// Updates a task and its recurrence configuration atomically.
  ///
  /// Passing a null [draft] stops future generation when a rule already exists,
  /// preserving the rule and all history as a stopped recurrence.
  Future<TaskRecurrenceRule?> updateTaskWithRecurrence(
    Task task,
    RecurrenceDraft? draft, {
    String? existingRuleId,
  }) async {
    if (draft != null) {
      _ensureValidDraft(draft);
    }
    return _database.transaction(() async {
      await update(task);

      final existing = existingRuleId != null
          ? await getRecurrenceRule(existingRuleId)
          : await getRecurrenceRuleForParent(task.id);

      if (draft == null) {
        if (existing != null && existing.isActive) {
          await stopRecurrence(existing.id);
        }
        return existing;
      }

      final now = DateTime.now();
      final rule = existing == null
          ? draft.toRule(
              id: generateId(),
              parentTaskId: task.id,
              createdAt: now,
              updatedAt: now,
            )
          : draft.toRule(
              id: existing.id,
              parentTaskId: task.id,
              createdAt: existing.createdAt,
              updatedAt: now,
              isActive: true,
            );

      if (existing == null) {
        await createRecurrenceRule(rule);
      } else {
        await updateRecurrenceRule(rule);
      }
      await _generateOccurrences(rule);
      return rule;
    });
  }

  // =========================================================================
  // Task occurrences
  // =========================================================================

  /// Creates a new occurrence.
  Future<void> createOccurrence(TaskOccurrence occurrence) async {
    await _database
        .into(_database.taskOccurrences)
        .insert(occurrence.toCompanion());
  }

  /// Returns the occurrence with [id], or null if not found.
  Future<TaskOccurrence?> getOccurrence(String id) async {
    final row = await (_database.select(
      _database.taskOccurrences,
    )..where((occurrence) => occurrence.id.equals(id))).getSingleOrNull();
    return row == null ? null : TaskOccurrence.fromRow(row);
  }

  /// Returns occurrences for [ruleId], ordered by occurrence date.
  ///
  /// Deleted occurrences are hidden by default but remain in the database so
  /// generation cannot recreate them.
  Future<List<TaskOccurrence>> getOccurrencesForRule(
    String ruleId, {
    bool includeDeleted = false,
  }) async {
    final query = _database.select(_database.taskOccurrences)
      ..where((occurrence) => occurrence.ruleId.equals(ruleId));
    if (!includeDeleted) {
      query.where((occurrence) => occurrence.isDeleted.equals(false));
    }
    query.orderBy([
      (occurrence) => OrderingTerm.asc(occurrence.occurrenceDate),
      (occurrence) => OrderingTerm.asc(occurrence.id),
    ]);
    final rows = await query.get();
    return rows.map(TaskOccurrence.fromRow).toList(growable: false);
  }

  /// Returns all occurrences in the date range [startDate, endDate] inclusive,
  /// ordered by occurrence date.
  Future<List<TaskOccurrence>> getOccurrencesForDateRange(
    DateTime startDate,
    DateTime endDate, {
    bool includeDeleted = false,
  }) async {
    final startEpoch = recurrenceDateToEpochMs(startDate);
    final endEpoch = recurrenceDateToEpochMs(endDate);
    final query = _database.select(_database.taskOccurrences)
      ..where(
        (occurrence) => Expression.and([
          occurrence.occurrenceDate.isBiggerOrEqualValue(startEpoch),
          occurrence.occurrenceDate.isSmallerOrEqualValue(endEpoch),
        ]),
      );
    if (!includeDeleted) {
      query.where((occurrence) => occurrence.isDeleted.equals(false));
    }
    query.orderBy([
      (occurrence) => OrderingTerm.asc(occurrence.occurrenceDate),
      (occurrence) => OrderingTerm.asc(occurrence.id),
    ]);
    final rows = await query.get();
    return rows.map(TaskOccurrence.fromRow).toList(growable: false);
  }

  /// Updates an existing occurrence.
  Future<void> updateOccurrence(TaskOccurrence occurrence) async {
    final updated = await _database
        .update(_database.taskOccurrences)
        .replace(occurrence.toCompanion());
    if (!updated) {
      throw TaskRelationshipException(
        'Occurrence "${occurrence.id}" does not exist.',
      );
    }
  }

  /// Independently completes or reopens an occurrence.
  Future<void> setOccurrenceCompleted(
    String id,
    bool completed, {
    DateTime? updatedAt,
  }) async {
    final updated =
        await (_database.update(
          _database.taskOccurrences,
        )..where((occurrence) => occurrence.id.equals(id))).write(
          TaskOccurrencesCompanion(
            completed: Value(completed),
            updatedAt: Value(
              (updatedAt ?? DateTime.now()).toUtc().millisecondsSinceEpoch,
            ),
          ),
        );
    if (updated == 0) {
      throw TaskRelationshipException('Occurrence "$id" does not exist.');
    }
  }

  /// Changes the due date of one occurrence without touching its rule or any
  /// sibling occurrence.
  Future<void> rescheduleOccurrence(
    String id,
    DateTime dueDate, {
    DateTime? updatedAt,
  }) async {
    final occurrence = await getOccurrence(id);
    if (occurrence == null) {
      throw TaskRelationshipException('Occurrence "$id" does not exist.');
    }
    await updateOccurrence(
      occurrence.copyWith(
        dueDate: recurrenceDateOnly(dueDate),
        updatedAt: (updatedAt ?? DateTime.now()).toUtc(),
      ),
    );
  }

  /// Soft-deletes one occurrence. The row is retained so generation cannot
  /// recreate the deleted date.
  Future<void> deleteOccurrence(String id, {DateTime? updatedAt}) async {
    final updated =
        await (_database.update(
          _database.taskOccurrences,
        )..where((occurrence) => occurrence.id.equals(id))).write(
          TaskOccurrencesCompanion(
            isDeleted: const Value(true),
            updatedAt: Value(
              (updatedAt ?? DateTime.now()).toUtc().millisecondsSinceEpoch,
            ),
          ),
        );
    if (updated == 0) {
      throw TaskRelationshipException('Occurrence "$id" does not exist.');
    }
  }

  /// Generates occurrences for [ruleId] within the configured horizon.
  ///
  /// Generation is idempotent: existing dates (including soft-deleted ones)
  /// are never inserted again, stable IDs reinforce the unique rule/date
  /// index, and each run is bounded by
  /// [maxOccurrencesPerGenerationRun].
  Future<int> generateOccurrences(
    String ruleId, {
    int horizonDays = defaultGenerationHorizonDays,
    int maxPerRun = maxOccurrencesPerGenerationRun,
  }) {
    return _database.transaction(() async {
      final rule = await getRecurrenceRule(ruleId);
      if (rule == null || !rule.isActive) {
        return 0;
      }
      return _generateOccurrences(
        rule,
        horizonDays: horizonDays,
        maxPerRun: maxPerRun,
      );
    });
  }

  /// Generates occurrences for every active rule. Called at startup to recover
  /// dates missed while the app was not running.
  Future<int> generateAllOccurrences({
    int horizonDays = defaultGenerationHorizonDays,
  }) async {
    final rules = await getAllRecurrenceRules();
    var generated = 0;
    for (final rule in rules.where((rule) => rule.isActive)) {
      generated += await generateOccurrences(rule.id, horizonDays: horizonDays);
    }
    return generated;
  }

  Future<int> _generateOccurrences(
    TaskRecurrenceRule rule, {
    int horizonDays = defaultGenerationHorizonDays,
    int maxPerRun = maxOccurrencesPerGenerationRun,
  }) async {
    _ensureValidRecurrence(rule);

    final existingRows =
        await (_database.select(_database.taskOccurrences)
              ..where((occurrence) => occurrence.ruleId.equals(rule.id))
              ..orderBy([
                (occurrence) => OrderingTerm.asc(occurrence.occurrenceDate),
                (occurrence) => OrderingTerm.asc(occurrence.id),
              ]))
            .get();

    final existingDates = <String>{
      for (final row in existingRows)
        recurrenceDateKey(recurrenceDateFromEpochMs(row.occurrenceDate)),
    };
    var count = existingRows.length;
    final maxOccurrences = rule.maxOccurrences;
    if (maxOccurrences != null && count >= maxOccurrences) {
      return 0;
    }

    var start = recurrenceDateOnly(rule.startDate);
    if (existingRows.isNotEmpty) {
      final latest = recurrenceDateFromEpochMs(
        existingRows.last.occurrenceDate,
      );
      final afterLatest = recurrenceAddDays(latest, 1);
      if (afterLatest.isAfter(start)) {
        start = afterLatest;
      }
    }

    final today = recurrenceDateOnly(DateTime.now());
    final horizonEnd = recurrenceAddDays(today, horizonDays);
    final ruleEnd = rule.endDate == null
        ? null
        : recurrenceDateOnly(rule.endDate!);
    final end = ruleEnd == null || horizonEnd.isBefore(ruleEnd)
        ? horizonEnd
        : ruleEnd;
    if (start.isAfter(end)) {
      return 0;
    }

    final parent = rule.parentTaskId == null
        ? null
        : await getById(rule.parentTaskId!);
    final now = DateTime.now().toUtc();
    final companions = <TaskOccurrencesCompanion>[];
    var candidate = rule.firstOccurrenceOnOrAfter(start);
    var iterations = 0;

    while (!candidate.isAfter(end) &&
        companions.length < maxPerRun &&
        iterations < maxGenerationIterationsPerRun) {
      iterations++;
      final key = recurrenceDateKey(candidate);
      if (!existingDates.contains(key)) {
        if (maxOccurrences != null && count >= maxOccurrences) {
          break;
        }
        companions.add(
          TaskOccurrence(
            id: occurrenceIdFor(rule.id, candidate),
            ruleId: rule.id,
            occurrenceDate: candidate,
            dueDate: candidate,
            dueTime: parent?.dueTime,
            dueTimezone: parent?.dueTimezone,
            createdAt: now,
            updatedAt: now,
          ).toCompanion(),
        );
        existingDates.add(key);
        count++;
      }

      final next = rule.nextOccurrenceAfter(candidate);
      if (!next.isAfter(candidate)) {
        throw StateError(
          'Recurrence rule "${rule.id}" did not advance past '
          '${recurrenceDateKey(candidate)}.',
        );
      }
      candidate = next;
    }

    if (companions.isNotEmpty) {
      await _database.batch((batch) {
        for (final companion in companions) {
          batch.insert(
            _database.taskOccurrences,
            companion,
            mode: InsertMode.insertOrIgnore,
          );
        }
      });
    }
    return companions.length;
  }

  void _ensureValidRecurrence(TaskRecurrenceRule rule) {
    final errors = rule.validate();
    if (errors.isNotEmpty) {
      throw TaskRecurrenceValidationException(errors);
    }
  }

  void _ensureValidDraft(RecurrenceDraft draft) {
    final errors = draft.validate();
    if (errors.isNotEmpty) {
      throw TaskRecurrenceValidationException(errors);
    }
  }
}

class TaskRelationshipException implements Exception {
  const TaskRelationshipException(this.message);

  final String message;

  @override
  String toString() => 'TaskRelationshipException: $message';
}

class TaskRecurrenceValidationException implements Exception {
  const TaskRecurrenceValidationException(this.errors);

  final List<String> errors;

  @override
  String toString() => 'TaskRecurrenceValidationException: ${errors.join(' ')}';
}
