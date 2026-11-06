import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../focus/models/focus_time_aggregation.dart';
import '../../focus/providers/focus_provider.dart';
import '../../reminders/models/reminder.dart';
import '../../reminders/providers/reminder_provider.dart';
import '../models/task_filter.dart';
import '../models/task_recurrence.dart';
import '../models/task_sort.dart';
import '../providers/task_provider.dart';
import '../repository/task_repository.dart';

/// One entry shown on the daily agenda.
///
/// Entries are a read-only projection of persisted tasks and task
/// occurrences; neither is created or mutated here.
class DailyAgendaEntry {
  const DailyAgendaEntry({
    required this.id,
    required this.title,
    required this.dueDate,
    this.dueTime,
    required this.completed,
    required this.isOccurrence,
    this.parentTaskId,
    this.ruleId,
    required this.hasReminder,
  });

  /// Stable identity of the entry. For tasks this is the task id; for
  /// occurrences it is the occurrence id.
  final String id;

  /// Display title (for occurrences, the parent task's title).
  final String title;

  /// Calendar date the entry is due on (date-only semantics).
  final DateTime dueDate;

  /// Seconds since midnight in the entry's timezone, or null for date-only.
  final int? dueTime;

  final bool completed;

  /// True when the entry is a generated occurrence rather than a task.
  final bool isOccurrence;

  /// Parent task id when [isOccurrence] is true.
  final String? parentTaskId;

  /// Recurrence rule id when [isOccurrence] is true.
  final String? ruleId;

  /// Whether a scheduled reminder exists for the entry's task.
  final bool hasReminder;

  /// Stable date key used for grouping and calendar indicators.
  String get dateKey => recurrenceDateKey(dueDate);

  /// Whether the entry is due on [date] (same calendar date).
  bool isDueOn(DateTime date) =>
      recurrenceDateOnly(dueDate).isAtSameMomentAs(recurrenceDateOnly(date));
}

/// A day's agenda: a projection of persisted data for [date].
class DailyAgenda {
  const DailyAgenda({
    required this.date,
    required this.overdue,
    required this.due,
  });

  final DateTime date;

  /// Tasks due before [date] that are not completed.
  final List<DailyAgendaEntry> overdue;

  /// Tasks due on [date], including completed ones.
  final List<DailyAgendaEntry> due;

  bool get hasOverdue => overdue.isNotEmpty;
  bool get hasDue => due.isNotEmpty;
  bool get isEmpty => overdue.isEmpty && due.isEmpty;
}

/// Factual metrics for one day, derived entirely from persisted data.
class DailySummary {
  const DailySummary({
    required this.date,
    required this.completedTasks,
    required this.incompleteTasks,
    required this.overdueTasks,
    required this.focusSessions,
    required this.focusedTimeMilliseconds,
    required this.tasksWorkedOn,
  });

  final DateTime date;

  /// Tasks (and occurrences) due on [date] that are completed.
  final int completedTasks;

  /// Tasks (and occurrences) due on [date] that are not completed.
  final int incompleteTasks;

  /// Tasks due before [date] that are not completed.
  final int overdueTasks;

  /// Completed focus sessions whose calendar day is [date].
  final int focusSessions;

  /// Active interval milliseconds whose calendar day is [date].
  final int focusedTimeMilliseconds;

  /// Distinct task ids with focus time on [date].
  final List<String> tasksWorkedOn;
}

/// Which dates of a month contain relevant tasks.
class MonthCalendar {
  const MonthCalendar({
    required this.year,
    required this.month,
    required this.daysWithTasks,
  });

  final int year;
  final int month;

  /// Date keys (`yyyy-mm-dd`) within the month that have at least one task
  /// or occurrence due on them.
  final Set<String> daysWithTasks;

  bool hasTasksOn(DateTime date) =>
      daysWithTasks.contains(recurrenceDateKey(date));
}

/// The currently selected agenda date (local calendar date).
///
/// The agenda never persists the selection; it is UI state held in Riverpod.
final selectedDateProvider = NotifierProvider<SelectedDateNotifier, DateTime>(
  SelectedDateNotifier.new,
);

class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void selectDate(DateTime date) => state = recurrenceDateOnly(date);

  void previousDay() => state = recurrenceAddDays(state, -1);

  void nextDay() => state = recurrenceAddDays(state, 1);

  void today() => state = DateTime.now();
}

/// Projects persisted tasks and occurrences into the daily agenda for a date.
///
/// Queries are bounded to the selected date plus a 90-day lookback for
/// overdue occurrences; the full task list is reused from [taskProvider]
/// rather than re-querying history.
final dailyAgendaProvider = FutureProvider.family<DailyAgenda, DateTime>((
  ref,
  date,
) async {
  final repository = ref.watch(taskRepositoryProvider);
  final tasks = await ref.watch(taskProvider.future);
  final reminders = await ref.watch(remindersProvider.future);
  final rules = await repository.getAllRecurrenceRules();
  final rulesById = {for (final rule in rules) rule.id: rule};

  final start = recurrenceDateOnly(date);
  final end = recurrenceAddDays(start, 1);
  final overdueStart = recurrenceAddDays(
    start,
    -TaskRepository.defaultGenerationHorizonDays,
  );

  final reminderTaskIds = <String>{
    for (final reminder in reminders)
      if (reminder.status == ReminderStatus.scheduled) reminder.taskId,
  };

  final parentTitleById = <String, String>{};
  for (final task in tasks) {
    parentTitleById[task.id] = task.title;
  }

  final overdue = <DailyAgendaEntry>[];
  final due = <DailyAgendaEntry>[];

  void addTaskEntry(TaskRow task) {
    final dueDate = recurrenceDateOnly(task.dueDate!);
    final hasReminder = reminderTaskIds.contains(task.id);
    if (dueDate.isBefore(start)) {
      if (!task.completed) {
        overdue.add(
          DailyAgendaEntry(
            id: task.id,
            title: task.title,
            dueDate: dueDate,
            dueTime: task.dueTime,
            completed: task.completed,
            isOccurrence: false,
            hasReminder: hasReminder,
          ),
        );
      }
    } else if (dueDate.isBefore(end)) {
      due.add(
        DailyAgendaEntry(
          id: task.id,
          title: task.title,
          dueDate: dueDate,
          dueTime: task.dueTime,
          completed: task.completed,
          isOccurrence: false,
          hasReminder: hasReminder,
        ),
      );
    }
  }

  for (final task in tasks) {
    if (task.dueDate != null) addTaskEntry(task);
  }

  final occurrences = await repository.getOccurrencesForDateRange(
    overdueStart,
    end,
  );
  for (final occurrence in occurrences) {
    if (occurrence.isDeleted) continue;
    final occurrenceDate = recurrenceDateOnly(occurrence.occurrenceDate);
    final rule = rulesById[occurrence.ruleId ?? ''];
    final parentTaskId = rule?.parentTaskId;
    final title = parentTaskId == null
        ? occurrence.id
        : (parentTitleById[parentTaskId] ?? occurrence.id);
    final hasReminder = parentTaskId == null
        ? false
        : reminderTaskIds.contains(parentTaskId);
    final entry = DailyAgendaEntry(
      id: occurrence.id,
      title: title,
      dueDate: occurrence.dueDate != null
          ? recurrenceDateOnly(occurrence.dueDate!)
          : occurrenceDate,
      dueTime: occurrence.dueTime,
      completed: occurrence.completed,
      isOccurrence: true,
      parentTaskId: parentTaskId,
      ruleId: occurrence.ruleId,
      hasReminder: hasReminder,
    );
    if (occurrenceDate.isBefore(start) && !occurrence.completed) {
      overdue.add(entry);
    } else if (occurrenceDate.isBefore(end)) {
      due.add(entry);
    }
  }

  overdue.sort(_compareEntries);
  due.sort(_compareEntries);

  return DailyAgenda(date: start, overdue: overdue, due: due);
});

int _compareEntries(DailyAgendaEntry a, DailyAgendaEntry b) {
  if (a.dueTime == null && b.dueTime == null) {
    return a.title.compareTo(b.title);
  }
  if (a.dueTime == null) return 1;
  if (b.dueTime == null) return 1;
  final timeCompare = a.dueTime!.compareTo(b.dueTime!);
  if (timeCompare != 0) return timeCompare;
  return a.title.compareTo(b.title);
}

/// Transient within-session ordering of agenda entries for a day.
///
/// The task model has no persisted per-user position column, so reordering
/// lives only in this notifier for the current session. Task identity and
/// recurrence rules are never touched by reordering.
final dayOrderProvider =
    NotifierProvider<DayOrderNotifier, Map<String, List<String>>>(
      DayOrderNotifier.new,
    );

class DayOrderNotifier extends Notifier<Map<String, List<String>>> {
  @override
  Map<String, List<String>> build() => {};

  /// Ordered entry ids for [date], or null when no order has been set.
  List<String>? orderedIds(DateTime date) => state[recurrenceDateKey(date)];

  /// Replaces the order for [date].
  void setOrder(DateTime date, List<String> orderedIds) {
    state = {
      ...state,
      recurrenceDateKey(date): List<String>.unmodifiable(orderedIds),
    };
  }

  /// Moves the entry at [oldIndex] to [newIndex] within [date].
  void move(DateTime date, int oldIndex, int newIndex) {
    final key = recurrenceDateKey(date);
    final current = List<String>.from(state[key] ?? const []);
    if (oldIndex < 0 || oldIndex >= current.length) return;
    newIndex = newIndex.clamp(0, current.length - 1);
    final moved = current.removeAt(oldIndex);
    current.insert(newIndex, moved);
    state = {...state, key: List<String>.unmodifiable(current)};
  }

  /// Appends [entryId] to the order for [date] when it is not already present.
  void noteEntry(DateTime date, String entryId) {
    final key = recurrenceDateKey(date);
    final current = List<String>.from(state[key] ?? const []);
    if (current.contains(entryId)) return;
    current.add(entryId);
    state = {...state, key: List<String>.unmodifiable(current)};
  }
}

/// Returns agenda entries for [date] in display order, applying any transient
/// day order and falling back to the planner's default comparison.
List<DailyAgendaEntry> orderedAgendaEntries(
  DailyAgenda agenda,
  List<String>? orderedIds,
) {
  final due = List<DailyAgendaEntry>.from(agenda.due);
  if (orderedIds != null && orderedIds.isNotEmpty) {
    final position = <String, int>{};
    for (var index = 0; index < orderedIds.length; index++) {
      position[orderedIds[index]] = index;
    }
    due.sort((a, b) {
      final aPos = position[a.id];
      final bPos = position[b.id];
      if (aPos == null && bPos == null) return _compareEntries(a, b);
      if (aPos == null) return 1;
      if (bPos == null) return -1;
      return aPos.compareTo(bPos);
    });
  } else {
    due.sort(_compareEntries);
  }
  return due;
}

/// Factual daily summary derived from persisted tasks, occurrences and focus
/// history. No scores, recommendations, or speculative analytics are added.
final dailySummaryProvider = FutureProvider.family<DailySummary, DateTime>((
  ref,
  date,
) async {
  final agenda = await ref.watch(dailyAgendaProvider(date).future);
  final history = await ref.watch(focusHistoryProvider.future);
  final aggregation = FocusTimeAggregation.fromHistory(history);

  final target = recurrenceDateOnly(date);
  var focusSessions = 0;
  var focusedTime = 0;
  final tasksWorkedOn = <String>{};

  for (final entry in aggregation.dailyCompletedFocusSessions.entries) {
    if (_sameCalendarDate(entry.key, target)) {
      focusSessions += entry.value;
    }
  }
  focusedTime = aggregation.dailyFocusMilliseconds.entries.fold(
    0,
    (total, entry) =>
        _sameCalendarDate(entry.key, target) ? total + entry.value : total,
  );
  for (final entry in aggregation.dailyTaskFocusMilliseconds.entries) {
    if (_sameCalendarDate(entry.key.day, target)) {
      tasksWorkedOn.add(entry.key.taskId);
    }
  }

  final completedTasks = agenda.due.where((entry) => entry.completed).length;
  final incompleteTasks = agenda.due.length - completedTasks;

  return DailySummary(
    date: target,
    completedTasks: completedTasks,
    incompleteTasks: incompleteTasks,
    overdueTasks: agenda.overdue.length,
    focusSessions: focusSessions,
    focusedTimeMilliseconds: focusedTime,
    tasksWorkedOn: tasksWorkedOn.toList(growable: false)..sort(),
  );
});

bool _sameCalendarDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Calendar month range used as the calendar query parameter.
class MonthRange {
  const MonthRange({required this.year, required this.month});

  final int year;
  final int month;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthRange && year == other.year && month == other.month;

  @override
  int get hashCode => Object.hash(year, month);
}

/// Calendar month projection: which dates contain tasks due on them.
final monthCalendarProvider = FutureProvider.family<MonthCalendar, MonthRange>((
  ref,
  range,
) async {
  final repository = ref.watch(taskRepositoryProvider);
  final first = DateTime.utc(range.year, range.month, 1);
  final last = DateTime.utc(range.year, range.month + 1, 0);

  final tasks = await repository
      .filterTasks(const TaskFilter(), view: TaskView.all)
      .then(
        (tasks) => tasks
            .where((task) {
              if (task.dueDate == null) return false;
              final due = recurrenceDateOnly(task.dueDate!);
              return !due.isBefore(first) && !due.isAfter(last);
            })
            .toList(growable: false),
      );

  final occurrences = await repository.getOccurrencesForDateRange(first, last);

  final daysWithTasks = <String>{};
  for (final task in tasks) {
    if (task.dueDate != null) {
      daysWithTasks.add(recurrenceDateKey(recurrenceDateOnly(task.dueDate!)));
    }
  }
  for (final occurrence in occurrences) {
    if (!occurrence.isDeleted) {
      daysWithTasks.add(recurrenceDateKey(occurrence.occurrenceDate));
    }
  }

  return MonthCalendar(
    year: range.year,
    month: range.month,
    daysWithTasks: daysWithTasks,
  );
});
