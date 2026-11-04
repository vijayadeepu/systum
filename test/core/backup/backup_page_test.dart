import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:systum/core/backup/automatic_backup.dart';
import 'package:systum/core/backup/backup_page.dart';
import 'package:systum/core/backup/backup_provider.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/shared/providers/database_provider.dart';

void main() {
  testWidgets('renders local backup and restore controls', (tester) async {
    final database = SystumDatabase.test(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          automaticBackupProvider.overrideWith(
            (ref) async => const AutomaticBackupStatus.empty(),
          ),
          automaticBackupCatalogueProvider.overrideWith(
            (ref) async => const <AutomaticBackupEntry>[],
          ),
        ],
        child: const MaterialApp(home: BackupPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Backup and restore'), findsOneWidget);
    expect(find.text('Export backup'), findsOneWidget);
    expect(find.text('Import backup'), findsOneWidget);
    expect(find.text('Verify current data'), findsOneWidget);
    expect(find.text('Automatic backups'), findsOneWidget);
    expect(find.text('No automatic backups are stored yet.'), findsOneWidget);
  });
}
