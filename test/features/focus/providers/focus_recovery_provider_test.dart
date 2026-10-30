import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/focus/models/focus_session_mode.dart';
import 'package:systum/features/focus/models/focus_session_status.dart';
import 'package:systum/features/focus/providers/focus_clock_provider.dart';
import 'package:systum/features/focus/providers/focus_provider.dart';
import 'package:systum/features/focus/repository/focus_repository.dart';
import 'package:systum/shared/providers/database_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Focus session recovery', () {
    late SystumDatabase database;
    late DateTime now;

    setUp(() {
      database = SystumDatabase.test(NativeDatabase.memory());
      now = DateTime.utc(2026, 10, 31, 0, 0);
    });

    tearDown(() async {
      await database.close();
    });

    ProviderContainer createContainer() {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          focusSystemClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    testWidgets('app resume reloads unresolved state from SQLite', (
      tester,
    ) async {
      final repository = FocusRepository(database);
      final started = await repository.startSession(
        mode: FocusSessionMode.standard,
        startedAtMs: now.millisecondsSinceEpoch,
      );
      final container = createContainer();
      final subscription = container.listen(focusSessionProvider, (_, _) {});
      await container.read(focusSessionProvider.future);

      await repository.pauseSession(
        started.session.id,
        atMs: now.millisecondsSinceEpoch + 1000,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await container.pump();
      await container.read(focusSessionProvider.future);

      expect(
        container.read(focusSessionProvider).requireValue?.session.status,
        FocusSessionStatus.paused,
      );

      subscription.close();
      container.dispose();
    });

    test('a fresh provider container recovers a running session', () async {
      final repository = FocusRepository(database);
      await repository.startSession(
        mode: FocusSessionMode.standard,
        startedAtMs: now.millisecondsSinceEpoch,
      );
      final container = createContainer();

      expect(
        (await container.read(focusSessionProvider.future))?.session.status,
        FocusSessionStatus.running,
      );
      container.dispose();
    });
  });
}
