import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/backup/selective_portability_page.dart';

void main() {
  testWidgets('renders dataset selection and guarded CSV export', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SelectivePortabilityPage())),
    );

    expect(find.text('Selective export and import'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Goals'), findsOneWidget);
    expect(find.text('Focus history'), findsOneWidget);
    expect(find.text('Export selected as JSON'), findsOneWidget);
    expect(find.text('Export CSV (select one data type)'), findsOneWidget);

    await tester.tap(find.text('Goals'));
    await tester.tap(find.text('Focus history'));
    await tester.pump();

    expect(find.text('Export Tasks as CSV'), findsOneWidget);
    expect(
      find.textContaining('never replaces the whole database'),
      findsOneWidget,
    );
  });
}
