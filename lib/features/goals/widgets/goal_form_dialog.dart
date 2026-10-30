import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../../core/database/database.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/utils/id_generator.dart';
import '../models/goal_date.dart';

/// Create/edit form for a goal. Returns the persisted [GoalRow] to the caller.
class GoalFormDialog extends StatefulWidget {
  const GoalFormDialog({super.key, this.goal});

  final GoalRow? goal;

  @override
  State<GoalFormDialog> createState() => _GoalFormDialogState();
}

class _GoalFormDialogState extends State<GoalFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late GoalDate? _targetDate;

  bool get _isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _titleController = TextEditingController(text: goal?.title ?? '');
    _descriptionController = TextEditingController(
      text: goal?.description ?? '',
    );
    _targetDate = goal?.targetDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickTargetDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _targetDate?.toDateTime() ?? now,
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year + 100, 12, 31),
      helpText: 'Select target date',
    );

    if (pickedDate != null && mounted) {
      setState(() {
        _targetDate = GoalDate.fromDateTime(pickedDate);
      });
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
    final existingGoal = widget.goal;

    final goal = existingGoal == null
        ? GoalRow(
            id: generateId(),
            title: title,
            description: description,
            targetDate: _targetDate,
            createdAt: now,
            updatedAt: now,
          )
        : existingGoal.copyWith(
            title: title,
            description: Value(description),
            targetDate: Value(_targetDate),
            updatedAt: now,
          );

    Navigator.of(context).pop(goal);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Goal' : 'Create Goal'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                autofocus: !_isEditing,
                textInputAction: TextInputAction.next,
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
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
                minLines: 2,
                maxLines: 5,
              ),
              const SizedBox(height: AppSpacing.md),
              InkWell(
                borderRadius: AppRadius.medium,
                onTap: _pickTargetDate,
                child: Semantics(
                  button: true,
                  label: _targetDate == null
                      ? 'Choose target date'
                      : 'Target date ${_targetDate!.toIso8601String()}',
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
                            _targetDate == null
                                ? 'Target date (optional)'
                                : 'Target ${_targetDate!.toIso8601String()}',
                            style: AppTypography.body,
                          ),
                        ),
                        if (_targetDate != null)
                          IconButton(
                            tooltip: 'Clear target date',
                            onPressed: () => setState(() => _targetDate = null),
                            icon: const Icon(Icons.clear_rounded),
                          ),
                        const Icon(Icons.event_outlined),
                      ],
                    ),
                  ),
                ),
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
