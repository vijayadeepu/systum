import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final goalSystemClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Publishes local calendar-day changes at midnight and when the app resumes.
final goalClockProvider = NotifierProvider<GoalClockNotifier, DateTime>(
  GoalClockNotifier.new,
);

class GoalClockNotifier extends Notifier<DateTime> {
  Timer? _midnightTimer;
  AppLifecycleListener? _lifecycleListener;

  @override
  DateTime build() {
    final now = ref.read(goalSystemClockProvider)();
    _lifecycleListener = AppLifecycleListener(
      onPause: _cancelMidnightTimer,
      onResume: _refresh,
    );
    ref.onDispose(() {
      _midnightTimer?.cancel();
      _lifecycleListener?.dispose();
    });
    _scheduleNextMidnight(now);
    return now;
  }

  void _refresh() {
    final now = ref.read(goalSystemClockProvider)();
    state = now;
    _scheduleNextMidnight(now);
  }

  void _scheduleNextMidnight(DateTime now) {
    _midnightTimer?.cancel();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now), _refresh);
  }

  void _cancelMidnightTimer() {
    _midnightTimer?.cancel();
    _midnightTimer = null;
  }
}
