import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/goals/screens/goal_detail_page.dart';
import '../features/goals/screens/goal_list_page.dart';
import '../features/focus/screens/focus_page.dart';
import '../features/focus/screens/focus_history_page.dart';
import '../features/home/home_page.dart';
import '../features/hydration/screens/hydration_details_page.dart';
import '../features/hydration/screens/hydration_settings_page.dart';
import '../features/settings/screens/settings_page.dart';
import '../features/tasks/screens/daily_agenda_page.dart';
import '../features/tasks/screens/task_detail_page.dart';
import '../core/backup/backup_page.dart';
import '../core/backup/selective_portability_page.dart';
import '../core/diagnostics/diagnostics_page.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// Page shown when a route does not match any known destination.
class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_rounded, size: 56),
            const SizedBox(height: AppSpacing.md),
            Text('This screen is not available.', style: AppTypography.title),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Use the navigation below to return to your tasks.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to tasks'),
            ),
          ],
        ),
      ),
    );
  }
}

final appRouter = GoRouter(
  initialLocation: '/',
  // Redirect unknown paths to home so users never hit a dead end.
  redirect: (context, state) {
    final uri = state.uri;
    final known = <String>{
      '/',
      '/focus',
      '/focus/history',
      '/backup',
      '/backup/portability',
      '/diagnostics',
      '/goals',
      '/agenda',
      '/calendar',
      '/hydration',
      '/settings',
    };
    if (known.contains(uri.path)) return null;
    if (uri.path.startsWith('/goal/') || uri.path.startsWith('/task/')) {
      return null;
    }
    return '/';
  },
  // Show a not-found page for any route that fails to build.
  errorBuilder: (context, state) => const _NotFoundPage(),
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomePage()),
    GoRoute(
      path: '/focus',
      builder: (context, state) =>
          FocusPage(initialTaskId: state.uri.queryParameters['taskId']),
    ),
    GoRoute(
      path: '/focus/history',
      builder: (context, state) => const FocusHistoryPage(),
    ),
    GoRoute(path: '/backup', builder: (context, state) => const BackupPage()),
    GoRoute(
      path: '/backup/portability',
      builder: (context, state) => const SelectivePortabilityPage(),
    ),
    GoRoute(
      path: '/diagnostics',
      builder: (context, state) => const DiagnosticsPage(),
    ),
    GoRoute(path: '/goals', builder: (context, state) => const GoalListPage()),
    GoRoute(
      path: '/goal/:goalId',
      builder: (context, state) =>
          GoalDetailPage(goalId: state.pathParameters['goalId']!),
    ),
    GoRoute(
      path: '/task/:taskId',
      builder: (context, state) =>
          TaskDetailPage(taskId: state.pathParameters['taskId']!),
    ),
    GoRoute(
      path: '/agenda',
      builder: (context, state) => const DailyAgendaPage(),
    ),
    GoRoute(
      path: '/calendar',
      builder: (context, state) => const MonthCalendarPage(),
    ),
    GoRoute(
      path: '/hydration',
      builder: (context, state) => const HydrationDetailsPage(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/settings/hydration',
      builder: (context, state) => const HydrationSettingsPage(),
    ),
  ],
);
