import 'package:go_router/go_router.dart';

import 'auth/auth_state.dart';
import 'auth/app_role.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/team_page.dart';
import 'pages/worker_check_page.dart';
import 'pages/dashboard_page.dart';

GoRouter buildRouter(AuthState auth) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: auth,
    redirect: (context, state) {
      // Wait for persisted role to load.
      if (!auth.ready) {
        return state.matchedLocation == '/login' ? null : '/login';
      }

      final loggedIn = auth.isLoggedIn;
      final goingToLogin = state.matchedLocation == '/login';

      if (!loggedIn) {
        return goingToLogin ? null : '/login';
      }
      if (goingToLogin) return '/';

      // Simple role-based access
      final role = auth.role;
      if (state.matchedLocation.startsWith('/dashboard')) {
        final allowed = role == AppRole.admin || role == AppRole.direction;
        if (!allowed) return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const HomePage(),
        routes: [
          GoRoute(
            path: 'teams/:teamId',
            builder: (_, state) => TeamPage(teamId: state.pathParameters['teamId']!),
          ),
          GoRoute(
            path: 'workers/:workerId/check',
            builder: (_, state) => WorkerCheckPage(workerId: state.pathParameters['workerId']!),
          ),
          GoRoute(
            path: 'dashboard',
            builder: (_, __) => const DashboardPage(),
          ),
        ],
      ),
    ],
  );
}
