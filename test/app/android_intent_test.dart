import 'package:flutter_test/flutter_test.dart';
import 'package:systum/app/android_intent.dart';

void main() {
  group('parseDeepLinkUri', () {
    test('launcher shortcut: create task', () {
      expect(
        parseDeepLinkUri('systum://app/shortcut/create-task'),
        const DeepLinkIntent(DeepLinkIntentType.createTask),
      );
    });

    test('launcher shortcut: open agenda', () {
      expect(
        parseDeepLinkUri('systum://app/shortcut/agenda'),
        const DeepLinkIntent(DeepLinkIntentType.agenda),
      );
    });

    test('task deep link carries the task id', () {
      expect(
        parseDeepLinkUri('systum://app/tasks/abc-123'),
        const DeepLinkIntent(DeepLinkIntentType.task, 'abc-123'),
      );
    });

    test('goal deep link carries the goal id', () {
      expect(
        parseDeepLinkUri('systum://app/goals/goal-9'),
        const DeepLinkIntent(DeepLinkIntentType.goal, 'goal-9'),
      );
    });

    test('agenda deep link', () {
      expect(
        parseDeepLinkUri('systum://app/agenda'),
        const DeepLinkIntent(DeepLinkIntentType.agenda),
      );
    });

    test('focus deep link', () {
      expect(
        parseDeepLinkUri('systum://app/focus'),
        const DeepLinkIntent(DeepLinkIntentType.focus),
      );
    });

    test('unsupported host is unknown', () {
      expect(
        parseDeepLinkUri('systum://other/app'),
        const DeepLinkIntent(DeepLinkIntentType.unknown),
      );
    });

    test('unknown path is unknown', () {
      expect(
        parseDeepLinkUri('systum://app/nothing'),
        const DeepLinkIntent(DeepLinkIntentType.unknown),
      );
    });

    test('missing path segment is unknown', () {
      expect(
        parseDeepLinkUri('systum://app/tasks'),
        const DeepLinkIntent(DeepLinkIntentType.unknown),
      );
    });

    test('non-systum scheme is unknown', () {
      expect(
        parseDeepLinkUri('https://example.com/tasks/1'),
        const DeepLinkIntent(DeepLinkIntentType.unknown),
      );
    });

    test('empty uri is unknown', () {
      expect(
        parseDeepLinkUri(''),
        const DeepLinkIntent(DeepLinkIntentType.unknown),
      );
    });
  });
}
