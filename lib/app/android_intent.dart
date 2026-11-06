import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The kind of Android intent that brought the user to Systum.
enum AndroidIntentType { deepLink, shareText }

/// A pending Android intent (launcher shortcut, deep link, or share) awaiting
/// handling by the UI layer.
///
/// The native side buffers the intent until the Flutter engine is ready, then
/// delivers it through a method channel. This provider holds the delivered
/// value until the UI consumes and clears it.
class AndroidIntent {
  const AndroidIntent._(this.type, this.value);

  final AndroidIntentType type;
  final String value;

  factory AndroidIntent.deepLink(String uri) =>
      AndroidIntent._(AndroidIntentType.deepLink, uri);

  factory AndroidIntent.shareText(String text) =>
      AndroidIntent._(AndroidIntentType.shareText, text);
}

/// Holds the most recently delivered Android intent. Only one intent is
/// remembered at a time; handling a new intent replaces the previous one.
class AndroidIntentNotifier extends Notifier<AndroidIntent?> {
  AndroidIntentNotifier();

  @override
  AndroidIntent? build() => null;

  void handleDeepLink(String uri) => state = AndroidIntent.deepLink(uri);

  void handleShareText(String text) => state = AndroidIntent.shareText(text);

  /// Clears the pending intent after the UI has acted on it.
  void clear() => state = null;
}

/// Intent buffered by the native channel before the provider container exists,
/// then flushed into [androidIntentProvider] during bootstrap (cold start).
AndroidIntent? _pendingIntent;

/// Stores an intent delivered by the native channel prior to container
/// creation. Flushed into the provider by [flushPendingIntent].
void bufferPendingIntent(AndroidIntent intent) {
  _pendingIntent = intent;
}

/// Flushes any buffered intent into [androidIntentProvider]. Called from
/// [bootstrap] after the [ProviderContainer] is created.
void flushPendingIntent(ProviderContainer container) {
  final pending = _pendingIntent;
  if (pending == null) return;
  _pendingIntent = null;
  final notifier = container.read(androidIntentProvider.notifier);
  switch (pending.type) {
    case AndroidIntentType.deepLink:
      notifier.handleDeepLink(pending.value);
    case AndroidIntentType.shareText:
      notifier.handleShareText(pending.value);
  }
}

/// Pending Android intent delivered from the platform (launcher shortcut,
/// deep link, or share). The UI layer watches this provider and navigates or
/// opens flows accordingly.
final androidIntentProvider =
    NotifierProvider<AndroidIntentNotifier, AndroidIntent?>(
      AndroidIntentNotifier.new,
    );

/// The destination parsed from a `systum://app/...` deep-link URI.
enum DeepLinkIntentType { createTask, agenda, task, goal, focus, unknown }

/// The parsed destination of a deep link, or [DeepLinkIntentType.unknown]
/// when the URI does not match a known Systum destination.
class DeepLinkIntent {
  const DeepLinkIntent(this.type, [this.id]);

  final DeepLinkIntentType type;
  final String? id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeepLinkIntent && type == other.type && id == other.id;

  @override
  int get hashCode => Object.hash(type, id);
}

/// Parses a `systum://app/...` deep-link URI into a [DeepLinkIntent].
///
/// Returns [DeepLinkIntentType.unknown] for malformed or unsupported URIs so
/// callers can fall back to a safe no-op rather than crashing.
DeepLinkIntent parseDeepLinkUri(String uri) {
  final segments = Uri.parse(uri).pathSegments;
  if (Uri.parse(uri).host != 'app' || segments.isEmpty) {
    return const DeepLinkIntent(DeepLinkIntentType.unknown);
  }
  switch (segments[0]) {
    case 'shortcut':
      if (segments.length >= 2) {
        switch (segments[1]) {
          case 'create-task':
            return const DeepLinkIntent(DeepLinkIntentType.createTask);
          case 'agenda':
            return const DeepLinkIntent(DeepLinkIntentType.agenda);
        }
      }
      return const DeepLinkIntent(DeepLinkIntentType.unknown);
    case 'tasks':
      if (segments.length >= 2) {
        return DeepLinkIntent(DeepLinkIntentType.task, segments[1]);
      }
      return const DeepLinkIntent(DeepLinkIntentType.unknown);
    case 'goals':
      if (segments.length >= 2) {
        return DeepLinkIntent(DeepLinkIntentType.goal, segments[1]);
      }
      return const DeepLinkIntent(DeepLinkIntentType.unknown);
    case 'agenda':
      return const DeepLinkIntent(DeepLinkIntentType.agenda);
    case 'focus':
      return const DeepLinkIntent(DeepLinkIntentType.focus);
    default:
      return const DeepLinkIntent(DeepLinkIntentType.unknown);
  }
}
