import 'package:go_router/go_router.dart';

import 'auth/auth_state.dart';
import 'auth/app_role.dart';

import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/team_page.dart';
import 'pages/worker_check_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/forbidden_page.dart';

// ✅ Liste des équipes (page “Contrôle équipes”)
import 'pages/team_control_page.dart';

// ✅ Gestion d’UNE équipe (gestion workers)
import 'pages/control_team_page.dart';

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
        redirect: (_, __) => auth.role == null ? '/login' : null,
        builder: (_, __) => const HomePage(),
      ),

      // ✅ Teams (page “équipe” classique) : UNIQUEMENT CHEF
      // (admin n'a plus accès au contrôle équipement/abs via cette page)
      GoRoute(
        path: '/teams/:teamId',
        redirect: (context, state) => _guard(
          auth,
          state,
          {AppRole.chef},
        ),
        builder: (_, state) {
          final teamId = state.pathParameters['teamId']!;
          return TeamPage(teamId: teamId);
        },
      ),

      // Worker check : chef + admin (tu peux resserrer si besoin)
      GoRoute(
        path: '/workers/:workerId/check',
        redirect: (context, state) => _guard(
          auth,
          state,
          {AppRole.chef, AppRole.admin},
        ),
        builder: (_, state) {
          final workerId = state.pathParameters['workerId']!;
          return WorkerCheckPage(workerId: workerId);
        },
      ),

      // ✅ Dashboard : UNIQUEMENT ADMIN
      GoRoute(
        path: '/dashboard',
        redirect: (context, state) => _guard(
          auth,
          state,
          {AppRole.admin},
        ),
        builder: (_, __) => const DashboardPage(),
      ),

      // ✅ Control teams (LISTE des équipes) : chef + admin + direction
      GoRoute(
        path: '/control-teams',
        redirect: (context, state) => _guard(
          auth,
          state,
          {AppRole.chef, AppRole.admin, AppRole.direction},
        ),
        builder: (_, __) => const TeamControlPage(),
      ),

      // ✅ Control team (DÉTAIL / gestion d'une équipe) : chef + admin + direction
      GoRoute(
        path: '/control-teams/:teamId',
        redirect: (context, state) => _guard(
          auth,
          state,
          {AppRole.chef, AppRole.admin, AppRole.direction},
        ),
        builder: (_, state) {
          final teamId = state.pathParameters['teamId']!;
          return ControlTeamPage(teamId: teamId);
        },
      ),
    ],
  );
}

/// IMPORTANT:
/// ton main.dart appelle `buildRouter(auth)`.
GoRouter buildRouter(AuthState auth) => createRouter(auth);