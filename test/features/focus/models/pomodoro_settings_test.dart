import 'package:flutter_test/flutter_test.dart';
import 'package:systum/features/focus/models/pomodoro_settings.dart';

void main() {
  test('uses expected default durations and round count', () {
    final settings = PomodoroSettings();

    expect(settings.focusMinutes, 25);
    expect(settings.shortBreakMinutes, 5);
    expect(settings.longBreakMinutes, 15);
    expect(PomodoroSettings.focusRoundsBeforeLongBreak, 4);
  });

  test('accepts custom durations within supported bounds', () {
    final settings = PomodoroSettings(
      focusMinutes: 50,
      shortBreakMinutes: 10,
      longBreakMinutes: 20,
    );

    expect(
      settings.focusDurationMs,
      const Duration(minutes: 50).inMilliseconds,
    );
    expect(
      settings.shortBreakDurationMs,
      const Duration(minutes: 10).inMilliseconds,
    );
    expect(
      settings.longBreakDurationMs,
      const Duration(minutes: 20).inMilliseconds,
    );
  });

  test('rejects zero, negative, and unreasonable durations', () {
    expect(() => PomodoroSettings(focusMinutes: 0), throwsArgumentError);
    expect(() => PomodoroSettings(shortBreakMinutes: -1), throwsArgumentError);
    expect(() => PomodoroSettings(longBreakMinutes: 1441), throwsArgumentError);
  });
}
