import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/task.dart';

class CreateTaskDialog extends StatefulWidget {
  const CreateTaskDialog({super.key, this.task});

  final Task? task;

  @override
  State<CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<CreateTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late DateTime? _dueDate;
  late int _priority;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController = TextEditingController(
      text: task?.description ?? '',
    );
    _dueDate = task?.dueDate;
    _priority = task?.priority ?? 2;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
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

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final now = DateTime.now();
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();
    final existingTask = widget.task;
    final task = existingTask == null
        ? Task(
            id: _generateTaskId(),
            title: title,
            description: description,
            createdAt: now,
            updatedAt: now,
            dueDate: _dueDate,
            priority: _priority,
          )
        : existingTask.copyWith(
            title: title,
            description: description,
            updatedAt: now,
            dueDate: _dueDate,
            priority: _priority,
          );

    Navigator.of(context).pop(task);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Task' : 'Create Task'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
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
              InkWell(
                borderRadius: AppRadius.medium,
                onTap: _pickDueDate,
                child: Semantics(
                  button: true,
                  label: _dueDate == null
                      ? 'Choose due date'
                      : 'Due date ${_formatDate(_dueDate!)}',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: AppRadius.medium,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _dueDate == null
                                ? 'Due date (optional)'
                                : 'Due ${_formatDate(_dueDate!)}',
                            style: AppTypography.body,
                          ),
                        ),
                        if (_dueDate != null)
                          IconButton(
                            tooltip: 'Clear due date',
                            onPressed: () => setState(() => _dueDate = null),
                            icon: const Icon(Icons.clear_rounded),
                          ),
                        const Icon(Icons.calendar_today_outlined),
                      ],
                    ),
                  ),
                ),
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

String _formatDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _generateTaskId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));

  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();

  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
