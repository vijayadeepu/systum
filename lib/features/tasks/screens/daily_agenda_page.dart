import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/utils/date_format.dart';
import '../../focus/providers/focus_provider.dart';
import '../models/task_recurrence.dart';
import '../providers/daily_planning_provider.dart';
import '../providers/task_provider.dart';
import '../widgets/create_task_dialog.dart';

/// Daily agenda: a projection of persisted tasks and occurrences for one day.
class DailyAgendaPage extends ConsumerWidget {
  static const route = '/agenda';

  const DailyAgendaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final agendaState = ref.watch(dailyAgendaProvider(date));
    final unresolved = ref.watch(focusSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_agendaTitle(date)),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Previous day',
            onPressed: () =>
                ref.read(selectedDateProvider.notifier).previousDay(),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            tooltip: 'Today',
            onPressed: () => ref.read(selectedDateProvider.notifier).today(),
            icon: const Icon(Icons.today_rounded),
          ),
          IconButton(
            tooltip: 'Next day',
            onPressed: () => ref.read(selectedDateProvider.notifier).nextDay(),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          IconButton(
            tooltip: 'Select date',
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null && context.mounted) {
                ref.read(selectedDateProvider.notifier).selectDate(picked);
              }
            },
            icon: const Icon(Icons.calendar_month_rounded),
          ),
          IconButton(
            tooltip: 'Calendar',
            onPressed: () => context.go(MonthCalendarPage.route),
            icon: const Icon(Icons.calendar_today_rounded),
          ),
          IconButton(
            tooltip: unresolved.hasError
                ? 'Focus unavailable'
                : unresolved.value == null
                ? 'Start focus'
                : 'Resume focus',
            onPressed: () => context.push(
              Uri(path: '/focus', queryParameters: {'taskId': ''}).toString(),
            ),
            icon: Icon(
              unresolved.hasError
                  ? Icons.error_outline_rounded
                  : unresolved.value == null
                  ? Icons.center_focus_strong_outlined
                  : Icons.play_arrow_rounded,
            ),
          ),
        ],
      ),
      body: agendaState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48),
                const SizedBox(height: AppSpacing.md),
                Text('Could not load agenda: $error'),
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(dailyAgendaProvider(date)),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (agenda) {
          if (agenda.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_outlined, size: 48),
                    SizedBox(height: AppSpacing.md),
                    Text('Nothing planned'),
                    SizedBox(height: AppSpacing.xs),
                    Text('There are no tasks for this day.'),
                  ],
                ),
              ),
            );
          }
          return _AgendaBody(agenda: agenda);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createTask(context, ref, date),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create task'),
      ),
    );
  }

  static String _agendaTitle(DateTime date) {
    final weekday = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ][date.weekday - 1];
    return '$weekday, ${formatDateOnly(date)}';
  }

  Future<void> _createTask(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
  ) async {
    final result = await showDialog<CreateTaskResult>(
      context: context,
      builder: (_) =>
          CreateTaskDialog(initialDueDate: recurrenceDateOnly(date)),
    );
    if (result == null || !context.mounted) return;
    try {
      if (result.recurrence == null) {
        await ref.read(taskProvider.notifier).addTask(result.task);
      } else {
        await ref
            .read(taskProvider.notifier)
            .createTaskWithRecurrence(result.task, result.recurrence!);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create task: $error')),
        );
      }
    }
  }
}

/// Rows for the loaded agenda.
class _AgendaBody extends ConsumerWidget {
  const _AgendaBody({required this.agenda});

  final DailyAgenda agenda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderedIds = ref
        .read(dayOrderProvider.notifier)
        .orderedIds(agenda.date);
    final orderedDue = orderedAgendaEntries(agenda, orderedIds);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        if (agenda.hasOverdue) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Text(
              'Overdue',
              style: AppTypography.body.copyWith(
                color: const Color(0xFFB3261E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ..._buildOverdueEntries(context, ref, agenda),
          const Divider(height: 1),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Text(
            'Due on ${formatDateOnly(agenda.date)}',
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        ..._buildDueEntries(context, ref, orderedDue),
      ],
    );
  }

  List<Widget> _buildOverdueEntries(
    BuildContext context,
    WidgetRef ref,
    DailyAgenda agenda,
  ) {
    return [
      for (final entry in agenda.overdue)
        _AgendaEntry(
          entry: entry,
          onToggle: (completed) => _toggle(context, ref, entry, completed),
          onEdit: entry.isOccurrence ? null : () => _openTask(context, entry),
          onStartFocus: () => _startFocus(context, entry),
          canEdit: !entry.isOccurrence,
        ),
    ];
  }

  List<Widget> _buildDueEntries(
    BuildContext context,
    WidgetRef ref,
    List<DailyAgendaEntry> entries,
  ) {
    return [
      for (final entry in entries)
        _AgendaEntry(
          entry: entry,
          onToggle: (completed) => _toggle(context, ref, entry, completed),
          onEdit: entry.isOccurrence ? null : () => _openTask(context, entry),
          onStartFocus: () => _startFocus(context, entry),
          canEdit: !entry.isOccurrence,
        ),
    ];
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    DailyAgendaEntry entry,
    bool completed,
  ) async {
    try {
      if (entry.isOccurrence) {
        await ref
            .read(taskProvider.notifier)
            .setOccurrenceCompleted(entry.id, completed);
      } else {
        await ref.read(taskProvider.notifier).setCompleted(entry.id, completed);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update task: $error')),
        );
      }
    }
  }

  void _openTask(BuildContext context, DailyAgendaEntry entry) {
    context.push('/task/${entry.id}');
  }

  void _startFocus(BuildContext context, DailyAgendaEntry entry) {
    context.push(
      Uri(path: '/focus', queryParameters: {'taskId': entry.id}).toString(),
    );
  }
}

/// One agenda row.
class _AgendaEntry extends ConsumerWidget {
  const _AgendaEntry({
    required this.entry,
    required this.onToggle,
    this.onEdit,
    required this.onStartFocus,
    required this.canEdit,
  });

  final DailyAgendaEntry entry;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onEdit;
  final VoidCallback onStartFocus;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      label:
          '${entry.title}${entry.completed ? ', completed' : ', not completed'}${entry.isOccurrence ? ', recurrence occurrence' : ''}',
      button: onEdit != null,
      child: ListTile(
        leading: Checkbox(
          value: entry.completed,
          onChanged: (value) => onToggle(value ?? false),
        ),
        title: Text(
          entry.title,
          style: entry.completed
              ? AppTypography.body.copyWith(
                  decoration: TextDecoration.lineThrough,
                  color: Colors.grey,
                )
              : AppTypography.body,
        ),
        subtitle: _buildSubtitle(),
        trailing: Wrap(
          spacing: AppSpacing.xs,
          children: [
            if (entry.hasReminder)
              const Icon(Icons.notifications_active_rounded, size: 20),
            if (onEdit != null)
              Semantics(
                label: 'Edit ${entry.title}',
                button: true,
                child: IconButton(
                  tooltip: 'Edit task',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
              ),
            Semantics(
              label: 'Start focus for ${entry.title}',
              button: true,
              child: IconButton(
                tooltip: 'Start focus',
                onPressed: onStartFocus,
                icon: const Icon(Icons.center_focus_strong_outlined, size: 20),
              ),
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }

  Widget _buildSubtitle() {
    final parts = <String>[];
    if (entry.dueTime != null) {
      parts.add(_formatDueTime(entry.dueTime!));
    }
    if (entry.isOccurrence) {
      parts.add('Recurrence occurrence');
    }
    return parts.isNotEmpty ? Text(parts.join(' • ')) : const SizedBox.shrink();
  }

  static String _formatDueTime(int secondsSinceMidnight) {
    final hours = secondsSinceMidnight ~/ 3600;
    final minutes = (secondsSinceMidnight % 3600) ~/ 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}';
  }
}

/// Lightweight monthly calendar of task dates.
class MonthCalendarPage extends ConsumerWidget {
  static const route = '/calendar';

  const MonthCalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDateProvider);
    final now = DateTime.now();
    final calendar = ref.watch(calendarProvider);
    final year = calendar.year;
    final month = calendar.month;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_monthName(month)} $year'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: () =>
                ref.read(calendarProvider.notifier).previousMonth(),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            tooltip: 'Today',
            onPressed: () {
              ref.read(calendarProvider.notifier).today();
              ref.read(selectedDateProvider.notifier).today();
            },
            icon: const Icon(Icons.today_rounded),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: () => ref.read(calendarProvider.notifier).nextMonth(),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
      body: _CalendarBody(
        selected: selected,
        now: recurrenceDateOnly(now),
        calendar: ref.watch<AsyncValue<MonthCalendar>>(
          monthCalendarProvider(MonthRange(year: year, month: month)),
        ),
        onSelect: (date) {
          ref.read(selectedDateProvider.notifier).selectDate(date);
          context.go(DailyAgendaPage.route);
        },
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[month - 1];
  }
}

/// Current calendar month held as UI state.
final calendarProvider =
    NotifierProvider<CalendarNotifier, ({int year, int month})>(
      CalendarNotifier.new,
    );

class CalendarNotifier extends Notifier<({int year, int month})> {
  @override
  ({int year, int month}) build() {
    final now = DateTime.now();
    return (year: now.year, month: now.month);
  }

  void previousMonth() {
    final year = state.month == 1 ? state.year - 1 : state.year;
    final month = state.month == 1 ? 12 : state.month - 1;
    state = (year: year, month: month);
  }

  void nextMonth() {
    final year = state.month == 12 ? state.year + 1 : state.year;
    final month = state.month == 12 ? 1 : state.month + 1;
    state = (year: year, month: month);
  }

  void today() {
    final now = DateTime.now();
    state = (year: now.year, month: now.month);
  }
}

/// Renders one month grid: weekday headers and dated cells.
class _CalendarBody extends ConsumerWidget {
  const _CalendarBody({
    required this.selected,
    required this.now,
    required this.calendar,
    required this.onSelect,
  });

  final DateTime selected;
  final DateTime now;
  final AsyncValue<MonthCalendar> calendar;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return calendar.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text('Could not load calendar: $error'),
            ],
          ),
        ),
      ),
      data: (month) => _CalendarGrid(
        calendar: month,
        selected: selected,
        now: now,
        onSelect: onSelect,
      ),
    );
  }
}

/// Renders one month grid: weekday headers and dated cells.
class _CalendarGrid extends ConsumerWidget {
  const _CalendarGrid({
    required this.calendar,
    required this.selected,
    required this.now,
    required this.onSelect,
  });

  final MonthCalendar calendar;
  final DateTime selected;
  final DateTime now;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = DateTime.utc(calendar.year, calendar.month, 1);
    final last = DateTime.utc(calendar.year, calendar.month + 1, 0);
    final startOffset = first.weekday % 7; // Monday=0 .. Sunday=6

    return Column(
      children: [
        // Weekday headers.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              for (var day = 0; day < 7; day++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day],
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Days.
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.1,
            ),
            itemCount: startOffset + last.day,
            itemBuilder: (context, index) {
              if (index < startOffset) {
                return const SizedBox.shrink();
              }
              final day = index - startOffset + 1;
              final cellDate = DateTime.utc(calendar.year, calendar.month, day);
              final isToday = _sameCalendarDate(cellDate, now);
              final isSelected = _sameCalendarDate(cellDate, selected);
              final hasTasks = calendar.hasTasksOn(cellDate);

              return Semantics(
                label:
                    '$day${calendar.hasTasksOn(cellDate) ? ', has tasks' : ''}${isToday ? ', today' : ''}${isSelected ? ', selected' : ''}',
                button: true,
                child: Material(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Colors.transparent,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  child: InkWell(
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    onTap: () => onSelect(cellDate),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          day.toString(),
                          style: AppTypography.body.copyWith(
                            color: isToday
                                ? Theme.of(context).colorScheme.primary
                                : null,
                            fontWeight: isToday || isSelected
                                ? FontWeight.w600
                                : null,
                          ),
                        ),
                        if (hasTasks)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFFB3261E),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  bool _sameCalendarDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
