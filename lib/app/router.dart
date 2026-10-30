import 'package:go_router/go_router.dart';

import '../features/goals/screens/goal_detail_page.dart';
import '../features/goals/screens/goal_list_page.dart';
import '../features/home/home_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomePage()),
    GoRoute(path: '/goals', builder: (context, state) => const GoalListPage()),
    GoRoute(
      path: '/goal/:goalId',
      builder: (context, state) =>
          GoalDetailPage(goalId: state.pathParameters['goalId']!),
    ),
  ],
);
