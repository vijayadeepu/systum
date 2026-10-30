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

  group('Focus display clock', () {
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

    testWidgets('running elapsed time follows the display clock only', (
      tester,
    ) async {
      final container = createContainer();
      final sessionSubscription = container.listen(
        focusSessionProvider,
        (_, _) {},
      );
      final elapsedSubscription = container.listen(
        focusElapsedDurationProvider,
        (_, _) {},
      );
      await container.read(focusSessionProvider.future);

      final started = await container
          .read(focusSessionProvider.notifier)
          .startSession(mode: FocusSessionMode.standard);
      expect(container.read(focusElapsedDurationProvider).requireValue, 0);

      now = now.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
      expect(container.read(focusElapsedDurationProvider).requireValue, 3000);
      final stored = await FocusRepository(
        database,
      ).getById(started.session.id);
      expect(stored?.session.status, FocusSessionStatus.running);
      expect(stored?.session.actualDurationMs, isNull);
      expect(stored?.session.updatedAtMs, started.session.updatedAtMs);
      expect(stored?.intervals.single.endedAtMs, isNull);

      elapsedSubscription.close();
      sessionSubscription.close();
      container.dispose();
    });

    testWidgets('paused elapsed time remains stable across display ticks', (
      tester,
    ) async {
      final container = createContainer();
      final subscription = container.listen(
        focusElapsedDurationProvider,
        (_, _) {},
      );
      await container.read(focusSessionProvider.future);

      final started = await container
          .read(focusSessionProvider.notifier)
          .startSession(mode: FocusSessionMode.standard);
      now = now.add(const Duration(seconds: 2));
      await container
          .read(focusSessionProvider.notifier)
          .pauseSession(started.session.id);
      expect(container.read(focusElapsedDurationProvider).requireValue, 2000);

      now = now.add(const Duration(minutes: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(container.read(focusElapsedDurationProvider).requireValue, 2000);

      subscription.close();
      container.dispose();
    });

    testWidgets('clock stops while backgrounded and refreshes on resume', (
      tester,
    ) async {
      final container = createContainer();
      final subscription = container.listen(focusClockProvider, (_, _) {});
      final initial = container.read(focusClockProvider);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      now = now.add(const Duration(minutes: 2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(container.read(focusClockProvider), now);
      expect(container.read(focusClockProvider), isNot(initial));
      subscription.close();
      container.dispose();
    });
  });
}
