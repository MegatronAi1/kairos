import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/storage/pairing_store.dart';
import 'package:kairos_pager/features/alarm/alarm_takeover_screen.dart';
import 'package:kairos_pager/features/chat/chat_screen.dart';
import 'package:kairos_pager/features/pair/pair_screen.dart';
import 'package:kairos_pager/features/plant/plant_screen.dart';
import 'package:kairos_pager/features/process/process_screen.dart';
import 'package:kairos_pager/features/reactor/reactor_detail_screen.dart';
import 'package:kairos_pager/features/settings/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final paired = ValueNotifier<Pairing?>(ref.read(pairingProvider));
  ref
    ..listen(pairingProvider, (_, next) => paired.value = next)
    ..onDispose(paired.dispose);

  final router = GoRouter(
    initialLocation: '/plant',
    refreshListenable: paired,
    redirect: (context, state) {
      final atPair = state.matchedLocation == '/pair';
      if (paired.value == null) return atPair ? null : '/pair';
      return atPair ? '/plant' : null;
    },
    routes: [
      GoRoute(path: '/pair', builder: (_, _) => const PairScreen()),
      GoRoute(path: '/plant', builder: (_, _) => const PlantScreen()),
      GoRoute(
        path: '/reactor/:id',
        builder: (_, s) => ReactorDetailScreen(reactorId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/alarm/:id',
        pageBuilder: (_, s) =>
            NoTransitionPage(child: AlarmTakeoverScreen(reactorId: s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/chat',
        builder: (_, s) => ChatScreen(reactorId: s.uri.queryParameters['reactor']),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/process', builder: (_, _) => const ProcessScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
