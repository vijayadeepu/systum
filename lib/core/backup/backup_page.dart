import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../../features/focus/providers/focus_provider.dart';
import '../../features/focus/providers/pomodoro_provider.dart';
import '../../features/goals/providers/goal_provider.dart';
import '../../features/tasks/providers/task_provider.dart';
import 'android_document_export.dart';
import 'automatic_backup.dart';
import 'backup_provider.dart';
import 'backup_service.dart';
import 'export_service.dart';

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
    final exportRecovery = ref.watch(exportRecoveryProvider);
    final automaticBackup = ref.watch(automaticBackupProvider);
    final catalogue = ref.watch(automaticBackupCatalogueProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Backup and restore')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (exportRecovery.hasError)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: const Padding(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: Text(
                  'An interrupted backup export needs attention. A verified local copy was retained where possible.',
                ),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.autorenew_rounded),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Automatic backups',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _runAutomaticBackup,
                        child: const Text('Back up now'),
                      ),
                    ],
                  ),
                  Text(_automaticSummary(automaticBackup)),
                  if (automaticBackup.value?.hasError ?? false) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      automaticBackup.value!.lastError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (automaticBackup.value?.hasRetentionWarning ?? false) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      automaticBackup.value!.retentionWarning!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _catalogueSection(context, catalogue),
          const SizedBox(height: AppSpacing.md),
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
          TextButton.icon(
            onPressed: _busy ? null : () => context.push('/diagnostics'),
            icon: const Icon(Icons.health_and_safety_outlined),
            label: const Text('Run data diagnostics'),
          ),
          TextButton.icon(
            onPressed: _busy ? null : () => context.push('/backup/portability'),
            icon: const Icon(Icons.swap_vert_rounded),
            label: const Text('Selective export and import'),
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

  Widget _catalogueSection(
    BuildContext context,
    AsyncValue<List<AutomaticBackupEntry>> catalogue,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Automatic backups on this device',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (catalogue.value case final entries?)
              Text(
                _formatBytes(
                  entries.fold<int>(
                    0,
                    (total, entry) => total + entry.file.sizeBytes,
                  ),
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        catalogue.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text(
            'Automatic backup list is unavailable: $error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          data: (entries) {
            if (entries.isEmpty) {
              return const Text('No automatic backups are stored yet.');
            }
            return Column(
              children: [
                for (final entry in entries)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        entry.isVerified
                            ? Icons.verified_outlined
                            : Icons.report_problem_outlined,
                        color: entry.isVerified
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
                      title: Text(_backupTimestamp(entry.file.createdAt)),
                      subtitle: Text(_catalogueDetails(entry)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Restore this backup',
                            onPressed: entry.preview == null || _busy
                                ? null
                                : () => _restoreAutomaticBackup(entry),
                            icon: const Icon(Icons.restore_rounded),
                          ),
                          IconButton(
                            tooltip: 'Delete this backup',
                            onPressed: _busy
                                ? null
                                : () => _deleteAutomaticBackup(entry),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _catalogueDetails(AutomaticBackupEntry entry) {
    final preview = entry.preview;
    final verification = preview == null
        ? 'Unreadable backup'
        : preview.isVerified
        ? 'SHA-256 verified'
        : 'Legacy backup (unverified)';
    final details = StringBuffer(
      '${_formatBytes(entry.file.sizeBytes)} · $verification',
    );
    if (preview != null) {
      details.write(
        ' · ${preview.taskCount} tasks, ${preview.goalCount} goals, '
        '${preview.focusSessionCount} focus sessions',
      );
    }
    if (entry.error case final error?) details.write('\n$error');
    return details.toString();
  }

  Future<void> _restoreAutomaticBackup(AutomaticBackupEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this automatic backup?'),
        content: Text(
          'Backup from ${_backupTimestamp(entry.file.createdAt)}.\n\n'
          'Restoring replaces current tasks, goals, focus history, intervals, '
          'and Pomodoro settings. This cannot be undone from inside Systum.',
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
    if (confirmed != true || !mounted) return;

    await _run(() async {
      await ref.read(automaticBackupServiceProvider).restoreBackup(entry.file);
      _invalidateDataProviders();
      ref.invalidate(automaticBackupCatalogueProvider);
      _setMessage('Automatic backup restored successfully.');
    });
  }

  Future<void> _deleteAutomaticBackup(AutomaticBackupEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this backup?'),
        content: Text(
          'Delete the automatic backup from '
          '${_backupTimestamp(entry.file.createdAt)}? '
          'Other backups are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _run(() async {
      await ref.read(automaticBackupServiceProvider).deleteBackup(entry.file);
      ref.invalidate(automaticBackupCatalogueProvider);
      _setMessage('Automatic backup deleted.');
    });
  }

  void _invalidateDataProviders() {
    ref.invalidate(taskProvider);
    ref.invalidate(goalProvider);
    ref.invalidate(focusSessionProvider);
    ref.invalidate(focusHistoryProvider);
    ref.invalidate(pomodoroSettingsProvider);
    ref.invalidate(pomodoroCycleProvider);
  }

  String _backupTimestamp(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _runAutomaticBackup() async {
    await _run(() async {
      final status = await ref
          .read(automaticBackupServiceProvider)
          .runIfDue(force: true);
      if (status.hasError) {
        throw BackupValidationException(status.lastError!);
      }
      ref.invalidate(automaticBackupProvider);
      ref.invalidate(automaticBackupCatalogueProvider);
      _setMessage(
        'Automatic backup verified and stored privately on this device.',
      );
    });
  }

  String _automaticSummary(AsyncValue<AutomaticBackupStatus> value) {
    if (value.isLoading) return 'Preparing an automatic backup check…';
    final status = value.value;
    if (status == null) return 'Automatic backup status is unavailable.';
    final lastSuccess = status.lastSuccessAt;
    if (lastSuccess == null) {
      return status.hasError
          ? 'No automatic backup has completed yet.'
          : 'No automatic backup is due yet.';
    }
    final local = lastSuccess.toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    final age = _ageLabel(DateTime.now().toUtc().difference(lastSuccess));
    return 'Last successful automatic backup: '
        '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} $time ($age). '
        'Backups are stored only in app-private storage.';
  }

  String _ageLabel(Duration age) {
    if (age.isNegative || age.inMinutes < 1) return 'just now';
    if (age.inHours < 1) return '${age.inMinutes}m ago';
    if (age.inDays < 1) return '${age.inHours}h ago';
    return '${age.inDays}d ago';
  }

  Future<void> _export() async {
    await _run(() async {
      final result = await ref
          .read(exportServiceProvider)
          .export(
            selectDestination: () async {
              if (Theme.of(context).platform == TargetPlatform.android) {
                return AndroidDocumentExport().selectDestination(
                  'systum-backup.json',
                );
              }
              final location = await getSaveLocation(
                suggestedName: 'systum-backup.json',
                acceptedTypeGroups: [_backupType],
                confirmButtonText: 'Save backup',
              );
              return location?.path;
            },
          );
      final message = switch (result.outcome) {
        ExportOutcome.completed => 'Backup exported and destination verified.',
        ExportOutcome.stagedOnly =>
          'Backup was verified locally, but destination readback is unavailable. The verified staged copy was retained.',
        ExportOutcome.cancelled => 'Backup export cancelled.',
      };
      _setMessage(message, isError: result.outcome == ExportOutcome.stagedOnly);
    });
  }

  Future<void> _import() async {
    await _run(() async {
      final file = await openFile(
        acceptedTypeGroups: [_backupType],
        confirmButtonText: 'Select backup',
      );
      if (file == null) return;
      if (!BackupService.isDocumentWithinLimit(await file.length())) {
        throw const BackupValidationException(
          'Backup file is too large to import safely.',
        );
      }
      final encoded = await file.readAsString();
      final service = ref.read(backupServiceProvider);
      final validation = await service.validate(encoded);
      if (!mounted) return;
      final verificationMessage = validation.isVerified
          ? 'Verified backup: SHA-256 integrity checked.'
          : 'Legacy backup: integrity cannot be verified.';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace local data?'),
          content: Text(
            '$verificationMessage\n\nRestoring will replace current tasks, goals, focus history, and Pomodoro settings. This cannot be undone from inside Systum.',
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
      _invalidateDataProviders();
      ref.invalidate(automaticBackupCatalogueProvider);
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
        final message = error is BackupValidationException
            ? 'Invalid backup — restore unavailable. ${error.message}'
            : error.toString();
        _setMessage(message, isError: true);
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
