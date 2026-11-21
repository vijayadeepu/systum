import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/utils/id_generator.dart';
import '../../tasks/models/task_recurrence.dart';
import '../models/activity.dart';

Future<Activity?> showActivityFormDialog(BuildContext context, {Activity? activity}) {
  return showDialog<Activity>(
    context: context,
    builder: (_) => _ActivityFormDialog(activity: activity),
  );
}

class _ActivityFormDialog extends StatefulWidget {
  const _ActivityFormDialog({this.activity});
  final Activity? activity;
  @override
  State<_ActivityFormDialog> createState() => _ActivityFormDialogState();
}

class _ActivityFormDialogState extends State<_ActivityFormDialog> {
  late final TextEditingController _name, _target, _description, _account, _interval;
  late ActivityTargetType _targetType;
  late ActivityCadence _cadence;
  late DateTime _startDate;
  late int? _time;

  @override
  void initState() {
    super.initState();
    final a = widget.activity;
    _name = TextEditingController(text: a?.name ?? '');
    _target = TextEditingController(text: a?.targetName ?? '');
    _description = TextEditingController(text: a?.description ?? '');
    _account = TextEditingController(text: a?.accountIdentifier ?? '');
    _interval = TextEditingController(text: (a?.interval ?? 1).toString());
    _targetType = a?.targetType ?? ActivityTargetType.service;
    _cadence = a?.cadence ?? ActivityCadence.daily;
    _startDate = a?.startDate ?? DateTime.now();
    _time = a?.localTimeSeconds;
  }

  @override
  void dispose() {
    _name.dispose(); _target.dispose(); _description.dispose(); _account.dispose(); _interval.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (date != null) setState(() => _startDate = date);
  }

  Future<void> _pickTime() async {
    final value = await showTimePicker(context: context, initialTime: TimeOfDay(hour: (_time ?? 9 * 3600) ~/ 3600, minute: ((_time ?? 9 * 3600) % 3600) ~/ 60));
    if (value != null) setState(() => _time = value.hour * 3600 + value.minute * 60);
  }

  void _save() {
    final now = DateTime.now().toUtc();
    final activity = widget.activity;
    final value = Activity(
      id: activity?.id ?? generateId(), name: _name.text.trim(), targetName: _target.text.trim(),
      description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      accountIdentifier: _account.text.trim().isEmpty ? null : _account.text.trim(),
      targetType: _targetType, cadence: _cadence, interval: int.tryParse(_interval.text) ?? 1,
      startDate: recurrenceDateOnly(_startDate), localTimeSeconds: _time,
      timezoneId: _time == null ? null : DateTime.now().timeZoneName,
      lastCompletedAt: activity?.lastCompletedAt, status: activity?.status ?? ActivityStatus.active,
      notificationEnabled: activity?.notificationEnabled ?? false,
      createdAt: activity?.createdAt ?? now, updatedAt: now,
    );
    final errors = value.validate();
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errors.join(' '))));
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.activity == null ? 'New activity' : 'Edit activity'),
    content: SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Activity')),
        TextField(controller: _target, decoration: const InputDecoration(labelText: 'Target name')),
        DropdownButtonFormField<ActivityTargetType>(
          initialValue: _targetType, decoration: const InputDecoration(labelText: 'Target type'),
          items: [for (final type in ActivityTargetType.values) DropdownMenuItem(value: type, child: Text(type.name))],
          onChanged: (value) => setState(() => _targetType = value!),
        ),
        TextField(controller: _account, decoration: const InputDecoration(labelText: 'Account (optional)')),
        TextField(controller: _description, decoration: const InputDecoration(labelText: 'Action / description')),
        DropdownButtonFormField<ActivityCadence>(
          initialValue: _cadence, decoration: const InputDecoration(labelText: 'Cadence'),
          items: const [
            DropdownMenuItem(value: ActivityCadence.daily, child: Text('Daily')),
            DropdownMenuItem(value: ActivityCadence.everyNDays, child: Text('Every N days')),
            DropdownMenuItem(value: ActivityCadence.weekly, child: Text('Weekly')),
            DropdownMenuItem(value: ActivityCadence.weekdays, child: Text('Selected weekdays')),
          ],
          onChanged: (value) => setState(() => _cadence = value!),
        ),
        if (_cadence == ActivityCadence.everyNDays || _cadence == ActivityCadence.weekly)
          TextField(controller: _interval, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Every N')),
        const SizedBox(height: AppSpacing.sm),
        ListTile(contentPadding: EdgeInsets.zero, title: Text('Starts ${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}'), trailing: const Icon(Icons.calendar_today), onTap: _pickDate),
        ListTile(contentPadding: EdgeInsets.zero, title: Text(_time == null ? 'Notification time (optional)' : 'Time ${(_time! ~/ 3600).toString().padLeft(2, '0')}:${((_time! % 3600) ~/ 60).toString().padLeft(2, '0')}'), trailing: const Icon(Icons.schedule), onTap: _pickTime),
      ]),
    ),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: _save, child: const Text('Save'))],
  );
}
