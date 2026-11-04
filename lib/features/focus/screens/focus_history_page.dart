import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../models/focus_session.dart';
import '../models/focus_session_mode.dart';
import '../models/focus_session_status.dart';
import '../models/focus_time_aggregation.dart';
import '../providers/focus_clock_provider.dart';
import '../providers/focus_provider.dart';
import '../../tasks/providers/task_provider.dart';

class FocusHistoryPage extends ConsumerStatefulWidget {
  const FocusHistoryPage({super.key, this.sessionId});

  final String? sessionId;

  @override
  ConsumerState<FocusHistoryPage> createState() => _FocusHistoryPageState();
}

class _FocusHistoryPageState extends ConsumerState<FocusHistoryPage> {
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    // Use the same injectable clock as the rest of the Focus subsystem so the
    // initial day is deterministic in tests and remains local-calendar based.
    final now = ref.read(focusSystemClockProvider)();
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(focusHistoryProvider);
    final tasks = ref.watch(taskProvider).value ?? const [];
    final taskIds = tasks.map((task) => task.id).toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus history'),
        actions: [
          IconButton(
            tooltip: 'Refresh history',
            onPressed: () => ref.invalidate(focusHistoryProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(focusHistoryProvider),
        ),
        data: (records) {
          if (widget.sessionId case final id?) {
            final record = records.cast<FocusSessionTransition?>().firstWhere(
              (entry) => entry?.session.id == id,
              orElse: () => null,
            );
            if (record == null) return const _MissingSessionState();
            return _SessionDetails(
              record: record,
              taskStillExists:
                  record.session.taskId != null &&
                  taskIds.contains(record.session.taskId),
            );
          }
          return _HistoryContent(
            records: records,
            selectedDay: _selectedDay,
            onDayChanged: (day) => setState(() => _selectedDay = day),
            taskIds: taskIds,
            onOpen: (record) => _openDetails(context, record.session.id),
          );
        },
      ),
    );
  }

  void _openDetails(BuildContext context, String id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => FocusHistoryPage(sessionId: id)),
    );
  }
}

class _HistoryContent extends StatelessWidget {
  const _HistoryContent({
    required this.records,
    required this.selectedDay,
    required this.onDayChanged,
    required this.taskIds,
    required this.onOpen,
  });

  final List<FocusSessionTransition> records;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDayChanged;
  final Set<String> taskIds;
  final ValueChanged<FocusSessionTransition> onOpen;

  @override
  Widget build(BuildContext context) {
    final aggregation = FocusTimeAggregation.fromHistory(records);
    final dayTotal = aggregation.dailyFocusMilliseconds[selectedDay] ?? 0;
    final completed = aggregation.dailyCompletedFocusSessions[selectedDay] ?? 0;
    final interrupted =
        aggregation.dailyInterruptedFocusSessions[selectedDay] ?? 0;
    final dayRecords = records.where((record) {
      final local = DateTime.fromMillisecondsSinceEpoch(
        record.session.startedAtMs,
        isUtc: true,
      ).toLocal();
      return local.year == selectedDay.year &&
          local.month == selectedDay.month &&
          local.day == selectedDay.day;
    }).toList();

    if (records.isEmpty) {
      return const _EmptyState();
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _DayPicker(day: selectedDay, onChanged: onDayChanged),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.sm,
              children: [
                _Metric(label: 'Focused', value: _duration(dayTotal)),
                _Metric(label: 'Completed', value: '$completed'),
                _Metric(label: 'Interrupted', value: '$interrupted'),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('Sessions', style: Theme.of(context).textTheme.titleLarge),
        if (dayRecords.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(child: Text('No sessions on this day.')),
          )
        else
          for (final record in dayRecords)
            _HistoryTile(
              record: record,
              taskStillExists:
                  record.session.taskId != null &&
                  taskIds.contains(record.session.taskId),
              onTap: () => onOpen(record),
            ),
        const SizedBox(height: AppSpacing.md),
        Text('Task time', style: Theme.of(context).textTheme.titleLarge),
        _TaskTotals(
          records: records,
          aggregation: aggregation,
          taskIds: taskIds,
        ),
      ],
    );
  }
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({required this.day, required this.onChanged});
  final DateTime day;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Previous day',
        onPressed: () => onChanged(day.subtract(const Duration(days: 1))),
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      Expanded(
        child: Text(
          _date(day),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      IconButton(
        tooltip: 'Next day',
        onPressed: () => onChanged(day.add(const Duration(days: 1))),
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ],
  );
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.record,
    required this.taskStillExists,
    required this.onTap,
  });
  final FocusSessionTransition record;
  final bool taskStillExists;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final session = record.session;
    final task = session.taskTitleSnapshot ?? 'Standalone';
    final deleted = session.taskIdSnapshot != null && !taskStillExists;
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(task + (deleted ? ' (deleted task)' : '')),
        subtitle: Text(
          '${_mode(session.mode)} · ${_status(session.status)}\n'
          '${_time(session.startedAtMs)}${session.endedAtMs == null ? '' : ' – ${_time(session.endedAtMs!)}'} · ${_duration(session.actualDurationMs ?? 0)}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _TaskTotals extends StatelessWidget {
  const _TaskTotals({
    required this.records,
    required this.aggregation,
    required this.taskIds,
  });
  final List<FocusSessionTransition> records;
  final FocusTimeAggregation aggregation;
  final Set<String> taskIds;

  @override
  Widget build(BuildContext context) {
    final names = <String, String>{
      for (final record in records)
        for (final id in [record.session.taskIdSnapshot].whereType<String>())
          id: record.session.taskTitleSnapshot ?? 'Deleted task',
    };
    final entries = aggregation.taskFocusMilliseconds.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return const Text('No task-linked focus time yet.');
    return Column(
      children: [
        for (final entry in entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${names[entry.key] ?? 'Deleted task'}${taskIds.contains(entry.key) ? '' : ' (deleted task)'}',
            ),
            trailing: Text(_duration(entry.value)),
          ),
      ],
    );
  }
}

class _SessionDetails extends StatelessWidget {
  const _SessionDetails({required this.record, required this.taskStillExists});
  final FocusSessionTransition record;
  final bool taskStillExists;

  @override
  Widget build(BuildContext context) {
    final session = record.session;
    final task = session.taskTitleSnapshot ?? 'Standalone';
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(
          task +
              (session.taskIdSnapshot != null && !taskStillExists
                  ? ' (deleted task)'
                  : ''),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        _Detail(label: 'Mode', value: _mode(session.mode)),
        _Detail(label: 'Status', value: _status(session.status)),
        _Detail(
          label: 'Planned duration',
          value: session.plannedDurationMs == null
              ? 'Untimed'
              : _duration(session.plannedDurationMs!),
        ),
        _Detail(
          label: 'Actual duration',
          value: _duration(session.actualDurationMs ?? 0),
        ),
        _Detail(label: 'Started', value: _timestamp(session.startedAtMs)),
        if (session.endedAtMs case final end?)
          _Detail(label: 'Ended', value: _timestamp(end)),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Recorded intervals',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        for (final interval in record.intervals)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_timestamp(interval.startedAtMs)),
            subtitle: Text(
              interval.endedAtMs == null
                  ? 'Still running'
                  : 'Ended ${_timestamp(interval.endedAtMs!)}',
            ),
          ),
      ],
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Text('$label: $value'),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      Text(value, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Text(
        'No focus sessions yet. Start a session to build your history.',
      ),
    ),
  );
}

class _MissingSessionState extends StatelessWidget {
  const _MissingSessionState();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('This session is no longer available.'));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48),
          const SizedBox(height: AppSpacing.sm),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

String _duration(int milliseconds) {
  final totalMinutes = milliseconds ~/ Duration.millisecondsPerMinute;
  final seconds =
      (milliseconds % Duration.millisecondsPerMinute) ~/
      Duration.millisecondsPerSecond;
  if (totalMinutes == 0) return '${seconds}s';
  return '${totalMinutes}m ${seconds.toString().padLeft(2, '0')}s';
}

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String _time(int ms) {
  final date = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String _timestamp(int ms) {
  final date = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  return '${_date(date)} ${_time(ms)}';
}

String _mode(FocusSessionMode mode) => switch (mode) {
  FocusSessionMode.standard => 'Focus',
  FocusSessionMode.pomodoro => 'Pomodoro focus',
  FocusSessionMode.shortBreak => 'Short break',
  FocusSessionMode.longBreak => 'Long break',
  FocusSessionMode.custom => 'Custom focus',
};
String _status(FocusSessionStatus status) => switch (status) {
  FocusSessionStatus.running => 'Running',
  FocusSessionStatus.paused => 'Paused',
  FocusSessionStatus.completed => 'Completed',
  FocusSessionStatus.interrupted => 'Interrupted',
  FocusSessionStatus.cancelled => 'Cancelled',
};
