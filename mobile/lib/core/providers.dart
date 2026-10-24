import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kairos_pager/core/api/kairos_api.dart';
import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/models/plant.dart';
import 'package:kairos_pager/core/storage/pairing_store.dart';
import 'package:kairos_pager/core/ws/event_source.dart';

final pairingStoreProvider = Provider<PairingStore>((ref) => PairingStore());

/// Pairing loaded from secure storage before `runApp`; overridden in main.
final initialPairingProvider = Provider<Pairing?>((ref) => null);

class PairingNotifier extends Notifier<Pairing?> {
  @override
  Pairing? build() => ref.read(initialPairingProvider);

  Future<void> pair(Pairing p) async {
    await ref.read(pairingStoreProvider).save(p);
    state = p;
  }

  Future<void> unpair() async {
    await ref.read(pairingStoreProvider).clear();
    state = null;
  }
}

final pairingProvider = NotifierProvider<PairingNotifier, Pairing?>(PairingNotifier.new);

final apiProvider = Provider<KairosApi?>((ref) {
  final p = ref.watch(pairingProvider);
  return p == null ? null : KairosApi(p);
});

final eventSourceProvider = Provider<EventSource?>((ref) {
  final p = ref.watch(pairingProvider);
  if (p == null) return null;
  final source = p.demo ? MockEventSource() : WsEventSource(p.wsUri);
  ref.onDispose(source.dispose);
  source.start();
  return source;
});

final connectionStatusProvider = StreamProvider<ConnectionStatus>((ref) {
  final source = ref.watch(eventSourceProvider);
  return source?.status ?? Stream.value(ConnectionStatus.offline);
});

/// Alarm transitions only; drives the takeover and notifications.
final alarmEventsProvider = StreamProvider<AlarmEvent>((ref) {
  final source = ref.watch(eventSourceProvider);
  if (source == null) return const Stream.empty();
  return source.frames
      .where((f) => f is EventFrame && f.event is AlarmEvent)
      .map((f) => (f as EventFrame).event as AlarmEvent);
});

/// Live view of one reactor slot, folded from snapshot + events.
class ReactorView {
  const ReactorView({
    required this.id,
    required this.batchId,
    required this.strategy,
    required this.isFaultBatch,
    required this.state,
    required this.acknowledged,
    this.plantId = '',
    this.tick,
    this.insight,
    this.lastAlarm,
    this.recent = const [],
  });

  factory ReactorView.fromSummary(ReactorSummary s) => ReactorView(
    id: s.id,
    plantId: s.plantId,
    batchId: s.batchId,
    strategy: s.strategy,
    isFaultBatch: s.isFaultBatch,
    state: s.state,
    acknowledged: s.acknowledged,
    tick: s.lastTick,
    insight: s.lastInsight,
    recent: [if (s.lastTick != null) s.lastTick!],
  );

  static const historyLength = 120;

  final String id;
  final String plantId;
  final int batchId;
  final String strategy;
  final bool isFaultBatch;
  final HealthState state;
  final bool acknowledged;
  final TickEvent? tick;
  final InsightEvent? insight;
  final AlarmEvent? lastAlarm;
  final List<TickEvent> recent;

  /// Short name inside its plant ("R2" for "PUN-R2").
  String get shortId => id.contains('-') ? id.substring(id.lastIndexOf('-') + 1) : id;

  String get strategyLabel => switch (strategy) {
    'recipe' => 'Recipe-driven',
    'operator' => 'Operator-controlled',
    'pat' => 'Raman PAT-controlled',
    'fault' => 'Fault batch',
    _ => strategy,
  };

  ReactorView copyWith({
    int? batchId,
    HealthState? state,
    bool? acknowledged,
    TickEvent? tick,
    InsightEvent? insight,
    AlarmEvent? lastAlarm,
    List<TickEvent>? recent,
  }) => ReactorView(
    id: id,
    plantId: plantId,
    batchId: batchId ?? this.batchId,
    strategy: strategy,
    isFaultBatch: isFaultBatch,
    state: state ?? this.state,
    acknowledged: acknowledged ?? this.acknowledged,
    tick: tick ?? this.tick,
    insight: insight ?? this.insight,
    lastAlarm: lastAlarm ?? this.lastAlarm,
    recent: recent ?? this.recent,
  );

  /// Hours of batch time left before the point of no return, if an alarm set one.
  double? get ponrRemainingH {
    final a = lastAlarm;
    final t = tick;
    if (a?.ponrHours == null || t == null || state == HealthState.normal) return null;
    return (a!.ponrHours! - (t.tH - a.tH)).clamp(0, double.infinity).toDouble();
  }
}

class ReactorsNotifier extends Notifier<Map<String, ReactorView>> {
  @override
  Map<String, ReactorView> build() {
    final source = ref.watch(eventSourceProvider);
    if (source == null) return const {};
    final sub = source.frames.listen(_onFrame);
    ref.onDispose(sub.cancel);
    return const {};
  }

  void _onFrame(Frame frame) {
    switch (frame) {
      case SnapshotFrame(:final reactors):
        state = {for (final r in reactors) r.id: ReactorView.fromSummary(r)};
      case EventFrame(:final event):
        final current = state[event.reactorId];
        if (current == null) return;
        state = {...state, event.reactorId: _apply(current, event)};
    }
  }

  ReactorView _apply(ReactorView r, KEvent e) => switch (e) {
    TickEvent() => r.copyWith(
      tick: e,
      batchId: e.batchId,
      recent: [
        ...r.recent.length >= ReactorView.historyLength
            ? r.recent.skip(r.recent.length - ReactorView.historyLength + 1)
            : r.recent,
        e,
      ],
    ),
    AlarmEvent() => r.copyWith(
      state: e.state,
      lastAlarm: e,
      acknowledged: e.state != HealthState.alarm && r.acknowledged,
    ),
    InsightEvent() => r.copyWith(insight: e),
    AckEvent() => r.copyWith(acknowledged: true),
  };

  Future<void> acknowledge(String id) async {
    final r = state[id];
    if (r != null) state = {...state, id: r.copyWith(acknowledged: true)};
    await ref.read(apiProvider)?.acknowledge(id);
  }
}

final reactorsProvider = NotifierProvider<ReactorsNotifier, Map<String, ReactorView>>(ReactorsNotifier.new);

final reactorProvider = Provider.family<ReactorView?, String>((ref, id) => ref.watch(reactorsProvider)[id]);

/// Unawaited helper for fire-and-forget UI calls.
void fireAndForget(Future<void> f) => unawaited(f.catchError((Object _) {}));

/// Energy recommendation per (reactor, 30 s bucket, state): refreshes every ~30 s of
/// screen time and whenever the reactor changes state.
final recommendationProvider =
    FutureProvider.family<EnergyRecommendation?, ({String id, int bucket, HealthState state})>((
      ref,
      key,
    ) async {
      final api = ref.watch(apiProvider);
      if (api == null) return null;
      return api.recommendation(key.id, rescue: key.state == HealthState.alarm);
    });

int recommendationBucket() => DateTime.now().millisecondsSinceEpoch ~/ 30000;

/// Plants of the signed-in company; refreshes every 20 s while watched.
final plantsProvider = FutureProvider<List<PlantSummary>>((ref) async {
  final api = ref.watch(apiProvider);
  if (api == null) return const [];
  final timer = Timer(const Duration(seconds: 20), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return api.plants();
});

/// The plant a reactor belongs to, if known.
final plantOfReactorProvider = Provider.family<PlantSummary?, String>((ref, reactorId) {
  final plants = ref.watch(plantsProvider).value ?? const [];
  final plantId = ref.watch(reactorProvider(reactorId))?.plantId ?? '';
  for (final p in plants) {
    if (p.id == plantId || p.reactorIds.contains(reactorId)) return p;
  }
  return null;
});
