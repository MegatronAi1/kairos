import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Haptics, sound and local notifications for alarms.
class AlarmAlerts {
  AlarmAlerts._();

  static final instance = AlarmAlerts._();

  final _notifications = FlutterLocalNotificationsPlugin();
  final _player = AudioPlayer();
  void Function(String reactorId)? onTapReactor;

  /// Reactor whose alarm notification launched the app (cold start), if any.
  String? launchReactor;
  bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'kairos_alarms',
    'Reactor alarms',
    channelDescription: 'Alarms from Kairos with the diagnosis and recommended action',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
    fullScreenIntent: true,
  );

  Future<void> init() async {
    if (_ready) return;
    try {
      await _notifications.initialize(
        const InitializationSettings(android: AndroidInitializationSettings('ic_stat_kairos')),
        onDidReceiveNotificationResponse: (r) {
          final id = r.payload;
          if (id != null && id.isNotEmpty) onTapReactor?.call(id);
        },
      );
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      final launch = await _notifications.getNotificationAppLaunchDetails();
      final payload = launch?.notificationResponse?.payload;
      if ((launch?.didNotificationLaunchApp ?? false) && payload != null && payload.isNotEmpty) {
        launchReactor = payload;
      }
      await _player.setReleaseMode(ReleaseMode.stop);
      _ready = true;
    } on Object {
      // Tests and unsupported platforms: alerts degrade to silent.
    }
  }

  /// One strong haptic pattern plus the chime. Called on foreground takeover.
  Future<void> buzz() async {
    unawaited(_player.play(AssetSource('sounds/alarm.wav')).catchError((Object _) {}));
    for (var i = 0; i < 3; i++) {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 140));
    }
    await HapticFeedback.vibrate();
  }

  Future<void> notify({required String reactorId, required String title, required String body}) async {
    if (!_ready) return;
    await _notifications.show(
      reactorId.hashCode & 0x7fffffff,
      title,
      body,
      const NotificationDetails(android: _channel),
      payload: reactorId,
    );
  }
}
