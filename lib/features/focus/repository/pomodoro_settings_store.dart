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

  Future<Map<String, dynamic>> exportData() async {
    final preferences = await SharedPreferences.getInstance();
    final settings = await load();
    return {
      'pomodoroSettings': {
        'focusMinutes': settings.focusMinutes,
        'shortBreakMinutes': settings.shortBreakMinutes,
        'longBreakMinutes': settings.longBreakMinutes,
      },
      'dismissedCycleIds':
          (preferences.getString(_dismissedCyclesKey) == null
                ? <String>[]
                : (await loadDismissedCycleIds()).toList()
            ..sort()),
    };
  }

  Future<void> importData(Map<String, dynamic> data) async {
    final settingsData = data['pomodoroSettings'];
    final dismissedData = data['dismissedCycleIds'];
    if (settingsData is! Map<String, dynamic> ||
        dismissedData is! List<dynamic> ||
        dismissedData.any((value) => value is! String)) {
      throw const FormatException('Pomodoro backup data is invalid.');
    }
    final settings = PomodoroSettings(
      focusMinutes: settingsData['focusMinutes'] as int,
      shortBreakMinutes: settingsData['shortBreakMinutes'] as int,
      longBreakMinutes: settingsData['longBreakMinutes'] as int,
    );
    final preferences = await SharedPreferences.getInstance();
    final settingsSaved = await preferences.setString(
      _settingsKey,
      jsonEncode({
        'focusMinutes': settings.focusMinutes,
        'shortBreakMinutes': settings.shortBreakMinutes,
        'longBreakMinutes': settings.longBreakMinutes,
      }),
    );
    final dismissedSaved = await preferences.setString(
      _dismissedCyclesKey,
      jsonEncode(dismissedData.cast<String>()..sort()),
    );
    if (!settingsSaved || !dismissedSaved) {
      throw StateError('Could not restore Pomodoro settings.');
    }
  }
}
