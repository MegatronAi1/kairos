import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kairos_pager/app/router.dart';
import 'package:kairos_pager/core/fleet_providers.dart';
import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/notifications/alarm_alerts.dart';
import 'package:kairos_pager/core/notifications/alarm_service.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/storage/pairing_store.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/theme_pref.dart';
import 'package:kairos_pager/core/theme/tokens.dart';

class KairosApp extends ConsumerStatefulWidget {
  const KairosApp({super.key});

  @override
  ConsumerState<KairosApp> createState() => _KairosAppState();
}

class _KairosAppState extends ConsumerState<KairosApp> with WidgetsBindingObserver {
  late final AppLifecycleListener _lifecycle;
  bool _foreground = true;
  String? _showingAlarmFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycle = AppLifecycleListener(
      onStateChange: (s) {
        _foreground = s == AppLifecycleState.resumed;
        AlarmService.setForeground(foreground: _foreground);
      },
    );
    AlarmAlerts.instance.onTapReactor = (id) => ref.read(routerProvider).push('/alarm/$id');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncService(ref.read(pairingProvider));
      final launched = AlarmAlerts.instance.launchReactor;
      if (launched != null) {
        AlarmAlerts.instance.launchReactor = null;
        unawaited(ref.read(routerProvider).push('/alarm/$launched'));
      }
    });
  }

  /// Background alarms: a foreground service keeps its own live connection
  /// while signed in to a real server (not in offline demo mode).
  bool _serviceOn = false;

  void _syncService(Pairing? p) {
    final want = p != null && !p.demo;
    if (want) {
      _serviceOn = true;
      unawaited(AlarmService.start(p.wsUri).then((_) => AlarmService.setForeground(foreground: _foreground)));
    } else if (_serviceOn) {
      _serviceOn = false;
      unawaited(AlarmService.stop());
    }
  }

  @override
  void didChangePlatformBrightness() => setState(() {});

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    } else if (!_serviceOn) {
      final card = ref.read(reactorProvider(e.reactorId))?.insight?.card;
      final plant = ref.read(plantOfReactorProvider(e.reactorId));
      fireAndForget(
        AlarmAlerts.instance.notify(
          reactorId: e.reactorId,
          title: '${plant == null ? e.reactorId : '${plant.name} ${e.reactorId}'}: ${card?.title ?? 'Alarm'}',
          body: card?.action ?? 'Open Kairos for the diagnosis.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(pairingProvider, (_, next) => _syncService(next))
      ..listen(alarmEventsProvider, (_, next) {
        final e = next.value;
        if (e != null) _onAlarm(e);
      })
      // Keep the reactor fold alive app-wide so no event is missed between screens.
      ..watch(reactorsProvider)
      ..watch(alertsProvider);
    final mode = ref.watch(themeModeProvider);
    final platform = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final brightness = switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => platform,
    };
    // Widgets read KColors at build time; switching the palette and keying the app
    // on brightness rebuilds every screen with the new colours.
    KColors.palette = brightness == Brightness.light ? KPalette.light : KPalette.dark;
    final theme = kairosTheme(brightness);
    return MaterialApp.router(
      key: ValueKey(brightness),
      title: 'Kairos Pager',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: brightness == Brightness.light ? ThemeMode.light : ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
