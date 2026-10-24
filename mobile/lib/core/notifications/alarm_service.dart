// ignore_for_file: unreachable_from_main (called from main.dart and app.dart)
import 'dart:async';
import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Keeps a live connection to the Kairos server in an Android foreground
/// service, so alarms reach the phone while the app is in the background, the
/// screen is off, or the app has been swiped away. The service runs in its own
/// isolate with its own WebSocket; it posts a heads-up alarm notification for
/// every new alarm unless the app is open (the app shows its takeover instead).
abstract final class AlarmService {
  static const _wsKey = 'kairos.ws';
  static const _fgKey = 'kairos.foreground';

  static void init() {
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'kairos_monitor',
        channelName: 'Kairos monitoring',
        channelDescription: 'Shown while Kairos watches your reactors for alarms',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(20000),
        autoRunOnMyPackageReplaced: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Start (or restart) monitoring [wsUri]. Asks for the permissions it needs.
  static Future<void> start(Uri wsUri) async {
    try {
      if (await FlutterForegroundTask.checkNotificationPermission() != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
      await FlutterForegroundTask.saveData(key: _wsKey, value: wsUri.toString());
      if (await FlutterForegroundTask.isRunningService) await FlutterForegroundTask.stopService();

      await FlutterForegroundTask.startService(
        serviceId: 4242,
        serviceTypes: [ForegroundServiceTypes.dataSync],
        notificationTitle: 'Kairos is watching your reactors',
        notificationText: 'Alarms will reach you even with the app closed',
        notificationIcon: const NotificationIcon(metaDataName: 'ai.kairos.NOTIFICATION_ICON'),
        callback: alarmServiceCallback,
      );
    } on Object {
      // Unsupported platform or permission refused: the in-app alarms still work.
    }
  }

  static Future<void> stop() async {
    try {
      await FlutterForegroundTask.stopService();
    } on Object {
      // Not running.
    }
  }

  /// Tell the service whether the app is on screen (it then stays quiet).
  static void setForeground({required bool foreground}) {
    unawaited(FlutterForegroundTask.saveData(key: _fgKey, value: foreground).catchError((Object _) => false));
    try {
      FlutterForegroundTask.sendDataToTask({'foreground': foreground});
    } on Object {
      // Service not running.
    }
  }
}

@pragma('vm:entry-point')
void alarmServiceCallback() {
  FlutterForegroundTask.setTaskHandler(_AlarmTaskHandler());
}

class _AlarmTaskHandler extends TaskHandler {
  final _notes = FlutterLocalNotificationsPlugin();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Uri? _uri;
  bool _foreground = false;
  bool _closing = false;
  int _attempt = 0;
  final _cards = <String, Map<String, dynamic>>{};
  final _alarmed = <String>{};

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'kairos_alarms',
      'Reactor alarms',
      channelDescription: 'Alarms from Kairos with the diagnosis and recommended action',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      ticker: 'Kairos alarm',
    ),
  );

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _notes.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('ic_stat_kairos')),
    );
    _foreground = await FlutterForegroundTask.getData<bool>(key: AlarmService._fgKey) ?? false;
    final ws = await FlutterForegroundTask.getData<String>(key: AlarmService._wsKey);
    if (ws == null) return;
    _uri = Uri.parse(ws);
    _connect();
  }

  void _connect() {
    final uri = _uri;
    if (uri == null || _closing) return;
    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _sub = channel.stream.listen(
        (raw) {
          _attempt = 0;
          _onMessage(raw as String);
        },
        onDone: _reconnect,
        onError: (Object _) => _reconnect(),
        cancelOnError: true,
      );
      channel.sink.add(jsonEncode({'type': 'subscribe', 'reactors': <String>[]}));
      _status('Live: watching every reactor');
    } on Object {
      _reconnect();
    }
  }

  void _reconnect() {
    if (_closing) return;
    unawaited(_sub?.cancel());
    _channel = null;
    _status('Reconnecting to the Kairos server…');
    final delay = Duration(seconds: [1, 2, 4, 8, 15, 30][_attempt.clamp(0, 5)]);
    _attempt++;
    Timer(delay, _connect);
  }

  void _status(String text) {
    unawaited(
      FlutterForegroundTask.updateService(
        notificationTitle: 'Kairos is watching your reactors',
        notificationText: text,
      ),
    );
  }

  void _onMessage(String raw) {
    final Map<String, dynamic> e;
    try {
      e = jsonDecode(raw) as Map<String, dynamic>;
    } on Object {
      return;
    }
    switch (e['type']) {
      case 'snapshot':
        for (final r in (e['reactors'] as List<dynamic>? ?? const [])) {
          final m = r as Map<String, dynamic>;
          if (m['state'] == 'alarm') _alarmed.add(m['id'] as String);
        }
      case 'alarm':
        final id = e['reactor_id'] as String;
        if (e['state'] == 'alarm') {
          if (_alarmed.add(id)) unawaited(_notify(id, e));
        } else {
          _alarmed.remove(id);
          unawaited(_notes.cancel(_noteId(id)));
        }
      case 'insight':
        final id = e['reactor_id'] as String;
        final card = e['card'] as Map<String, dynamic>?;
        if (card != null) {
          _cards[id] = card;
          // Upgrade the alarm notification with the copilot's diagnosis.
          if (_alarmed.contains(id) && !_foreground) unawaited(_notify(id, null));
        }
      case 'ack':
        final id = e['reactor_id'] as String;
        unawaited(_notes.cancel(_noteId(id)));
    }
  }

  int _noteId(String reactorId) => reactorId.hashCode & 0x7fffffff;

  Future<void> _notify(String reactorId, Map<String, dynamic>? alarm) async {
    if (_foreground) return;
    final card = _cards[reactorId];
    String title;
    String body;
    if (card != null) {
      title = '$reactorId: ${card['title']}';
      body = '${card['action']}';
    } else {
      final top = (alarm?['contributors'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
      final what = top.isEmpty ? 'process drift' : '${top.first['var']}'.replaceAll('_', ' ');
      title = '$reactorId: alarm';
      body = 'Kairos detected $what. Open for the diagnosis and the fix.';
    }
    final ponr = alarm?['ponr_hours'];
    if (ponr is num) body = '$body  ·  ${ponr.toStringAsFixed(0)} h to act';
    await _notes.show(_noteId(reactorId), title, body, _details, payload: reactorId);
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    try {
      _channel?.sink.add(jsonEncode({'type': 'ping'}));
    } on Object {
      _reconnect();
    }
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map && data['foreground'] is bool) _foreground = data['foreground'] as bool;
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp();

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _closing = true;
    await _sub?.cancel();
    await _channel?.sink.close();
  }
}
