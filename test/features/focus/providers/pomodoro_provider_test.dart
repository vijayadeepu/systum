import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:systum/core/database/database.dart';
import 'package:systum/features/focus/models/focus_session_mode.dart';
import 'package:systum/features/focus/models/focus_session_status.dart';
import 'package:systum/features/focus/models/pomodoro_settings.dart';
import 'package:systum/features/focus/providers/focus_clock_provider.dart';
import 'package:systum/features/focus/providers/focus_provider.dart';
import 'package:systum/features/focus/providers/pomodoro_provider.dart';
import 'package:systum/features/focus/repository/focus_repository.dart';
import 'package:systum/features/focus/repository/pomodoro_settings_store.dart';
import 'package:systum/features/tasks/models/task.dart';
import 'package:systum/features/tasks/repository/task_repository.dart';
import 'package:systum/shared/providers/database_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pomodoro cycle provider', () {
    late SystumDatabase database;
    late _MemoryPomodoroSettingsStore settingsStore;
    late DateTime now;
    var cycleNumber = 0;

    setUp(() {
      settingsStore = _MemoryPomodoroSettingsStore();
      database = SystumDatabase.test(NativeDatabase.memory());
      now = DateTime.utc(2026, 10, 31, 0);
      cycleNumber = 0;
    });

    tearDown(() async {
      await database.close();
    });

    ProviderContainer createContainer() => ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        pomodoroSettingsStoreProvider.overrideWithValue(settingsStore),
        focusSystemClockProvider.overrideWithValue(() => now),
        pomodoroCycleIdGeneratorProvider.overrideWithValue(
          () => 'cycle-${++cycleNumber}',
        ),
      ],
    );

    Future<void> load(ProviderContainer container) async {
      await container.read(focusSessionProvider.future);
      await container.read(pomodoroSettingsProvider.future);
      await container.read(pomodoroCycleProvider.future);
    }

    Future<void> completeCurrent(ProviderContainer container) async {
      final current = await container.read(focusSessionProvider.future);
      expect(current, isNotNull);
      now = now.add(const Duration(seconds: 1));
      await container
          .read(focusSessionProvider.notifier)
          .completeSession(current!.session.id);
    }

    test('starts the first persisted focus session in round one', () async {
      final container = createContainer();
      addTearDown(container.dispose);
      await load(container);

      final started = await container
          .read(pomodoroCycleProvider.notifier)
          .startCycle();

      expect(started.session.mode, FocusSessionMode.pomodoro);
      expect(started.session.cycleId, 'cycle-1');
      expect(started.session.cycleRound, 1);
      expect(
        started.session.plannedDurationMs,
        const Duration(minutes: 25).inMilliseconds,
      );
      expect(await FocusRepository(database).getHistory(), hasLength(1));
    });

    test(
      'four completed focus rounds use short breaks and then a long break',
      () async {
        final container = createContainer();
        addTearDown(container.dispose);
        await load(container);
        final cycle = container.read(pomodoroCycleProvider.notifier);
        final first = await cycle.startCycle();

        for (var round = 1; round <= 4; round++) {
          await completeCurrent(container);
          final afterFocus = await container.read(pomodoroCycleProvider.future);
          expect(afterFocus?.cycleId, first.session.cycleId);
          expect(afterFocus?.round, round);
          expect(
            afterFocus?.nextMode,
            round == 4
                ? FocusSessionMode.longBreak
                : FocusSessionMode.shortBreak,
          );

          final breakSession = await cycle.startNextSegment();
          expect(breakSession.session.cycleId, first.session.cycleId);
          expect(breakSession.session.cycleRound, round);
          expect(
            breakSession.session.mode,
            round == 4
                ? FocusSessionMode.longBreak
                : FocusSessionMode.shortBreak,
          );
          expect(breakSession.session.taskId, isNull);
          expect(breakSession.session.taskIdSnapshot, isNull);
          await completeCurrent(container);

          if (round < 4) {
            final nextFocus = await cycle.startNextSegment();
            expect(nextFocus.session.mode, FocusSessionMode.pomodoro);
            expect(nextFocus.session.cycleRound, round + 1);
            expect(nextFocus.session.cycleId, first.session.cycleId);
          }
        }

        final complete = await container.read(pomodoroCycleProvider.future);
        expect(complete?.isComplete, isTrue);
        final newCycle = await cycle.startNewCycle();
        expect(newCycle.session.cycleId, 'cycle-2');
        expect(newCycle.session.cycleRound, 1);
        expect(newCycle.session.mode, FocusSessionMode.pomodoro);
      },
    );

    test(
      'custom configuration is recovered by a fresh provider container',
      () async {
        final container = createContainer();
        await load(container);
        final settings = PomodoroSettings(
          focusMinutes: 40,
          shortBreakMinutes: 8,
          longBreakMinutes: 22,
        );
        await container.read(pomodoroSettingsProvider.notifier).save(settings);
        container.dispose();

        final recovered = createContainer();
        addTearDown(recovered.dispose);
        await load(recovered);
        expect(await recovered.read(pomodoroSettingsProvider.future), settings);
        final started = await recovered
            .read(pomodoroCycleProvider.notifier)
            .startCycle();
        expect(
          started.session.plannedDurationMs,
          const Duration(minutes: 40).inMilliseconds,
        );
      },
    );

    test('pause and resume do not advance the current round', () async {
      final container = createContainer();
      addTearDown(container.dispose);
      await load(container);
      final first = await container
          .read(pomodoroCycleProvider.notifier)
          .startCycle();
      final focus = container.read(focusSessionProvider.notifier);

      now = now.add(const Duration(seconds: 1));
      await focus.pauseSession(first.session.id);
      now = now.add(const Duration(minutes: 5));
      await focus.resumeSession(first.session.id);

      final cycle = await container.read(pomodoroCycleProvider.future);
      expect(cycle?.round, 1);
      expect(cycle?.nextMode, isNull);
      expect(cycle?.isActive, isTrue);
      expect(
        (await FocusRepository(database).getHistory()).single.session.status,
        FocusSessionStatus.running,
      );
    });

    test(
      'early completion offers the break without waiting for planned time',
      () async {
        final container = createContainer();
        addTearDown(container.dispose);
        await load(container);
        final started = await container
            .read(pomodoroCycleProvider.notifier)
            .startCycle();

        await completeCurrent(container);

        final history = await FocusRepository(database).getHistory();
        expect(history.single.session.status, FocusSessionStatus.completed);
        expect(history.single.session.actualDurationMs, 1000);
        expect(
          (await container.read(pomodoroCycleProvider.future))?.nextMode,
          FocusSessionMode.shortBreak,
        );
        expect(started.session.plannedDurationMs, greaterThan(1000));
      },
    );

    test(
      'cancelled and interrupted focus sessions are retried, not counted',
      () async {
        for (final terminalStatus in [
          FocusSessionStatus.cancelled,
          FocusSessionStatus.interrupted,
        ]) {
          final container = createContainer();
          await load(container);
          final started = await container
              .read(pomodoroCycleProvider.notifier)
              .startCycle();
          now = now.add(const Duration(seconds: 1));
          if (terminalStatus == FocusSessionStatus.cancelled) {
            await container
                .read(focusSessionProvider.notifier)
                .cancelSession(started.session.id);
          } else {
            await container
                .read(focusSessionProvider.notifier)
                .interruptSession(started.session.id);
          }

          container.dispose();

          final recoveredContainer = createContainer();
          await load(recoveredContainer);
          final state = await recoveredContainer.read(
            pomodoroCycleProvider.future,
          );
          expect(state?.requiresRecovery, isTrue);
          expect(state?.nextMode, FocusSessionMode.pomodoro);
          expect(state?.nextRound, 1);
          final retry = await recoveredContainer
              .read(pomodoroCycleProvider.notifier)
              .startNextSegment();
          expect(retry.session.cycleId, started.session.cycleId);
          expect(retry.session.cycleRound, 1);
          await recoveredContainer
              .read(pomodoroCycleProvider.notifier)
              .exitCycle();
          recoveredContainer.dispose();
        }
      },
    );

    test(
      'cancelled break is offered again instead of advancing the round',
      () async {
        final container = createContainer();
        addTearDown(container.dispose);
        await load(container);
        final cycle = container.read(pomodoroCycleProvider.notifier);
        await cycle.startCycle();
        await completeCurrent(container);
        final shortBreak = await cycle.startNextSegment();
        now = now.add(const Duration(seconds: 1));
        await container
            .read(focusSessionProvider.notifier)
            .cancelSession(shortBreak.session.id);

        final recovered = await container.read(pomodoroCycleProvider.future);
        expect(recovered?.requiresRecovery, isTrue);
        expect(recovered?.nextMode, FocusSessionMode.shortBreak);
        expect(recovered?.nextRound, 1);
      },
    );

    test(
      'repeat starts are rejected and do not duplicate session records',
      () async {
        final container = createContainer();
        addTearDown(container.dispose);
        await load(container);
        final notifier = container.read(pomodoroCycleProvider.notifier);

        final firstStart = notifier.startCycle();
        await expectLater(
          notifier.startCycle(),
          throwsA(isA<PomodoroMutationInProgressException>()),
        );
        final first = await firstStart;
        await expectLater(notifier.startCycle(), throwsA(isA<StateError>()));
        expect(await FocusRepository(database).getHistory(), hasLength(1));

        now = now.add(const Duration(seconds: 1));
        await container
            .read(focusSessionProvider.notifier)
            .completeSession(first.session.id);
        await notifier.startNextSegment();
        await expectLater(notifier.startNextSegment(), throwsA(anything));
        expect(await FocusRepository(database).getHistory(), hasLength(2));
      },
    );

    test(
      'recovery resumes running and paused focus and break sessions',
      () async {
        for (final scenario in [
          (mode: FocusSessionMode.pomodoro, paused: false),
          (mode: FocusSessionMode.pomodoro, paused: true),
          (mode: FocusSessionMode.shortBreak, paused: false),
          (mode: FocusSessionMode.shortBreak, paused: true),
        ]) {
          final firstContainer = createContainer();
          await load(firstContainer);
          final cycle = firstContainer.read(pomodoroCycleProvider.notifier);
          var current = await cycle.startCycle();
          if (scenario.mode == FocusSessionMode.shortBreak) {
            await completeCurrent(firstContainer);
            current = await cycle.startNextSegment();
          }
          if (scenario.paused) {
            now = now.add(const Duration(seconds: 1));
            await firstContainer
                .read(focusSessionProvider.notifier)
                .pauseSession(current.session.id);
          }
          firstContainer.dispose();

          final recoveredContainer = createContainer();
          await load(recoveredContainer);
          final recoveredSession = await recoveredContainer.read(
            focusSessionProvider.future,
          );
          final recoveredCycle = await recoveredContainer.read(
            pomodoroCycleProvider.future,
          );
          expect(recoveredSession?.session.mode, scenario.mode);
          expect(
            recoveredSession?.session.status,
            scenario.paused
                ? FocusSessionStatus.paused
                : FocusSessionStatus.running,
          );
          expect(recoveredCycle?.isActive, isTrue);
          await recoveredContainer
              .read(pomodoroCycleProvider.notifier)
              .exitCycle();
          recoveredContainer.dispose();
        }
      },
    );

    test(
      'recovers completed focus and break before the next segment starts',
      () async {
        final container = createContainer();
        await load(container);
        final cycle = container.read(pomodoroCycleProvider.notifier);
        await cycle.startCycle();
        await completeCurrent(container);
        expect(
          (await container.read(pomodoroCycleProvider.future))?.nextMode,
          FocusSessionMode.shortBreak,
        );
        container.dispose();

        final afterFocus = createContainer();
        await load(afterFocus);
        expect(
          (await afterFocus.read(pomodoroCycleProvider.future))?.nextMode,
          FocusSessionMode.shortBreak,
        );
        await afterFocus
            .read(pomodoroCycleProvider.notifier)
            .startNextSegment();
        await completeCurrent(afterFocus);
        expect(
          (await afterFocus.read(pomodoroCycleProvider.future))?.nextMode,
          FocusSessionMode.pomodoro,
        );
        afterFocus.dispose();

        final afterBreak = createContainer();
        addTearDown(afterBreak.dispose);
        await load(afterBreak);
        final recovered = await afterBreak.read(pomodoroCycleProvider.future);
        expect(recovered?.nextMode, FocusSessionMode.pomodoro);
        expect(recovered?.nextRound, 2);
        expect(await FocusRepository(database).getHistory(), hasLength(2));
      },
    );

    test(
      'deleted task remains in focus snapshots while breaks stay standalone',
      () async {
        final task = Task(
          id: 'cycle-task',
          title: 'Original cycle task',
          createdAt: now,
          updatedAt: now,
        );
        await TaskRepository(database).insert(task);
        final container = createContainer();
        addTearDown(container.dispose);
        await load(container);
        final cycle = container.read(pomodoroCycleProvider.notifier);
        await cycle.startCycle(taskId: task.id);
        await completeCurrent(container);
        final shortBreak = await cycle.startNextSegment();
        expect(shortBreak.session.taskId, isNull);
        await completeCurrent(container);
        await TaskRepository(database).delete(task.id);

        final nextFocus = await cycle.startNextSegment();
        expect(nextFocus.session.taskId, isNull);
        expect(nextFocus.session.taskIdSnapshot, task.id);
        expect(nextFocus.session.taskTitleSnapshot, task.title);
      },
    );

    test('exit saves cancellation and suppresses cycle recovery', () async {
      final container = createContainer();
      addTearDown(container.dispose);
      await load(container);
      final started = await container
          .read(pomodoroCycleProvider.notifier)
          .startCycle();

      await container.read(pomodoroCycleProvider.notifier).exitCycle();

      expect(
        (await FocusRepository(
          database,
        ).getById(started.session.id))?.session.status,
        FocusSessionStatus.cancelled,
      );
      expect(await container.read(pomodoroCycleProvider.future), isNull);
      expect(await FocusRepository(database).getHistory(), hasLength(1));
    });

    test('running long break is recovered after process restart', () async {
      final container = createContainer();
      addTearDown(container.dispose);
      await load(container);
      final cycle = container.read(pomodoroCycleProvider.notifier);
      await cycle.startCycle();

      for (var round = 1; round <= 3; round++) {
        await completeCurrent(container);
        await cycle.startNextSegment();
        await completeCurrent(container);
        if (round < 3) {
          await cycle.startNextSegment();
        }
      }

      await cycle.startNextSegment();
      await completeCurrent(container);
      final longBreak = await cycle.startNextSegment();
      expect(longBreak.session.mode, FocusSessionMode.longBreak);
      expect(longBreak.session.status, FocusSessionStatus.running);

      container.dispose();

      final recovered = createContainer();
      addTearDown(recovered.dispose);
      await load(recovered);

      final recoveredSession = await recovered.read(
        focusSessionProvider.future,
      );
      expect(recoveredSession?.session.mode, FocusSessionMode.longBreak);
      expect(recoveredSession?.session.status, FocusSessionStatus.running);

      final recoveredCycle = await recovered.read(pomodoroCycleProvider.future);
      expect(recoveredCycle?.isActive, isTrue);
      expect(recoveredCycle?.round, 4);
      expect(recoveredCycle?.nextMode, isNull);
    });

    test('paused long break is recovered after process restart', () async {
      final container = createContainer();
      addTearDown(container.dispose);
      await load(container);
      final cycle = container.read(pomodoroCycleProvider.notifier);
      await cycle.startCycle();

      for (var round = 1; round <= 3; round++) {
        await completeCurrent(container);
        await cycle.startNextSegment();
        await completeCurrent(container);
        if (round < 3) {
          await cycle.startNextSegment();
        }
      }

      await cycle.startNextSegment();
      await completeCurrent(container);
      final longBreak = await cycle.startNextSegment();
      now = now.add(const Duration(seconds: 1));
      await container
          .read(focusSessionProvider.notifier)
          .pauseSession(longBreak.session.id);

      expect(
        (await container.read(focusSessionProvider.future))?.session.status,
        FocusSessionStatus.paused,
      );

      container.dispose();

      final recovered = createContainer();
      addTearDown(recovered.dispose);
      await load(recovered);

      final recoveredSession = await recovered.read(
        focusSessionProvider.future,
      );
      expect(recoveredSession?.session.mode, FocusSessionMode.longBreak);
      expect(recoveredSession?.session.status, FocusSessionStatus.paused);

      final recoveredCycle = await recovered.read(pomodoroCycleProvider.future);
      expect(recoveredCycle?.isActive, isTrue);
      expect(recoveredCycle?.round, 4);
    });

    test('completed long break marks cycle complete after restart', () async {
      final container = createContainer();
      addTearDown(container.dispose);
      await load(container);
      final cycle = container.read(pomodoroCycleProvider.notifier);
      await cycle.startCycle();

      for (var round = 1; round <= 3; round++) {
        await completeCurrent(container);
        await cycle.startNextSegment();
        await completeCurrent(container);
        if (round < 3) {
          await cycle.startNextSegment();
        }
      }

      await cycle.startNextSegment();
      await completeCurrent(container);
      final longBreak = await cycle.startNextSegment();
      now = now.add(const Duration(seconds: 1));
      await container
          .read(focusSessionProvider.notifier)
          .completeSession(longBreak.session.id);

      container.dispose();

      final recovered = createContainer();
      addTearDown(recovered.dispose);
      await load(recovered);

      final recoveredCycle = await recovered.read(pomodoroCycleProvider.future);
      expect(recoveredCycle?.isComplete, isTrue);
      expect(recoveredCycle?.nextMode, isNull);
      expect(recoveredCycle?.round, 4);
    });

    test(
      'running session recovered then completed produces one history entry',
      () async {
        final firstContainer = createContainer();
        await load(firstContainer);
        final cycle = firstContainer.read(pomodoroCycleProvider.notifier);
        final started = await cycle.startCycle();
        firstContainer.dispose();

        final recoveredContainer = createContainer();
        addTearDown(recoveredContainer.dispose);
        await load(recoveredContainer);

        final recovered = await recoveredContainer.read(
          focusSessionProvider.future,
        );
        expect(recovered?.session.id, started.session.id);
        expect(recovered?.session.status, FocusSessionStatus.running);

        now = now.add(const Duration(seconds: 1));
        await recoveredContainer
            .read(focusSessionProvider.notifier)
            .completeSession(started.session.id);

        final history = await FocusRepository(database).getHistory();
        expect(history, hasLength(1));
        expect(history.single.session.id, started.session.id);
        expect(history.single.session.status, FocusSessionStatus.completed);
      },
    );
  });
}

class _MemoryPomodoroSettingsStore extends PomodoroSettingsStore {
  PomodoroSettings? _settings;

  @override
  Future<PomodoroSettings> load() async => _settings ?? PomodoroSettings();

  @override
  Future<void> save(PomodoroSettings settings) async {
    _settings = settings;
  }

  @override
  Future<Set<String>> loadDismissedCycleIds() async =>
      _dismissedCycleIds.toSet();

  @override
  Future<void> dismissCycle(String cycleId) async {
    _dismissedCycleIds.add(cycleId);
  }

  final Set<String> _dismissedCycleIds = {};
}
