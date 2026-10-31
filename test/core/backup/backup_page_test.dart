import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:systum/core/backup/backup_page.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/shared/providers/database_provider.dart';

void main() {
  testWidgets('renders local backup and restore controls', (tester) async {
    final database = SystumDatabase.test(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: BackupPage()),
      ),
    );

    expect(find.text('Backup and restore'), findsOneWidget);
    expect(find.text('Export backup'), findsOneWidget);
    expect(find.text('Import backup'), findsOneWidget);
    expect(find.text('Verify current data'), findsOneWidget);
  });
}
