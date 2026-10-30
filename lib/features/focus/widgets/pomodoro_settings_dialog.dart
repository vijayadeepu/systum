import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../models/pomodoro_settings.dart';
import '../providers/pomodoro_provider.dart';

class PomodoroSettingsDialog extends ConsumerStatefulWidget {
  const PomodoroSettingsDialog({super.key, required this.settings});

  final PomodoroSettings settings;

  @override
  ConsumerState<PomodoroSettingsDialog> createState() =>
      _PomodoroSettingsDialogState();
}

class _PomodoroSettingsDialogState
    extends ConsumerState<PomodoroSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _focusController;
  late final TextEditingController _shortBreakController;
  late final TextEditingController _longBreakController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _focusController = TextEditingController(
      text: widget.settings.focusMinutes.toString(),
    );
    _shortBreakController = TextEditingController(
      text: widget.settings.shortBreakMinutes.toString(),
    );
    _longBreakController = TextEditingController(
      text: widget.settings.longBreakMinutes.toString(),
    );
  }

  @override
  void dispose() {
    _focusController.dispose();
    _shortBreakController.dispose();
    _longBreakController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Pomodoro durations'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _durationField(
              controller: _focusController,
              label: 'Focus minutes',
              key: const ValueKey('pomodoro-focus-minutes'),
            ),
            const SizedBox(height: AppSpacing.sm),
            _durationField(
              controller: _shortBreakController,
              label: 'Short break minutes',
              key: const ValueKey('pomodoro-short-break-minutes'),
            ),
            const SizedBox(height: AppSpacing.sm),
            _durationField(
              controller: _longBreakController,
              label: 'Long break minutes',
              key: const ValueKey('pomodoro-long-break-minutes'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Each duration must be from ${PomodoroSettings.minimumMinutes} '
              'to ${PomodoroSettings.maximumMinutes} minutes.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _isSaving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('save-pomodoro-settings'),
        onPressed: _isSaving ? null : _save,
        child: Text(_isSaving ? 'Saving…' : 'Save'),
      ),
    ],
  );

  Widget _durationField({
    required TextEditingController controller,
    required String label,
    required Key key,
  }) => TextFormField(
    key: key,
    controller: controller,
    enabled: !_isSaving,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      final minutes = int.tryParse(value ?? '');
      if (minutes == null ||
          minutes < PomodoroSettings.minimumMinutes ||
          minutes > PomodoroSettings.maximumMinutes) {
        return 'Enter ${PomodoroSettings.minimumMinutes}–'
            '${PomodoroSettings.maximumMinutes} minutes.';
      }
      return null;
    },
  );

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(pomodoroSettingsProvider.notifier)
          .save(
            PomodoroSettings(
              focusMinutes: int.parse(_focusController.text),
              shortBreakMinutes: int.parse(_shortBreakController.text),
              longBreakMinutes: int.parse(_longBreakController.text),
            ),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save Pomodoro settings: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
