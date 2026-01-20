import 'package:go_router/go_router.dart';

import 'auth/auth_state.dart';
import 'auth/app_role.dart';

import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/team_page.dart';
import 'pages/worker_check_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/forbidden_page.dart';

bool _isAllowed(AppRole? role, Set<AppRole> allowed) {
  if (role == null) return false;
  return allowed.contains(role);
}

/// Guard générique : 
/// - si pas connecté -> /login
/// - si rôle interdit -> /forbidden?from=...
String? _guard(AuthState auth, GoRouterState state, Set<AppRole> allowed) {
  final role = auth.role;

  if (role == null) return '/login';

  if (!_isAllowed(role, allowed)) {
    return '/forbidden?from=${Uri.encodeComponent(state.uri.toString())}';
  }

  return null;
}

GoRouter createRouter(AuthState auth) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: auth,

    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginPage(),
      ),

      GoRoute(
        path: '/forbidden',
        builder: (_, state) {
          final from = state.uri.queryParameters['from'];
          return ForbiddenPage(
            message: from == null
                ? "Vous n'avez pas les droits."
                : "Accès refusé pour: $from",
          );
        },
      ),

      // HOME : n'importe quel rôle connecté
      GoRoute(
        path: '/',
        redirect: (context, state) => auth.role == null ? '/login' : null,
        builder: (_, __) => const HomePage(),
      ),

      // Teams : chef + admin + direction
      GoRoute(
        path: '/teams/:teamId',
        redirect: (context, state) => _guard(
          auth,
          state,
          {AppRole.chef, AppRole.admin, AppRole.direction},
        ),
        builder: (_, state) {
          final teamId = state.pathParameters['teamId']!;
          return TeamPage(teamId: teamId);
        },
      ),

      // Worker check : chef + admin
      GoRoute(
        path: '/workers/:workerId/check',
        builder: (context, state) {
          final workerId = state.pathParameters['workerId']!;
          return WorkerCheckPage(workerId: workerId);
        },
      ),

      // Dashboard : direction + admin
      GoRoute(
        path: '/dashboard',
        redirect: (context, state) => _guard(
          auth,
          state,
          {AppRole.direction, AppRole.admin},
        ),
        builder: (_, __) => const DashboardPage(),
      ),
    ],
  );
}

/// IMPORTANT:
/// ton main.dart appelle `buildRouter(auth)`.
/// On force donc buildRouter à être un alias du router sécurisé.
GoRouter buildRouter(AuthState auth) => createRouter(auth);