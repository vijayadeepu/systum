import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/utils/date_format.dart';
import '../../../shared/utils/id_generator.dart';
import '../models/task.dart';
import '../models/task_recurrence.dart';

/// Result of the task create/edit dialog.
class CreateTaskResult {
  const CreateTaskResult({required this.task, this.recurrence});

  final Task task;

  /// Null when recurrence is disabled. Editing an existing recurring task and
  /// disabling this field stops the rule without deleting history.
  final RecurrenceDraft? recurrence;
}

class CreateTaskDialog extends StatefulWidget {
  const CreateTaskDialog({
    super.key,
    this.task,
    this.parentTitle,
    this.existingRecurrence,
    this.initialDueDate,
    this.initialTitle,
  });

  final Task? task;

  /// When provided, the dialog creates a subtask for the named parent.
  final String? parentTitle;

  /// Existing rule shown when editing a recurring task.
  final TaskRecurrenceRule? existingRecurrence;

  /// Due date pre-filled for a new task, for example the selected agenda day.
  final DateTime? initialDueDate;

  /// Title pre-filled for a new task, for example content shared from Android.
  final String? initialTitle;

  @override
  State<CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<CreateTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  late final TextEditingController _intervalController;
  late final TextEditingController _maxOccurrencesController;
  late DateTime? _dueDate;
  late int _priority;
  late bool _repeats;
  late RecurrenceType _recurrenceType;
  late DateTime _recurrenceStart;
  late int _weekdayMask;
  DateTime? _recurrenceEnd;
  String? _recurrenceError;
  bool _isSubmitting = false;

  bool get _isEditing => widget.task != null;

  bool get _isSubtask => !_isEditing && widget.parentTitle != null;

  bool get _canRepeat => !_isSubtask;

  String get _dialogTitle {
    if (_isEditing) {
      return 'Edit Task';
    }
    return _isSubtask ? 'Add Subtask' : 'Create Task';
  }

  String get _submitLabel {
    if (_isEditing) {
      return 'Save';
    }
    return _isSubtask ? 'Add' : 'Create';
  }

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    final rule = widget.existingRecurrence;
    final draft = rule == null ? null : RecurrenceDraft.fromRule(rule);
    _dueDate = widget.initialDueDate ?? task?.dueDate;
    _titleController = TextEditingController(
      text: widget.initialTitle ?? task?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: task?.description ?? '',
    );
    _categoryController = TextEditingController(text: task?.category ?? '');
    _intervalController = TextEditingController(
      text: (draft?.interval ?? 1).toString(),
    );
    _maxOccurrencesController = TextEditingController(
      text: draft?.maxOccurrences?.toString() ?? '',
    );
    _dueDate = widget.initialDueDate ?? task?.dueDate;
    _priority = task?.priority ?? 2;
    _repeats = rule?.isActive ?? false;
    _recurrenceType =
        draft == null || draft.recurrenceType == RecurrenceType.custom
        ? RecurrenceType.daily
        : draft.recurrenceType;
    _recurrenceStart =
        draft?.startDate ??
        (task?.dueDate == null
            ? recurrenceDateOnly(DateTime.now())
            : recurrenceDateOnly(task!.dueDate!));
    _recurrenceEnd = draft?.endDate;
    _weekdayMask = draft?.weekdays ?? weekdayBit(_recurrenceStart.weekday);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _intervalController.dispose();
    _maxOccurrencesController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
    );

    if (pickedDate != null && mounted) {
      setState(() => _dueDate = pickedDate);
    }
  }

  Future<void> _pickRecurrenceStart() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _recurrenceStart,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null && mounted) {
      setState(() {
        _recurrenceStart = recurrenceDateOnly(pickedDate);
        if (_recurrenceEnd != null &&
            _recurrenceEnd!.isBefore(_recurrenceStart)) {
          _recurrenceEnd = null;
        }
        _recurrenceError = null;
      });
    }
  }

  Future<void> _pickRecurrenceEnd() async {
    final initial =
        _recurrenceEnd != null && !_recurrenceEnd!.isBefore(_recurrenceStart)
        ? _recurrenceEnd!
        : _recurrenceStart;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _recurrenceStart,
      lastDate: DateTime(2100),
    );
    if (pickedDate != null && mounted) {
      setState(() {
        _recurrenceEnd = recurrenceDateOnly(pickedDate);
        _recurrenceError = null;
      });
    }
  }

  RecurrenceDraft? _buildRecurrenceDraft({bool reportErrors = true}) {
    if (!_repeats) {
      return null;
    }

    String? error;
    final intervalText = _intervalController.text.trim();
    final interval = int.tryParse(intervalText);
    if (interval == null || interval < 1 || interval > 999) {
      error = 'Interval must be between 1 and 999.';
    }

    final maxText = _maxOccurrencesController.text.trim();
    final maxOccurrences = maxText.isEmpty ? null : int.tryParse(maxText);
    if (error == null &&
        maxText.isNotEmpty &&
        (maxOccurrences == null ||
            maxOccurrences < 1 ||
            maxOccurrences > 10000)) {
      error = 'Maximum occurrences must be between 1 and 10000.';
    }

    if (error == null &&
        _recurrenceType == RecurrenceType.weekly &&
        _weekdayMask == 0) {
      error = 'Select at least one weekday.';
    }

    if (error != null) {
      if (reportErrors) {
        _recurrenceError = error;
      }
      return null;
    }

    final draft = RecurrenceDraft(
      recurrenceType: _recurrenceType,
      interval: interval!,
      weekdays: _recurrenceType == RecurrenceType.weekly ? _weekdayMask : null,
      startDate: _recurrenceStart,
      endDate: _recurrenceEnd,
      maxOccurrences: maxOccurrences,
    );
    final errors = draft.validate();
    if (errors.isNotEmpty) {
      if (reportErrors) {
        _recurrenceError = errors.first;
      }
      return null;
    }
    return draft;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isSubmitting) {
      return;
    }

    final draft = _buildRecurrenceDraft();
    if (_repeats && draft == null) {
      setState(() {});
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final now = DateTime.now();
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();
      final category = _categoryController.text.trim().isEmpty
          ? null
          : _categoryController.text.trim();
      final existingTask = widget.task;
      final task = existingTask == null
          ? Task(
              id: generateId(),
              title: title,
              description: description,
              createdAt: now,
              updatedAt: now,
              dueDate: _dueDate,
              priority: _priority,
              category: category,
            )
          : existingTask.copyWith(
              title: title,
              description: description,
              updatedAt: now,
              dueDate: _dueDate,
              priority: _priority,
              category: category,
            );

      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
      ).pop(CreateTaskResult(task: task, recurrence: draft));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_dialogTitle),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isSubtask) ...[
                Text(
                  'Under "${widget.parentTitle}"',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) {
                  final title = value?.trim() ?? '';
                  if (title.isEmpty) {
                    return 'Title is required';
                  }
                  if (title.length > 120) {
                    return 'Title must be 120 characters or fewer';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category (optional)',
                ),
                validator: (value) {
                  final category = value?.trim() ?? '';
                  if (category.length > 80) {
                    return 'Category must be 80 characters or fewer';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              _DateSelector(
                label: _dueDate == null
                    ? 'Due date (optional)'
                    : 'Due ${formatDate(_dueDate!)}',
                semanticsLabel: _dueDate == null
                    ? 'Choose due date'
                    : 'Due date ${formatDate(_dueDate!)}',
                onTap: _pickDueDate,
                onClear: _dueDate == null
                    ? null
                    : () => setState(() => _dueDate = null),
                clearTooltip: 'Clear due date',
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<int>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: [
                  if (_priority < 1 || _priority > 3)
                    DropdownMenuItem(
                      value: _priority,
                      child: const Text('Low'),
                    ),
                  const DropdownMenuItem(value: 1, child: Text('Low')),
                  DropdownMenuItem(value: 2, child: Text('Medium')),
                  DropdownMenuItem(value: 3, child: Text('High')),
                ],
                onChanged: (priority) {
                  if (priority != null) {
                    setState(() => _priority = priority);
                  }
                },
              ),
              if (_canRepeat) ...[
                const SizedBox(height: AppSpacing.sm),
                const Divider(),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Repeats'),
                  subtitle: Text(
                    _repeats
                        ? 'Occurrences are generated from the schedule below.'
                        : 'Create a one-off task.',
                    style: AppTypography.caption,
                  ),
                  value: _repeats,
                  onChanged: (value) {
                    setState(() {
                      _repeats = value;
                      _recurrenceError = null;
                    });
                  },
                ),
                if (_repeats) _buildRecurrenceFields(context),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (_isSubmitting)
          const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          FilledButton(onPressed: _submit, child: Text(_submitLabel)),
      ],
    );
  }

  Widget _buildRecurrenceFields(BuildContext context) {
    final intervalUnit = switch (_recurrenceType) {
      RecurrenceType.daily || RecurrenceType.custom => 'days',
      RecurrenceType.weekly => 'weeks',
      RecurrenceType.monthly => 'months',
    };
    final draft = _buildRecurrenceDraft(reportErrors: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<RecurrenceType>(
          initialValue: _recurrenceType,
          decoration: const InputDecoration(labelText: 'Frequency'),
          items: const [
            DropdownMenuItem(value: RecurrenceType.daily, child: Text('Daily')),
            DropdownMenuItem(
              value: RecurrenceType.weekly,
              child: Text('Weekly'),
            ),
            DropdownMenuItem(
              value: RecurrenceType.monthly,
              child: Text('Monthly'),
            ),
          ],
          onChanged: (type) {
            if (type == null) return;
            setState(() {
              _recurrenceType = type;
              if (type == RecurrenceType.weekly && _weekdayMask == 0) {
                _weekdayMask = weekdayBit(_recurrenceStart.weekday);
              }
              _recurrenceError = null;
            });
          },
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _intervalController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: 'Every N $intervalUnit'),
          onChanged: (_) => setState(() => _recurrenceError = null),
          validator: (value) {
            final interval = int.tryParse(value?.trim() ?? '');
            if (interval == null || interval < 1 || interval > 999) {
              return 'Enter a number from 1 to 999';
            }
            return null;
          },
        ),
        if (_recurrenceType == RecurrenceType.weekly) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Repeat on', style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (var bit = 0; bit < 7; bit++)
                FilterChip(
                  label: Text(_weekdayShortNames[bit]),
                  selected: _weekdayMask & (1 << bit) != 0,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _weekdayMask |= 1 << bit;
                      } else {
                        _weekdayMask &= ~(1 << bit);
                      }
                      _recurrenceError = null;
                    });
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _DateSelector(
          label: 'Starts ${formatDateOnly(_recurrenceStart)}',
          semanticsLabel:
              'Recurrence start date ${formatDateOnly(_recurrenceStart)}',
          onTap: _pickRecurrenceStart,
        ),
        const SizedBox(height: AppSpacing.sm),
        _DateSelector(
          label: _recurrenceEnd == null
              ? 'End date (optional)'
              : 'Ends ${formatDateOnly(_recurrenceEnd!)}',
          semanticsLabel: _recurrenceEnd == null
              ? 'Choose recurrence end date'
              : 'Recurrence end date ${formatDateOnly(_recurrenceEnd!)}',
          onTap: _pickRecurrenceEnd,
          onClear: _recurrenceEnd == null
              ? null
              : () => setState(() => _recurrenceEnd = null),
          clearTooltip: 'Clear recurrence end date',
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _maxOccurrencesController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Maximum occurrences (optional)',
          ),
          onChanged: (_) => setState(() => _recurrenceError = null),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) return null;
            final count = int.tryParse(text);
            if (count == null || count < 1 || count > 10000) {
              return 'Enter a number from 1 to 10000';
            }
            return null;
          },
        ),
        if (_recurrenceError != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _recurrenceError!,
            style: AppTypography.caption.copyWith(color: AppColors.error),
          ),
        ],
        if (draft != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(draft.summary, style: AppTypography.caption),
        ],
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

const List<String> _weekdayShortNames = [
  'Sun',
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
];

class _DateSelector extends StatelessWidget {
  const _DateSelector({
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
    this.onClear,
    this.clearTooltip = 'Clear date',
  });

  final String label;
  final String semanticsLabel;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final String clearTooltip;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.medium,
      onTap: onTap,
      child: Semantics(
        button: true,
        label: semanticsLabel,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: AppRadius.medium,
          ),
          child: Row(
            children: [
              Expanded(child: Text(label, style: AppTypography.body)),
              if (onClear != null)
                IconButton(
                  tooltip: clearTooltip,
                  onPressed: onClear,
                  icon: const Icon(Icons.clear_rounded),
                ),
              const Icon(Icons.calendar_today_outlined),
            ],
          ),
        ),
      ),
    );
  }
}
