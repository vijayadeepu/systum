import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_spacing.dart';
import 'database_diagnostics.dart';
import 'diagnostics_provider.dart';

class DiagnosticsPage extends ConsumerWidget {
  const DiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(diagnosticsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data diagnostics'),
        actions: [
          IconButton(
            tooltip: 'Run diagnostics again',
            onPressed: () => ref.invalidate(diagnosticsProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Diagnostics could not be completed safely.\n$error',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(diagnosticsProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (report) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              report.hasErrors
                  ? 'Review the findings below before changing data.'
                  : 'No integrity errors were found.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Healthy ${report.count(DiagnosticSeverity.healthy)} · '
              'Warnings ${report.count(DiagnosticSeverity.warning)} · '
              'Errors ${report.count(DiagnosticSeverity.error)} · '
              'Inconclusive ${report.count(DiagnosticSeverity.inconclusive)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Diagnostics are read-only. Systum will not delete or repair records automatically.',
            ),
            const SizedBox(height: AppSpacing.md),
            for (final issue in report.issues) _IssueCard(issue: issue),
          ],
        ),
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.issue});

  final DiagnosticIssue issue;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, color) = switch (issue.severity) {
      DiagnosticSeverity.healthy => (
        Icons.check_circle_outline,
        colors.primary,
      ),
      DiagnosticSeverity.warning => (
        Icons.warning_amber_outlined,
        colors.tertiary,
      ),
      DiagnosticSeverity.error => (Icons.error_outline, colors.error),
      DiagnosticSeverity.inconclusive => (Icons.help_outline, colors.error),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    issue.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(issue.severity.name),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(issue.message),
            if (issue.guidance case final guidance?) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(guidance, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (issue.records.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              for (final record in issue.records)
                Text('• $record', style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
