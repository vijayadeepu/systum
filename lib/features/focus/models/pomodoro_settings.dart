final class PomodoroSettings {
  PomodoroSettings({
    this.focusMinutes = defaultFocusMinutes,
    this.shortBreakMinutes = defaultShortBreakMinutes,
    this.longBreakMinutes = defaultLongBreakMinutes,
  }) {
    _validate(focusMinutes, 'focusMinutes');
    _validate(shortBreakMinutes, 'shortBreakMinutes');
    _validate(longBreakMinutes, 'longBreakMinutes');
  }

  static const defaultFocusMinutes = 25;
  static const defaultShortBreakMinutes = 5;
  static const defaultLongBreakMinutes = 15;
  static const focusRoundsBeforeLongBreak = 4;
  static const minimumMinutes = 1;
  static const maximumMinutes = 1440;

  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;

  int durationForMinutes(int minutes) =>
      Duration(minutes: minutes).inMilliseconds;

  int get focusDurationMs => durationForMinutes(focusMinutes);
  int get shortBreakDurationMs => durationForMinutes(shortBreakMinutes);
  int get longBreakDurationMs => durationForMinutes(longBreakMinutes);

  static void _validate(int minutes, String name) {
    if (minutes < minimumMinutes || minutes > maximumMinutes) {
      throw ArgumentError.value(
        minutes,
        name,
        'Must be between $minimumMinutes and $maximumMinutes minutes.',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PomodoroSettings &&
          focusMinutes == other.focusMinutes &&
          shortBreakMinutes == other.shortBreakMinutes &&
          longBreakMinutes == other.longBreakMinutes;

  @override
  int get hashCode =>
      Object.hash(focusMinutes, shortBreakMinutes, longBreakMinutes);
}
