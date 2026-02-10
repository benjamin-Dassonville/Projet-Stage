import 'package:go_router/go_router.dart';

import 'auth/auth_state.dart';
import 'auth/app_role.dart';

import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/team_page.dart';
import 'pages/worker_check_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/forbidden_page.dart';

import 'pages/team_control_page.dart';
import 'pages/control_team_page.dart';

import 'pages/calendar_page.dart';
import 'pages/calendar_team_page.dart';
import 'pages/calendar_worker_check_page.dart';

import 'pages/roles_manager_page.dart';

import 'pages/briefing_team_page.dart';

// ✅ Briefings ADMIN hub + pages
import 'pages/briefings_admin_page.dart';
import 'pages/briefings_topics_admin_page.dart';
import 'pages/briefings_required_day_admin_page.dart';
import 'pages/briefings_rules_admin_page.dart';

bool _isAllowed(AppRole? role, Set<AppRole> allowed) {
  if (role == null) return false;
  return allowed.contains(role);
}

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
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),

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

      GoRoute(
        path: '/',
        redirect: (_, __) => auth.role == null ? '/login' : null,
        builder: (_, __) => const HomePage(),
      ),

      GoRoute(
        path: '/teams/:teamId',
        redirect: (context, state) => _guard(auth, state, {AppRole.chef}),
        builder: (_, state) {
          final teamId = state.pathParameters['teamId']!;
          return TeamPage(teamId: teamId);
        },
      ),

      GoRoute(
        path: '/teams/:teamId/briefing',
        redirect: (context, state) => _guard(auth, state, {AppRole.chef}),
        builder: (_, state) {
          final teamId = state.pathParameters['teamId']!;
          final date = state.uri.queryParameters['date']; // optionnel (YYYY-MM-DD)
          return BriefingTeamPage(teamId: teamId, date: date);
        },
      ),

      GoRoute(
        path: '/workers/:workerId/check',
        redirect: (context, state) =>
            _guard(auth, state, {AppRole.chef, AppRole.admin}),
        builder: (_, state) {
          final workerId = state.pathParameters['workerId']!;
          return WorkerCheckPage(workerId: workerId);
        },
      ),

      GoRoute(
        path: '/dashboard',
        redirect: (context, state) => _guard(auth, state, {AppRole.admin}),
        builder: (_, __) => const DashboardPage(),
      ),

      // ✅ Calendrier contrôles : ADMIN + CHEF + DIRECTION
      GoRoute(
        path: '/calendar',
        redirect: (context, state) => _guard(auth, state, {
          AppRole.admin,
          AppRole.chef,
          AppRole.direction,
        }),
        builder: (_, __) => const CalendarPage(),
      ),

      GoRoute(
        path: '/calendar/teams/:teamId',
        redirect: (context, state) => _guard(auth, state, {
          AppRole.admin,
          AppRole.chef,
          AppRole.direction,
        }),
        builder: (_, state) {
          final teamId = state.pathParameters['teamId']!;
          final date = state.uri.queryParameters['date']; // YYYY-MM-DD
          return CalendarTeamPage(teamId: teamId, date: date);
        },
      ),

      GoRoute(
        path: '/calendar/workers/:workerId',
        redirect: (context, state) => _guard(auth, state, {
          AppRole.admin,
          AppRole.chef,
          AppRole.direction,
        }),
        builder: (_, state) {
          final workerId = state.pathParameters['workerId']!;
          final date = state.uri.queryParameters['date']; // YYYY-MM-DD
          return CalendarWorkerCheckPage(workerId: workerId, date: date);
        },
      ),

      // ✅ HUB: page avec les 3 cartes/boutons
      GoRoute(
        path: '/briefings/admin',
        redirect: (context, state) =>
            _guard(auth, state, {AppRole.admin, AppRole.direction}),
        builder: (_, __) => const BriefingsAdminPage(),
      ),

      // ✅ 1) Sujets
      GoRoute(
        path: '/briefings/admin/topics',
        redirect: (context, state) =>
            _guard(auth, state, {AppRole.admin, AppRole.direction}),
        builder: (_, __) => const BriefingsTopicsAdminPage(),
      ),

      // ✅ 2) Obligations par date
      GoRoute(
        path: '/briefings/admin/required-day',
        redirect: (context, state) =>
            _guard(auth, state, {AppRole.admin, AppRole.direction}),
        builder: (_, __) => const BriefingsRequiredDayAdminPage(),
      ),

      // ✅ 3) Règles récurrentes
      GoRoute(
        path: '/briefings/admin/rules',
        redirect: (context, state) =>
            _guard(auth, state, {AppRole.admin, AppRole.direction}),
        builder: (_, __) => const BriefingsRulesAdminPage(),
      ),

      GoRoute(
        path: '/roles',
        redirect: (context, state) => _guard(auth, state, {
          AppRole.admin,
          AppRole.chef,
          AppRole.direction,
        }),
        builder: (_, __) => const RolesManagerPage(),
      ),

      GoRoute(
        path: '/control-teams',
        redirect: (context, state) => _guard(auth, state, {
          AppRole.chef,
          AppRole.admin,
          AppRole.direction,
        }),
        builder: (_, __) => const TeamControlPage(),
      ),

      GoRoute(
        path: '/control-teams/:teamId',
        redirect: (context, state) => _guard(auth, state, {
          AppRole.chef,
          AppRole.admin,
          AppRole.direction,
        }),
        builder: (_, state) {
          final teamId = state.pathParameters['teamId']!;
          return ControlTeamPage(teamId: teamId);
        },
      ),
    ],
  );
}

GoRouter buildRouter(AuthState auth) => createRouter(auth);