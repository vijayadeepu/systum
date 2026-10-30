import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final focusSystemClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// A foreground display clock. It never writes time or duration to storage.
final focusClockProvider =
    NotifierProvider.autoDispose<FocusClockNotifier, DateTime>(
      FocusClockNotifier.new,
    );

class FocusClockNotifier extends Notifier<DateTime> {
  Timer? _timer;
  AppLifecycleListener? _lifecycleListener;

  @override
  DateTime build() {
    final now = ref.read(focusSystemClockProvider)();
    _lifecycleListener = AppLifecycleListener(onPause: _stop, onResume: _start);
    ref.onDispose(() {
      _stop();
      _lifecycleListener?.dispose();
    });
    _start(refreshState: false);
    return now;
  }

  void refresh() {
    state = ref.read(focusSystemClockProvider)();
  }

  void _start({bool refreshState = true}) {
    _stop();
    if (refreshState) refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => refresh());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }
}
