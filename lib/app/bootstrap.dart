import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:logger/logger.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../features/reminders/notifications/local_reminder_notification_scheduler.dart';
import 'android_intent.dart';
import 'app.dart';
import 'router.dart';

const _androidIntentChannel = MethodChannel('com.systum.app/android_intent');

/// The [ProviderContainer] exposing Riverpod to the app. Held so the Android
/// intent method channel can write pending intents from outside a widget build
/// (for example, during cold start).
late final ProviderContainer _intentContainer;

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeTimeZones();
  _setupAndroidIntentChannel();

  final scheduler = LocalReminderNotificationScheduler();
  try {
    await scheduler.initialize(onTap: _openReminderTask);
  } catch (error, stackTrace) {
    // Notification delivery is not allowed to prevent the app from starting.
    Logger().w(
      'Reminder notifications could not be initialized.',
      error: error,
      stackTrace: stackTrace,
    );
  }

  _intentContainer = ProviderContainer();
  // Deliver any intent buffered by the native channel during cold start.
  flushPendingIntent(_intentContainer);

  runApp(
    UncontrolledProviderScope(
      container: _intentContainer,
      child: const SystumApp(),
    ),
  );
}

Future<void> _initializeTimeZones() async {
  tzdata.initializeTimeZones();
  try {
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
  } catch (error, stackTrace) {
    // Keep the UTC fallback. Absolute one-time reminders are unaffected; only
    // device-local recurring wall-clock schedules would lose the zone.
    Logger().w(
      'Could not resolve the device timezone.',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Receives Android intents (launcher shortcuts, deep links, shares) from the
/// native side and buffers them into [androidIntentProvider] for UI handling.
void _setupAndroidIntentChannel() {
  _androidIntentChannel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'deepLink':
        bufferPendingIntent(AndroidIntent.deepLink(call.arguments as String));
      case 'sharedText':
        bufferPendingIntent(AndroidIntent.shareText(call.arguments as String));
    }
    return null;
  });
}

void _openReminderTask(String taskId) {
  appRouter.go('/task/${Uri.encodeComponent(taskId)}');
}
