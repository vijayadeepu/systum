import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/diagnostics/database_diagnostics.dart';
import 'package:systum/core/diagnostics/diagnostics_page.dart';
import 'package:systum/core/diagnostics/diagnostics_provider.dart';

void main() {
  testWidgets('shows severity counts, records, and read-only guidance', (
    tester,
  ) async {
    final report = DiagnosticReport(
      completedAt: DateTime.utc(2026, 11, 3),
      issues: const [
        DiagnosticIssue(
          name: 'SQLite integrity',
          severity: DiagnosticSeverity.healthy,
          message: 'SQLite integrity_check completed successfully.',
        ),
        DiagnosticIssue(
          name: 'Task relationships',
          severity: DiagnosticSeverity.error,
          message: 'Task relationships require review.',
          records: ['task-1:missing_parent'],
          guidance: 'Review the listed tasks.',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [diagnosticsProvider.overrideWith((ref) async => report)],
        child: const MaterialApp(home: DiagnosticsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Data diagnostics'), findsOneWidget);
    expect(
      find.text('Healthy 1 · Warnings 0 · Errors 1 · Inconclusive 0'),
      findsOneWidget,
    );
    expect(find.text('Task relationships'), findsOneWidget);
    expect(find.text('• task-1:missing_parent'), findsOneWidget);
    expect(find.text('Review the listed tasks.'), findsOneWidget);
    expect(find.textContaining('Diagnostics are read-only'), findsOneWidget);
  });

  testWidgets('shows a retry action when diagnostics fail', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diagnosticsProvider.overrideWith(
            (ref) => Future<DiagnosticReport>.error(Exception('offline')),
          ),
        ],
        child: const MaterialApp(home: DiagnosticsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('offline'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
