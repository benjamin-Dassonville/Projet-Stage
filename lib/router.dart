import 'package:go_router/go_router.dart';
import 'package:projet_stage/pages/briefing_team_detail_page.dart';
import 'package:projet_stage/pages/briefings_overview_page.dart';

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

import 'pages/briefings_admin_page.dart';
import 'pages/briefings_topics_admin_page.dart';
import 'pages/briefings_required_day_admin_page.dart';
import 'pages/briefings_rules_admin_page.dart';

import 'pages/waiting_page.dart';
import 'pages/account_roles_admin_page.dart';

bool _isAllowed(AppRole role, Set<AppRole> allowed) {
  return allowed.contains(role);
}

String? _guard(AuthState auth, GoRouterState state, Set<AppRole> allowed) {
  if (!auth.isLoggedIn) return '/login';

  final role = auth.role;

  if (role == AppRole.nonAssigne) {
    return '/waiting';
  }

  if (!_isAllowed(role, allowed)) {
    return '/forbidden?from=${Uri.encodeComponent(state.uri.toString())}';
  }

  return null;
}

GoRouter createRouter(AuthState auth) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: auth,

    redirect: (context, state) {
      if (!auth.ready) return null;

      final loc = state.uri.toString();
      final isLogin = loc.startsWith('/login');
      final isWaiting = loc.startsWith('/waiting');
      final isForbidden = loc.startsWith('/forbidden');

      if (!auth.isLoggedIn) {
        return isLogin ? null : '/login';
      }

      if (auth.role == AppRole.nonAssigne) {
        if (isWaiting || isForbidden) return null;
        return '/waiting';
      }

      if (isLogin) return '/';
      return null;
    },

    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),

      GoRoute(path: '/waiting', builder: (_, __) => const WaitingPage()),

      GoRoute(
        path: '/admin/account-roles',
        redirect: (context, state) =>
            _guard(auth, state, {AppRole.admin, AppRole.direction}),
        builder: (_, __) => const AccountRolesAdminPage(),
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

      GoRoute(path: '/', builder: (_, __) => const HomePage()),

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
          final date = state.uri.queryParameters['date'];
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
        redirect: (context, state) =>
            _guard(auth, state, {AppRole.admin}),
        builder: (_, __) => const DashboardPage(),
      ),

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
          final date = state.uri.queryParameters['date'];
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
          final date = state.uri.queryParameters['date'];
          return CalendarWorkerCheckPage(workerId: workerId, date: date);
        },
      ),

      GoRoute(
        path: '/briefings/admin',
        redirect: (context, state) =>
            _guard(auth, state, {AppRole.admin, AppRole.direction}),
        builder: (_, __) => const BriefingsAdminPage(),
      ),

      GoRoute(
        path: '/briefings/admin/topics',
        redirect: (context, state) =>
            _guard(auth, state, {AppRole.admin, AppRole.direction}),
        builder: (_, __) => const BriefingsTopicsAdminPage(),
      ),

      GoRoute(
        path: '/briefings/admin/required-day',
        redirect: (context, state) =>
            _guard(auth, state, {AppRole.admin, AppRole.direction}),
        builder: (_, __) => const BriefingsRequiredDayAdminPage(),
      ),

      GoRoute(
        path: '/briefings/admin/rules',
        redirect: (context, state) =>
            _guard(auth, state, {AppRole.admin, AppRole.direction}),
        builder: (_, __) => const BriefingsRecurringRulesAdminPage(),
      ),

      GoRoute(
        path: '/briefings/overview',
        builder: (context, state) => const BriefingsOverviewPage(),
      ),

      GoRoute(
        path: '/briefings/team/:teamId',
        builder: (context, state) {
          final teamId = state.pathParameters['teamId']!;
          final day =
              state.uri.queryParameters['day'] ??
              DateTime.now().toIso8601String().substring(0, 10);
          return BriefingTeamDetailPage(teamId: teamId, day: day);
        },
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