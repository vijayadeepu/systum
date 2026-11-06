import 'package:go_router/go_router.dart';

import '../features/goals/screens/goal_detail_page.dart';
import '../features/goals/screens/goal_list_page.dart';
import '../features/focus/screens/focus_page.dart';
import '../features/focus/screens/focus_history_page.dart';
import '../features/home/home_page.dart';
import '../features/tasks/screens/daily_agenda_page.dart';
import '../features/tasks/screens/task_detail_page.dart';
import '../core/backup/backup_page.dart';
import '../core/backup/selective_portability_page.dart';
import '../core/diagnostics/diagnostics_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
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
  ],
);
