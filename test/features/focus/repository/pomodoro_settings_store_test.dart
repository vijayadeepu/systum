import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:systum/features/focus/models/pomodoro_settings.dart';
import 'package:systum/features/focus/repository/pomodoro_settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads defaults when no local configuration exists', () async {
    final settings = await PomodoroSettingsStore().load();

    expect(settings, PomodoroSettings());
  });

  test(
    'persists custom settings and cycle exit across store instances',
    () async {
      final store = PomodoroSettingsStore();
      final custom = PomodoroSettings(
        focusMinutes: 30,
        shortBreakMinutes: 7,
        longBreakMinutes: 18,
      );
      await store.save(custom);
      await store.dismissCycle('cycle-1');

      expect(await PomodoroSettingsStore().load(), custom);
      expect(await PomodoroSettingsStore().loadDismissedCycleIds(), {
        'cycle-1',
      });
    },
  );

  test('rejects malformed or out-of-range stored settings', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'focus.pomodoro.settings.v1',
      '{"focusMinutes":0,"shortBreakMinutes":5,"longBreakMinutes":15}',
    );

    await expectLater(PomodoroSettingsStore().load(), throwsArgumentError);
  });
}
