import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kairos_pager/app/shell.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/storage/pairing_store.dart';
import 'package:kairos_pager/features/alarm/alarm_takeover_screen.dart';
import 'package:kairos_pager/features/alerts/alerts_screen.dart';
import 'package:kairos_pager/features/chat/chat_screen.dart';
import 'package:kairos_pager/features/home/home_screen.dart';
import 'package:kairos_pager/features/pair/pair_screen.dart';
import 'package:kairos_pager/features/process/process_screen.dart';
import 'package:kairos_pager/features/reactor/reactor_detail_screen.dart';
import 'package:kairos_pager/features/reactors/reactors_screen.dart';
import 'package:kairos_pager/features/settings/settings_screen.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  final paired = ValueNotifier<Pairing?>(ref.read(pairingProvider));
  ref
    ..listen(pairingProvider, (_, next) => paired.value = next)
    ..onDispose(paired.dispose);

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/home',
    refreshListenable: paired,
    redirect: (context, state) {
      final atPair = state.matchedLocation == '/pair';
      if (paired.value == null) return atPair ? null : '/pair';
      if (atPair || state.matchedLocation == '/plant') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/pair', builder: (_, _) => const PairScreen()),
      GoRoute(path: '/plant', redirect: (_, _) => '/home'),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/reactors', builder: (_, _) => const ReactorsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/alerts', builder: (_, _) => const AlertsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/ask', builder: (_, _) => const ChatScreen(inTab: true))],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/profile', builder: (_, _) => const SettingsScreen())],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/reactor/:id',
        builder: (_, s) => ReactorDetailScreen(reactorId: s.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/alarm/:id',
        pageBuilder: (_, s) =>
            NoTransitionPage(child: AlarmTakeoverScreen(reactorId: s.pathParameters['id']!)),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/chat',
        builder: (_, s) => ChatScreen(reactorId: s.uri.queryParameters['reactor']),
      ),
      GoRoute(parentNavigatorKey: _rootKey, path: '/settings', redirect: (_, _) => '/profile'),
      GoRoute(parentNavigatorKey: _rootKey, path: '/process', builder: (_, _) => const ProcessScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
