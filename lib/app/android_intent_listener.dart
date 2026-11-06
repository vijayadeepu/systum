import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'android_intent.dart';
import '../features/tasks/widgets/create_task_dialog.dart';

/// Listens for Android intents delivered from the platform (launcher
/// shortcuts, deep links, shares) and translates them into existing app
/// navigation or task-creation flows.
///
/// The listener is a passive entry point: it never mutates persistence
/// directly and always reuses the existing routes and widgets.
class AndroidIntentListener extends ConsumerStatefulWidget {
  const AndroidIntentListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AndroidIntentListener> createState() =>
      _AndroidIntentListenerState();
}

class _AndroidIntentListenerState extends ConsumerState<AndroidIntentListener> {
  /// The last intent that was handed to the UI, so a cleared-and-re-set value
  /// is not handled twice across rebuilds.
  AndroidIntent? _lastHandled;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final intent = ref.watch(androidIntentProvider);
    if (intent == null) {
      _lastHandled = null;
      return widget.child;
    }
    if (intent != _lastHandled) {
      _lastHandled = intent;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handleIntent(intent);
        ref.read(androidIntentProvider.notifier).clear();
      });
    }
    return widget.child;
  }

  void _handleIntent(AndroidIntent intent) {
    switch (intent.type) {
      case AndroidIntentType.deepLink:
        _handleDeepLink(intent.value);
      case AndroidIntentType.shareText:
        _handleShareText(intent.value);
    }
  }

  void _handleDeepLink(String uri) {
    final intent = parseDeepLinkUri(uri);
    switch (intent.type) {
      case DeepLinkIntentType.createTask:
        _openCreateTaskDialog();
      case DeepLinkIntentType.agenda:
        context.go('/agenda');
      case DeepLinkIntentType.task:
        if (intent.id != null) {
          context.go('/task/${intent.id}');
        }
      case DeepLinkIntentType.goal:
        if (intent.id != null) {
          context.go('/goal/${intent.id}');
        }
      case DeepLinkIntentType.focus:
        context.go('/focus');
      case DeepLinkIntentType.unknown:
        break;
    }
  }

  void _handleShareText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    context.go('/');
    _openCreateTaskDialog(initialTitle: trimmed);
  }

  void _openCreateTaskDialog({String? initialTitle}) {
    showDialog<CreateTaskResult>(
      context: context,
      builder: (_) => CreateTaskDialog(initialTitle: initialTitle),
    );
  }
}
