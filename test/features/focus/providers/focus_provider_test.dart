import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/focus/models/focus_session.dart';
import 'package:systum/features/focus/models/focus_session_mode.dart';
import 'package:systum/features/focus/models/focus_session_status.dart';
import 'package:systum/features/focus/providers/focus_clock_provider.dart';
import 'package:systum/features/focus/providers/focus_provider.dart';
import 'package:systum/features/focus/repository/focus_repository.dart';
import 'package:systum/shared/providers/database_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Focus providers', () {
    late SystumDatabase database;
    late DateTime now;

    setUp(() {
      database = SystumDatabase.test(NativeDatabase.memory());
      now = DateTime.utc(2026, 10, 31, 0, 0);
    });

    tearDown(() async {
      await database.close();
    });

    ProviderContainer createContainer({
      FocusRepository? repository,
      DateTime Function()? clock,
    }) {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          if (repository != null)
            focusRepositoryProvider.overrideWithValue(repository),
          focusSystemClockProvider.overrideWithValue(clock ?? () => now),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('loads no unresolved session as AsyncData(null)', () async {
      final container = createContainer();

      expect(await container.read(focusSessionProvider.future), isNull);
      expect(container.read(focusSessionProvider), isA<AsyncData>());
      expect(container.read(focusSessionProvider).requireValue, isNull);
    });

    test(
      'exposes loading while the initial database read is pending',
      () async {
        final repository = _BlockingRepository(database);
        final container = createContainer(repository: repository);
        final initialLoad = container.read(focusSessionProvider.future);
        await repository.unresolvedReadStarted.future;

        expect(container.read(focusSessionProvider), isA<AsyncLoading>());

        repository.releaseUnresolvedRead.complete();
        expect(await initialLoad, isNull);
      },
    );

    test('loads a running session from persisted state', () async {
      final repository = FocusRepository(database);
      await repository.startSession(
        mode: FocusSessionMode.standard,
        startedAtMs: 1000,
      );
      final container = createContainer(repository: repository);

      final session = await container.read(focusSessionProvider.future);
      expect(session?.session.status, FocusSessionStatus.running);
      expect(session?.intervals.single.isOpen, isTrue);
    });

    test(
      'loads a paused session without inventing a running interval',
      () async {
        final repository = FocusRepository(database);
        final started = await repository.startSession(
          mode: FocusSessionMode.standard,
          startedAtMs: 1000,
        );
        await repository.pauseSession(started.session.id, atMs: 1500);
        final container = createContainer(repository: repository);

        final session = await container.read(focusSessionProvider.future);
        expect(session?.session.status, FocusSessionStatus.paused);
        expect(session?.intervals.single.isOpen, isFalse);
      },
    );

    test(
      'start and lifecycle mutations use injected UTC clock and refresh history',
      () async {
        final container = createContainer();
        final historySubscription = container.listen(
          focusHistoryProvider,
          (_, _) {},
        );
        addTearDown(historySubscription.close);
        await container.read(focusSessionProvider.future);
        await container.read(focusHistoryProvider.future);

        final started = await container
            .read(focusSessionProvider.notifier)
            .startSession(
              mode: FocusSessionMode.pomodoro,
              plannedDurationMs: 5000,
            );
        expect(started.session.startedAtMs, now.millisecondsSinceEpoch);
        expect(container.read(focusSessionProvider).requireValue, started);
        expect(await container.read(focusHistoryProvider.future), hasLength(1));

        now = now.add(const Duration(seconds: 2));
        final paused = await container
            .read(focusSessionProvider.notifier)
            .pauseSession(started.session.id);
        expect(paused.session.updatedAtMs, now.millisecondsSinceEpoch);
        expect(paused.session.status, FocusSessionStatus.paused);

        now = now.add(const Duration(seconds: 4));
        final resumed = await container
            .read(focusSessionProvider.notifier)
            .resumeSession(started.session.id);
        expect(resumed.session.updatedAtMs, now.millisecondsSinceEpoch);

        now = now.add(const Duration(seconds: 1));
        final completed = await container
            .read(focusSessionProvider.notifier)
            .completeSession(started.session.id);
        expect(completed.session.status, FocusSessionStatus.completed);
        expect(
          completed.session.actualDurationMs,
          const Duration(seconds: 3).inMilliseconds,
        );
        expect(container.read(focusSessionProvider).requireValue, isNull);
        expect(await container.read(focusHistoryProvider.future), hasLength(1));
      },
    );

    test('cancel and interrupt delegate to repository transitions', () async {
      final container = createContainer();
      await container.read(focusSessionProvider.future);
      final notifier = container.read(focusSessionProvider.notifier);

      final cancelled = await notifier.startSession(
        mode: FocusSessionMode.standard,
      );
      now = now.add(const Duration(seconds: 1));
      expect(
        (await notifier.cancelSession(cancelled.session.id)).session.status,
        FocusSessionStatus.cancelled,
      );

      now = now.add(const Duration(seconds: 1));
      final interrupted = await notifier.startSession(
        mode: FocusSessionMode.standard,
      );
      now = now.add(const Duration(seconds: 1));
      expect(
        (await notifier.interruptSession(
          interrupted.session.id,
        )).session.status,
        FocusSessionStatus.interrupted,
      );
    });

    test(
      'repository mutation failures remain visible in state and caller',
      () async {
        final repository = _FailingStartRepository(database);
        final container = createContainer(repository: repository);
        await container.read(focusSessionProvider.future);

        await expectLater(
          container
              .read(focusSessionProvider.notifier)
              .startSession(mode: FocusSessionMode.standard),
          throwsA(isA<StateError>()),
        );
        final state = container.read(focusSessionProvider);
        expect(state, isA<AsyncError>());
        expect(state.error, isA<StateError>());
      },
    );

    test(
      'concurrent mutations are rejected until the first is persisted',
      () async {
        final repository = _BlockingStartRepository(database);
        final container = createContainer(repository: repository);
        await container.read(focusSessionProvider.future);
        final notifier = container.read(focusSessionProvider.notifier);

        final pendingStart = notifier.startSession(
          mode: FocusSessionMode.standard,
        );
        await repository.startStarted.future;
        await expectLater(
          notifier.startSession(mode: FocusSessionMode.standard),
          throwsA(isA<FocusMutationInProgressException>()),
        );

        repository.releaseStart.complete();
        await pendingStart;
        expect(container.read(focusSessionProvider).requireValue, isNotNull);
      },
    );

    test('refresh requests during a mutation run after commit', () async {
      final repository = _BlockingStartRepository(database);
      final container = createContainer(repository: repository);
      await container.read(focusSessionProvider.future);
      final notifier = container.read(focusSessionProvider.notifier);

      final pendingStart = notifier.startSession(
        mode: FocusSessionMode.standard,
      );
      await repository.startStarted.future;
      await notifier.refresh();
      repository.releaseStart.complete();
      final started = await pendingStart;
      await container.pump();

      expect(
        container.read(focusSessionProvider).requireValue?.session.id,
        started.session.id,
      );
    });
  });
}

class _BlockingRepository extends FocusRepository {
  _BlockingRepository(super.database);

  final unresolvedReadStarted = Completer<void>();
  final releaseUnresolvedRead = Completer<void>();

  @override
  Future<FocusSessionTransition?> getUnresolvedSession() async {
    unresolvedReadStarted.complete();
    await releaseUnresolvedRead.future;
    return super.getUnresolvedSession();
  }
}

class _FailingStartRepository extends FocusRepository {
  _FailingStartRepository(super.database);

  @override
  Future<FocusSessionTransition> startSession({
    String? taskId,
    String? taskIdSnapshot,
    String? taskTitleSnapshot,
    required FocusSessionMode mode,
    required int startedAtMs,
    int? plannedDurationMs,
    String? cycleId,
    int? cycleRound,
  }) {
    throw StateError('Storage write failed.');
  }
}

class _BlockingStartRepository extends FocusRepository {
  _BlockingStartRepository(super.database);

  final startStarted = Completer<void>();
  final releaseStart = Completer<void>();

  @override
  Future<FocusSessionTransition> startSession({
    String? taskId,
    String? taskIdSnapshot,
    String? taskTitleSnapshot,
    required FocusSessionMode mode,
    required int startedAtMs,
    int? plannedDurationMs,
    String? cycleId,
    int? cycleRound,
  }) async {
    startStarted.complete();
    await releaseStart.future;
    return super.startSession(
      taskId: taskId,
      taskIdSnapshot: taskIdSnapshot,
      taskTitleSnapshot: taskTitleSnapshot,
      mode: mode,
      startedAtMs: startedAtMs,
      plannedDurationMs: plannedDurationMs,
      cycleId: cycleId,
      cycleRound: cycleRound,
    );
  }
}
