import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/theme/app_spacing.dart';
import '../../tasks/providers/task_provider.dart';
import '../models/focus_session_mode.dart';
import '../models/pomodoro_settings.dart';
import '../providers/focus_provider.dart';
import '../providers/pomodoro_provider.dart';
import 'pomodoro_settings_dialog.dart';

class FocusSetupView extends ConsumerStatefulWidget {
  const FocusSetupView({super.key, this.initialTaskId});

  final String? initialTaskId;

  @override
  ConsumerState<FocusSetupView> createState() => _FocusSetupViewState();
}

class _FocusSetupViewState extends ConsumerState<FocusSetupView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _durationController;
  FocusSessionMode _mode = FocusSessionMode.standard;
  String? _taskId;
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    _taskId = widget.initialTaskId;
    _durationController = TextEditingController(
      text: _defaultMinutes(_mode).toString(),
    );
  }

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasksState = ref.watch(taskProvider);
    final settingsState = ref.watch(pomodoroSettingsProvider);
    final isBreak = _mode.isBreak;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              'Set up a focus session',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Choose what to work on and how you want to focus.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (!isBreak && settingsState.hasValue)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('open-pomodoro-settings'),
                  onPressed: _editPomodoroSettings,
                  child: const Text('Pomodoro settings'),
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<FocusSessionMode>(
                    key: const ValueKey('focus-mode'),
                    initialValue: _mode,
                    decoration: const InputDecoration(
                      labelText: 'Session mode',
                    ),
                    items: [
                      for (final mode in FocusSessionMode.values)
                        DropdownMenuItem(
                          value: mode,
                          child: Text(_modeLabel(mode)),
                        ),
                    ],
                    onChanged: _isStarting
                        ? null
                        : (mode) {
                            if (mode == null) return;
                            setState(() {
                              _mode = mode;
                              _durationController.text = _defaultMinutes(
                                mode,
                                settingsState.asData?.value,
                              ).toString();
                              if (mode.isBreak) _taskId = null;
                            });
                          },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (isBreak)
                    const InputDecorator(
                      decoration: InputDecoration(labelText: 'Session type'),
                      child: Text('Break session — no task required'),
                    )
                  else
                    _taskSelector(tasksState),
                  const SizedBox(height: AppSpacing.md),
                  if (_mode != FocusSessionMode.standard) ...[
                    TextFormField(
                      key: const ValueKey('focus-duration'),
                      controller: _durationController,
                      enabled: !_isStarting,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Duration in minutes',
                        helperText: 'Enter a value from 1 to 1440 minutes.',
                      ),
                      validator: _validateDuration,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'This session is timed. You can complete it early.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ] else
                    const InputDecorator(
                      decoration: InputDecoration(labelText: 'Duration'),
                      child: Text('Standard session — untimed'),
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton.icon(
                    key: const ValueKey('start-focus-session'),
                    onPressed:
                        _isStarting || (_taskId != null && tasksState.isLoading)
                        ? null
                        : _startSession,
                    icon: _isStarting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(_isStarting ? 'Starting…' : 'Start focus'),
                  ),
                  if (!isBreak) ...[
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      key: const ValueKey('start-pomodoro-cycle'),
                      onPressed:
                          _isStarting ||
                              settingsState.isLoading ||
                              settingsState.hasError ||
                              (_taskId != null && tasksState.isLoading)
                          ? null
                          : _startCycle,
                      icon: const Icon(Icons.repeat_rounded),
                      label: const Text('Start Pomodoro cycle'),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (settingsState.hasValue)
                      Text(
                        '${settingsState.requireValue.focusMinutes} min focus · '
                        '${settingsState.requireValue.shortBreakMinutes} min short break · '
                        '${settingsState.requireValue.longBreakMinutes} min long break',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    else if (settingsState.hasError)
                      Text(
                        'Pomodoro settings could not be loaded: '
                        '${settingsState.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _taskSelector(AsyncValue<List<TaskRow>> tasksState) {
    return tasksState.when(
      loading: () => const InputDecorator(
        decoration: InputDecoration(labelText: 'Task (optional)'),
        child: LinearProgressIndicator(),
      ),
      error: (error, _) => InputDecorator(
        decoration: const InputDecoration(labelText: 'Task (optional)'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Could not load tasks.'),
            Text(
              error.toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            TextButton(
              onPressed: () => ref.read(taskProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (tasks) {
        final selectedId = tasks.any((task) => task.id == _taskId)
            ? _taskId
            : null;
        return DropdownButtonFormField<String?>(
          key: const ValueKey('focus-task'),
          initialValue: selectedId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Task (optional)'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('No task — focus on anything'),
            ),
            for (final task in tasks)
              DropdownMenuItem<String?>(
                value: task.id,
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: _isStarting
              ? null
              : (taskId) => setState(() => _taskId = taskId),
        );
      },
    );
  }

  String? _validateDuration(String? value) {
    final minutes = int.tryParse(value ?? '');
    if (minutes == null || minutes < 1 || minutes > 1440) {
      return 'Enter a duration from 1 to 1440 minutes.';
    }
    return null;
  }

  Future<void> _startSession() async {
    if (_mode != FocusSessionMode.standard &&
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _isStarting = true);
    try {
      await ref
          .read(focusSessionProvider.notifier)
          .startSession(
            taskId: _mode.isBreak ? null : _taskId,
            mode: _mode,
            plannedDurationMs: _mode == FocusSessionMode.standard
                ? null
                : int.parse(_durationController.text) *
                      Duration.millisecondsPerMinute,
          );
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  Future<void> _startCycle() async {
    setState(() => _isStarting = true);
    try {
      await ref
          .read(pomodoroCycleProvider.notifier)
          .startCycle(taskId: _taskId);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  Future<void> _editPomodoroSettings() async {
    final settings = ref.read(pomodoroSettingsProvider).asData?.value;
    if (settings == null) return;
    await showDialog<bool>(
      context: context,
      builder: (context) => PomodoroSettingsDialog(settings: settings),
    );
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Could not start focus session: $error')),
      );
  }

  static int _defaultMinutes(
    FocusSessionMode mode, [
    PomodoroSettings? settings,
  ]) => switch (mode) {
    FocusSessionMode.standard => 0,
    FocusSessionMode.pomodoro =>
      settings?.focusMinutes ?? PomodoroSettings.defaultFocusMinutes,
    FocusSessionMode.shortBreak =>
      settings?.shortBreakMinutes ?? PomodoroSettings.defaultShortBreakMinutes,
    FocusSessionMode.longBreak =>
      settings?.longBreakMinutes ?? PomodoroSettings.defaultLongBreakMinutes,
    FocusSessionMode.custom => 25,
  };

  static String _modeLabel(FocusSessionMode mode) => switch (mode) {
    FocusSessionMode.standard => 'Standard',
    FocusSessionMode.pomodoro => 'Pomodoro',
    FocusSessionMode.shortBreak => 'Short break',
    FocusSessionMode.longBreak => 'Long break',
    FocusSessionMode.custom => 'Custom',
  };
}
