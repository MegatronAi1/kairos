import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:kairos_pager/core/models/models.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum ConnectionStatus { connecting, live, offline }

sealed class Frame {
  const Frame();
}

class SnapshotFrame extends Frame {
  const SnapshotFrame(this.reactors);
  final List<ReactorSummary> reactors;
}

class EventFrame extends Frame {
  const EventFrame(this.event);
  final KEvent event;
}

/// A live stream of server frames plus connection status.
abstract class EventSource {
  Stream<Frame> get frames;
  Stream<ConnectionStatus> get status;
  void start();
  Future<void> dispose();
}

/// WebSocket source with exponential-backoff reconnect.
class WsEventSource implements EventSource {
  WsEventSource(this.uri);

  final Uri uri;
  final _frames = StreamController<Frame>.broadcast();
  final _status = StreamController<ConnectionStatus>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  Timer? _ping;
  int _attempt = 0;
  bool _disposed = false;

  @override
  Stream<Frame> get frames => _frames.stream;

  @override
  Stream<ConnectionStatus> get status => _status.stream;

  @override
  void start() => unawaited(_connect());

  Future<void> _connect() async {
    if (_disposed) return;
    _status.add(ConnectionStatus.connecting);
    try {
      final channel = WebSocketChannel.connect(uri);
      await channel.ready.timeout(const Duration(seconds: 5));
      _channel = channel;
      _attempt = 0;
      _status.add(ConnectionStatus.live);
      channel.sink.add(jsonEncode({'type': 'subscribe', 'reactors': <String>[]}));
      _ping = Timer.periodic(const Duration(seconds: 20), (_) {
        channel.sink.add(jsonEncode({'type': 'ping'}));
      });
      _sub = channel.stream.listen(_onMessage, onDone: _scheduleRetry, onError: (_) => _scheduleRetry());
    } on Object {
      _scheduleRetry();
    }
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    final json = jsonDecode(raw) as Json;
    if (json['type'] == 'snapshot') {
      final list = (json['reactors'] as List).map((e) => ReactorSummary.fromJson(e as Json)).toList();
      _frames.add(SnapshotFrame(list));
      return;
    }
    final event = KEvent.fromJson(json);
    if (event != null) _frames.add(EventFrame(event));
  }

  void _scheduleRetry() {
    _ping?.cancel();
    unawaited(_sub?.cancel());
    _channel = null;
    if (_disposed) return;
    _status.add(ConnectionStatus.offline);
    final delay = Duration(milliseconds: math.min(10000, 500 * (1 << math.min(_attempt, 5))));
    _attempt++;
    _retry?.cancel();
    _retry = Timer(delay, _connect);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _retry?.cancel();
    _ping?.cancel();
    await _sub?.cancel();
    await _channel?.sink.close();
    await _frames.close();
    await _status.close();
  }
}

/// Offline demo stream: R2 drifts into an oxygen-limitation alarm at ~71 h.
/// Used for UI work and as a venue fallback. Clearly labelled "Demo data".
class MockEventSource implements EventSource {
  MockEventSource({this.hoursPerSecond = 2});

  final double hoursPerSecond;
  final _frames = StreamController<Frame>.broadcast();
  final _status = StreamController<ConnectionStatus>.broadcast();
  final _rand = math.Random(7);
  final Map<String, HealthState> _state = {};
  Timer? _timer;
  double _t = 40;

  static const _slots = {'R1': 22, 'R2': 91, 'R3': 46, 'R4': 74};
  static const _strategy = {'R1': 'recipe', 'R2': 'fault', 'R3': 'operator', 'R4': 'pat'};

  @override
  Stream<Frame> get frames => _frames.stream;

  @override
  Stream<ConnectionStatus> get status => _status.stream;

  @override
  void start() {
    Future<void>.delayed(Duration.zero, () {
      _status.add(ConnectionStatus.live);
      _frames.add(
        SnapshotFrame([
          for (final e in _slots.entries)
            ReactorSummary(
              id: e.key,
              batchId: e.value,
              strategy: _strategy[e.key]!,
              isFaultBatch: e.value >= 91,
              running: true,
              state: HealthState.normal,
              acknowledged: false,
              tEndH: 230,
            ),
        ]),
      );
    });
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
  }

  double _noise(double scale) => (_rand.nextDouble() - 0.5) * scale;

  void _tick() {
    _t += hoursPerSecond / 2;
    if (_t > 230) _t = 40;
    final ts = DateTime.now().millisecondsSinceEpoch;
    for (final e in _slots.entries) {
      final id = e.key;
      final drift = id == 'R2' ? math.max(0, _t - 60) : 0.0;
      final doPct = 62 - drift * 2.2 + _noise(1.5);
      final score = (96 - drift * 4.5 + _noise(2)).clamp(5, 100).toDouble();
      final state = score < 45 ? HealthState.alarm : (score < 70 ? HealthState.watch : HealthState.normal);
      final p50 = 31 - drift * 0.35 + (id == 'R3' ? -4 : 0);
      final progress = (_t / 230).clamp(0, 1).toDouble();
      final contributors = drift > 0
          ? const [
              Contribution(variable: 'do_pct', pct: 46, low: true),
              Contribution(variable: 'feed', pct: 28, low: false),
              Contribution(variable: 'our', pct: 14, low: false),
            ]
          : const <Contribution>[];
      _frames.add(
        EventFrame(
          TickEvent(
            reactorId: id,
            ts: ts,
            tH: _t,
            progress: progress,
            batchId: e.value,
            sensors: {
              'do_pct': doPct,
              'ph': 6.5 + _noise(0.04) - drift * 0.004,
              'temp_c': 25 + _noise(0.1),
              'rpm': 100,
              'aeration': 60,
              'feed': 80 + drift * 0.3,
              'co2_offgas_pct': 0.8 + _noise(0.05),
              'o2_offgas_pct': 19.9 + _noise(0.1),
            },
            derived: {
              'our': 0.99 + _noise(0.05),
              'power_kw': id == 'R4' ? 121 : 141 + _noise(2),
              'kwh_cum': _t * 140,
            },
            forecast: Forecast(
              p50: p50,
              p10: p50 - 3,
              p90: p50 + 2.7,
              unit: 'g/L',
              vsGoldenPct: 100 * p50 / 31,
              confidence: Confidence.medium,
              provenance: Provenance.synthetic,
            ),
            health: Health(score: score, state: state, topContributors: contributors),
          ),
        ),
      );
      final prev = _state[id] ?? HealthState.normal;
      if (state != prev) {
        _state[id] = state;
        _frames
          ..add(
            EventFrame(
              AlarmEvent(
                reactorId: id,
                ts: ts,
                tH: _t,
                progress: progress,
                batchId: e.value,
                state: state,
                previousState: prev,
                severity: state == HealthState.alarm ? 'critical' : 'warning',
                contributors: contributors,
                ponrHours: state == HealthState.normal ? null : 4.5,
              ),
            ),
          )
          ..add(
            EventFrame(
              InsightEvent(
                reactorId: id,
                ts: ts,
                tH: _t,
                progress: progress,
                batchId: e.value,
                fromAgent: false,
                card: InsightCard(
                  title: state == HealthState.normal ? '$id back to normal' : 'Oxygen limitation developing',
                  summary: state == HealthState.normal
                      ? 'Health score is back inside normal limits.'
                      : 'Dissolved oxygen is falling while sugar feed stays high. Demo data.',
                  action: state == HealthState.normal ? 'No action needed.' : 'Reduce sugar feed 10% for 3 h',
                  expectedEffect: state == HealthState.normal ? 'None' : '+6 to +11% final yield',
                  confidence: Confidence.medium,
                  ponrHours: state == HealthState.normal ? null : 4.5,
                  evidence: const ['fault_detector', 'yield_model'],
                ),
              ),
            ),
          );
      }
    }
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    await _frames.close();
    await _status.close();
  }
}
