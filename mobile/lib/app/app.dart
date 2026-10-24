import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kairos_pager/app/router.dart';
import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/notifications/alarm_alerts.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';

class KairosApp extends ConsumerStatefulWidget {
  const KairosApp({super.key});

  @override
  ConsumerState<KairosApp> createState() => _KairosAppState();
}

class _KairosAppState extends ConsumerState<KairosApp> {
  late final AppLifecycleListener _lifecycle;
  bool _foreground = true;
  String? _showingAlarmFor;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (s) => _foreground = s == AppLifecycleState.resumed,
    );
    AlarmAlerts.instance.onTapReactor = (id) => ref.read(routerProvider).push('/alarm/$id');
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Alarm takeover straight from the socket event: no REST round-trip, so it
  /// lands well inside the 1 s budget.
  void _onAlarm(AlarmEvent e) {
    if (e.state != HealthState.alarm) {
      if (_showingAlarmFor == e.reactorId) _showingAlarmFor = null;
      return;
    }
    final router = ref.read(routerProvider);
    if (_foreground) {
      if (_showingAlarmFor != e.reactorId) {
        _showingAlarmFor = e.reactorId;
        unawaited(router.push('/alarm/${e.reactorId}'));
      }
      fireAndForget(AlarmAlerts.instance.buzz());
    } else {
      final card = ref.read(reactorProvider(e.reactorId))?.insight?.card;
      fireAndForget(
        AlarmAlerts.instance.notify(
          reactorId: e.reactorId,
          title: '${e.reactorId}: ${card?.title ?? 'Alarm'}',
          body: card?.action ?? 'Open Kairos for the diagnosis.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(alarmEventsProvider, (_, next) {
        final e = next.value;
        if (e != null) _onAlarm(e);
      })
      // Keep the reactor fold alive app-wide so no event is missed between screens.
      ..watch(reactorsProvider);
    return MaterialApp.router(
      title: 'Kairos Pager',
      debugShowCheckedModeBanner: false,
      theme: kairosTheme(),
      darkTheme: kairosTheme(),
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
