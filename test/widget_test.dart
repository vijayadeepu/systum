import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/app/app.dart';
import 'package:systum/core/backup/automatic_backup.dart';
import 'package:systum/core/backup/backup_provider.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/shared/providers/database_provider.dart';

class _FakeQueryExecutor implements QueryExecutor {
  @override
  SqlDialect get dialect => SqlDialect.sqlite;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) async => true;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) async => const [];

  @override
  Future<int> runInsert(String statement, List<Object?> args) async => 0;

  @override
  Future<int> runUpdate(String statement, List<Object?> args) async => 0;

  @override
  Future<int> runDelete(String statement, List<Object?> args) async => 0;

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) async {}

  @override
  Future<void> runBatched(BatchedStatements statements) async {}

  @override
  TransactionExecutor beginTransaction() => _FakeTransactionExecutor(this);

  @override
  QueryExecutor beginExclusive() => this;

  @override
  Future<void> close() async {}
}

class _FakeTransactionExecutor implements TransactionExecutor {
  _FakeTransactionExecutor(this._executor);

  final QueryExecutor _executor;

  @override
  SqlDialect get dialect => _executor.dialect;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) async => true;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) async => const [];

  @override
  Future<int> runInsert(String statement, List<Object?> args) async => 0;

  @override
  Future<int> runUpdate(String statement, List<Object?> args) async => 0;

  @override
  Future<int> runDelete(String statement, List<Object?> args) async => 0;

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) async {}

  @override
  Future<void> runBatched(BatchedStatements statements) async {}

  @override
  TransactionExecutor beginTransaction() => this;

  @override
  QueryExecutor beginExclusive() => _executor;

  @override
  Future<void> send() async {}

  @override
  Future<void> rollback() async {}

  @override
  Future<void> close() async {}

  @override
  bool get supportsNestedTransactions => false;
}

void main() {
  testWidgets('shows task list page', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backupRecoveryProvider.overrideWith((ref) async {}),
          automaticBackupProvider.overrideWith(
            (ref) async => const AutomaticBackupStatus.empty(),
          ),
          databaseProvider.overrideWithValue(
            SystumDatabase.test(_FakeQueryExecutor()),
          ),
        ],
        child: const SystumApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('No tasks yet'), findsOneWidget);
    expect(find.text('Create your first task to get started.'), findsOneWidget);
  });
}
