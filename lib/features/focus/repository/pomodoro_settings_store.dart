import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/pomodoro_settings.dart';

class PomodoroSettingsStore {
  static const _settingsKey = 'focus.pomodoro.settings.v1';
  static const _dismissedCyclesKey = 'focus.pomodoro.dismissed_cycles.v1';

  Future<PomodoroSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_settingsKey);
    if (stored == null) return PomodoroSettings();

    final decoded = jsonDecode(stored);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Stored Pomodoro settings are invalid.');
    }
    final focus = decoded['focusMinutes'];
    final shortBreak = decoded['shortBreakMinutes'];
    final longBreak = decoded['longBreakMinutes'];
    if (focus is! int || shortBreak is! int || longBreak is! int) {
      throw const FormatException('Stored Pomodoro settings are incomplete.');
    }
    return PomodoroSettings(
      focusMinutes: focus,
      shortBreakMinutes: shortBreak,
      longBreakMinutes: longBreak,
    );
  }

  Future<void> save(PomodoroSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _settingsKey,
      jsonEncode({
        'focusMinutes': settings.focusMinutes,
        'shortBreakMinutes': settings.shortBreakMinutes,
        'longBreakMinutes': settings.longBreakMinutes,
      }),
    );
    if (!saved) throw StateError('Could not save Pomodoro settings.');
  }

  Future<Set<String>> loadDismissedCycleIds() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_dismissedCyclesKey);
    if (stored == null) return {};
    final decoded = jsonDecode(stored);
    if (decoded is! List<dynamic> || decoded.any((value) => value is! String)) {
      throw const FormatException('Stored Pomodoro cycle exits are invalid.');
    }
    return decoded.cast<String>().toSet();
  }

  Future<void> dismissCycle(String cycleId) async {
    final preferences = await SharedPreferences.getInstance();
    final dismissed = await loadDismissedCycleIds();
    dismissed.add(cycleId);
    final saved = await preferences.setString(
      _dismissedCyclesKey,
      jsonEncode(dismissed.toList()..sort()),
    );
    if (!saved) throw StateError('Could not exit the Pomodoro cycle.');
  }
}
