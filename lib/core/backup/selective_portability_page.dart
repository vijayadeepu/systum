import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/focus/providers/focus_provider.dart';
import '../../features/focus/providers/pomodoro_provider.dart';
import '../../features/goals/providers/goal_provider.dart';
import '../../features/tasks/providers/task_provider.dart';
import '../theme/app_spacing.dart';
import 'android_document_export.dart';
import 'backup_provider.dart';
import 'backup_service.dart';
import 'selective_portability.dart';

class SelectivePortabilityPage extends ConsumerStatefulWidget {
  const SelectivePortabilityPage({super.key});

  @override
  ConsumerState<SelectivePortabilityPage> createState() =>
      _SelectivePortabilityPageState();
}

class _SelectivePortabilityPageState
    extends ConsumerState<SelectivePortabilityPage> {
  static const _jsonType = XTypeGroup(
    label: 'Systum selective export',
    extensions: ['json'],
    mimeTypes: ['application/json'],
  );

  final Set<SelectiveDataset> _selection = {...SelectiveDataset.values};
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Selective export and import')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'Move only the data you choose. Full backup and restore remains a '
            'separate workflow.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final dataset in SelectiveDataset.values)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(dataset.label),
              value: _selection.contains(dataset),
              onChanged: _busy
                  ? null
                  : (selected) {
                      setState(() {
                        if (selected ?? false) {
                          _selection.add(dataset);
                        } else {
                          _selection.remove(dataset);
                        }
                      });
                    },
            ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _busy ? null : _exportJson,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Export selected as JSON'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _busy || _selection.length != 1 ? null : _exportCsv,
            icon: const Icon(Icons.table_chart_outlined),
            label: Text(
              _selection.length == 1
                  ? 'Export ${_selection.single.label} as CSV'
                  : 'Export CSV (select one data type)',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _busy ? null : _importJson,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Import selective JSON'),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Selective import never replaces the whole database. Existing tasks '
            'and goals are skipped unless you explicitly choose overwrite. '
            'Existing Focus history is never overwritten.',
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

  Future<void> _exportJson() async {
    await _run(() async {
      final encoded = await ref
          .read(selectivePortabilityServiceProvider)
          .exportJson(_selection);
      final path = await _pickDestination('systum-selective.json');
      if (path == null) return;
      await _write(path, encoded);
      _setMessage('Selective JSON export saved.');
    });
  }

  Future<void> _exportCsv() async {
    await _run(() async {
      final dataset = _selection.single;
      final csv = await ref
          .read(selectivePortabilityServiceProvider)
          .exportCsv(dataset);
      final path = await _pickDestination('systum-${dataset.key}.csv');
      if (path == null) return;
      await _write(path, csv);
      _setMessage('${dataset.label} CSV export saved.');
    });
  }

  Future<void> _importJson() async {
    await _run(() async {
      final file = await openFile(
        acceptedTypeGroups: [_jsonType],
        confirmButtonText: 'Select selective export',
      );
      if (file == null) return;
      if (!BackupService.isDocumentWithinLimit(await file.length())) {
        throw const SelectiveImportException(
          'Selective export is too large to import safely.',
        );
      }
      final encoded = await file.readAsString();
      final service = ref.read(selectivePortabilityServiceProvider);
      final preview = await service.preview(encoded);
      if (!mounted) return;

      var overwrite = false;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Import selected data?'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${preview.taskCount} tasks, ${preview.goalCount} goals, '
                    '${preview.focusSessionCount} focus sessions, '
                    '${preview.focusIntervalCount} intervals.',
                  ),
                  if (preview.createdAt case final createdAt?)
                    Text('Exported: ${createdAt.toLocal()}'),
                  if (preview.warnings.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    for (final warning in preview.warnings) Text('• $warning'),
                  ],
                  if (preview.blockers.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    for (final blocker in preview.blockers)
                      Text(
                        '• $blocker',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                  if (preview.canImport)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Overwrite existing tasks and goals'),
                      subtitle: const Text(
                        'Focus history is always append-only and is never overwritten.',
                      ),
                      value: overwrite,
                      onChanged: (value) =>
                          setDialogState(() => overwrite = value ?? false),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: preview.canImport
                    ? () => Navigator.pop(context, true)
                    : null,
                child: const Text('Import'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true) return;

      final result = await service.import(
        encoded,
        confirmed: true,
        overwriteExisting: overwrite,
      );
      _invalidateDataProviders();
      _setMessage(
        'Imported ${result.tasksImported} tasks, '
        '${result.goalsImported} goals, and '
        '${result.focusSessionsImported} focus sessions. '
        'Skipped ${result.tasksSkipped} tasks, '
        '${result.goalsSkipped} goals, and '
        '${result.focusSessionsSkipped} focus sessions.',
      );
    });
  }

  Future<String?> _pickDestination(String fileName) async {
    if (Theme.of(context).platform == TargetPlatform.android) {
      return AndroidDocumentExport().selectDestination(fileName);
    }
    final location = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: const [],
      confirmButtonText: 'Save',
    );
    return location?.path;
  }

  Future<void> _write(String path, String contents) async {
    final bytes = utf8.encode(contents);
    if (Theme.of(context).platform == TargetPlatform.android) {
      await AndroidDocumentExport().publish(bytes, path);
      return;
    }
    await File(path).writeAsBytes(bytes, flush: true);
  }

  void _invalidateDataProviders() {
    ref.invalidate(taskProvider);
    ref.invalidate(goalProvider);
    ref.invalidate(focusSessionProvider);
    ref.invalidate(focusHistoryProvider);
    ref.invalidate(pomodoroSettingsProvider);
    ref.invalidate(pomodoroCycleProvider);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } on Object catch (error) {
      _setMessage(error.toString(), isError: true);
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
