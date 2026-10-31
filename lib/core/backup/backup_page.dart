import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../features/focus/providers/focus_provider.dart';
import '../../features/focus/providers/pomodoro_provider.dart';
import '../../features/goals/providers/goal_provider.dart';
import '../../features/tasks/providers/task_provider.dart';
import 'backup_provider.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  static const _backupType = XTypeGroup(
    label: 'Systum backup',
    extensions: ['json'],
    mimeTypes: ['application/json'],
  );

  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup and restore')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const Icon(Icons.shield_outlined, size: 56),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Keep a local copy of your Systum data.',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Backups include tasks, goals, focus history, intervals, and Pomodoro settings. Nothing is uploaded.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Export backup'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _busy ? null : _import,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Import backup'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: _busy ? null : _verify,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Verify current data'),
          ),
          if (_busy) ...[
            const SizedBox(height: AppSpacing.lg),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_message case final message?) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _messageIsError
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _export() async {
    await _run(() async {
      final location = await getSaveLocation(
        suggestedName: 'systum-backup.json',
        acceptedTypeGroups: [_backupType],
        confirmButtonText: 'Save backup',
      );
      if (location == null) return;
      final encoded = await ref.read(backupServiceProvider).createBackup();
      await XFile.fromData(
        utf8.encode(encoded),
        name: 'systum-backup.json',
        mimeType: 'application/json',
      ).saveTo(location.path);
      _setMessage('Backup exported successfully.');
    });
  }

  Future<void> _import() async {
    await _run(() async {
      final file = await openFile(
        acceptedTypeGroups: [_backupType],
        confirmButtonText: 'Select backup',
      );
      if (file == null) return;
      final encoded = await file.readAsString();
      final service = ref.read(backupServiceProvider);
      await service.validate(encoded);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace local data?'),
          content: const Text(
            'Restoring will replace current tasks, goals, focus history, and Pomodoro settings. This cannot be undone from inside Systum.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace data'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await service.restore(encoded, overwriteExisting: true);
      ref.invalidate(taskProvider);
      ref.invalidate(goalProvider);
      ref.invalidate(focusSessionProvider);
      ref.invalidate(focusHistoryProvider);
      ref.invalidate(pomodoroSettingsProvider);
      ref.invalidate(pomodoroCycleProvider);
      _setMessage('Backup restored successfully.');
    });
  }

  Future<void> _verify() async {
    await _run(() async {
      final service = ref.read(backupServiceProvider);
      await service.validate(await service.createBackup());
      _setMessage('Current data is valid and can be backed up.');
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } on Object catch (error) {
      if (mounted) {
        _setMessage(error.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageIsError = isError;
    });
  }
}
