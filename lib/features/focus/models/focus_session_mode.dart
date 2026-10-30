enum FocusSessionMode {
  standard,
  pomodoro,
  shortBreak,
  longBreak,
  custom;

  bool get isBreak => this == shortBreak || this == longBreak;
}
