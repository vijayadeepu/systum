import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../activities/models/activity.dart';
import '../../activities/providers/activity_provider.dart';
import '../../activities/widgets/activity_form_dialog.dart';
import '../../tasks/providers/task_provider.dart';
import '../models/reminder.dart';
import '../providers/reminder_provider.dart';

class RemindersPage extends ConsumerWidget {
  const RemindersPage({super.key});

  static const route = '/reminders';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(remindersProvider);
    final activities = ref.watch(activitiesProvider);
    final tasks = ref.watch(taskProvider).value ?? const [];
    final titles = {for (final task in tasks) task.id: task.title};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        actions: [
          IconButton(
            tooltip: 'Refresh reminders',
            onPressed: () => ref.invalidate(remindersProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final activity = await showActivityFormDialog(context);
          if (activity != null && context.mounted) {
            await ref.read(activityActionsProvider).create(activity);
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Activity'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _SectionTitle(title: 'Activities', action: 'Due'),
          activities.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Could not load activities: $error'),
            data: (items) => items.isEmpty
                ? const Text('No activities yet. Add one to track recurring attention.')
                : Column(
                    children: [for (final activity in items) _ActivityTile(activity: activity, ref: ref)],
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionTitle(title: 'One-time reminders'),
          reminders.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Could not load reminders: $error'),
            data: (items) => items.isEmpty
                ? const Text('No task reminders yet. Add reminders from a task.')
                : Column(
                    children: [
                      for (final reminder in items)
                        _ReminderTile(reminder: reminder, taskTitle: titles[reminder.taskId] ?? 'Task unavailable'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action});
  final String title;
  final String? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: Theme.of(context).textTheme.titleMedium), if (action != null) Text(action!, style: Theme.of(context).textTheme.labelMedium)]),
  );
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.activity, required this.ref});
  final Activity activity;
  final WidgetRef ref;
  @override
  Widget build(BuildContext context) {
    final due = activity.nextDue;
    final overdue = activity.status == ActivityStatus.active && due.isBefore(DateTime.now());
    return Card(
      child: ListTile(
        leading: Icon(activity.status == ActivityStatus.active ? Icons.sync_rounded : Icons.pause_circle_outline),
        title: Text('${activity.targetName} · ${activity.name}'),
        subtitle: Text('${activity.description ?? 'Recurring activity'}\n${overdue ? 'Overdue' : 'Due ${due.toLocal()}'}'),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'complete') await ref.read(activityActionsProvider).complete(activity.id);
            if (value == 'pause') await ref.read(activityActionsProvider).setStatus(activity.id, ActivityStatus.paused);
            if (value == 'resume') await ref.read(activityActionsProvider).setStatus(activity.id, ActivityStatus.active);
            if (value == 'archive') await ref.read(activityActionsProvider).setStatus(activity.id, ActivityStatus.archived);
            if (value == 'edit' && context.mounted) {
              final edited = await showActivityFormDialog(context, activity: activity);
              if (edited != null) await ref.read(activityActionsProvider).update(edited);
            }
          },
          itemBuilder: (_) => [
            if (activity.status == ActivityStatus.active) const PopupMenuItem(value: 'complete', child: Text('Complete')),
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            if (activity.status == ActivityStatus.active) const PopupMenuItem(value: 'pause', child: Text('Pause')),
            if (activity.status == ActivityStatus.paused) const PopupMenuItem(value: 'resume', child: Text('Resume')),
            if (activity.status != ActivityStatus.archived) const PopupMenuItem(value: 'archive', child: Text('Archive')),
          ],
        ),
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.reminder, required this.taskTitle});

  final Reminder reminder;
  final String taskTitle;

  @override
  Widget build(BuildContext context) {
    final schedule = reminder.isRecurring
        ? '${_label(reminder.scheduleType)}${reminder.localHour == null ? '' : ' at ${_time(reminder.localHour!, reminder.localMinute!)}'}'
        : reminder.scheduledAtUtc == null
        ? 'One-time reminder'
        : 'At ${reminder.scheduledAtUtc!.toLocal()}' ;
    return Card(
      child: ListTile(
        leading: Icon(
          reminder.isScheduled
              ? Icons.notifications_active_outlined
              : Icons.notifications_off_outlined,
        ),
        title: Text(taskTitle),
        subtitle: Text(schedule),
        trailing: Text(
          reminder.isScheduled ? 'Scheduled' : 'Cancelled',
          style: TextStyle(
            color: reminder.isScheduled
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  String _label(ReminderScheduleType type) => switch (type) {
    ReminderScheduleType.daily => 'Daily',
    ReminderScheduleType.weekly => 'Weekly',
    ReminderScheduleType.monthly => 'Monthly',
    ReminderScheduleType.custom => 'Custom',
    ReminderScheduleType.once => 'One-time',
  };

  String _time(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
