import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/models/plant.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/ws/event_source.dart';

// ---------------------------------------------------------------------------
// Fleet roll-up

class FleetCounts {
  const FleetCounts({
    required this.total,
    required this.alarm,
    required this.watch,
    required this.healthy,
    required this.openAlarms,
    required this.powerKw,
  });

  final int total;
  final int alarm;
  final int watch;
  final int healthy;

  /// Alarms not yet acknowledged.
  final int openAlarms;
  final double powerKw;

  int get needAttention => alarm + watch;
}

final fleetCountsProvider = Provider<FleetCounts>((ref) {
  final rs = ref.watch(reactorsProvider).values;
  return FleetCounts(
    total: rs.length,
    alarm: rs.where((r) => r.state == HealthState.alarm).length,
    watch: rs.where((r) => r.state == HealthState.watch).length,
    healthy: rs.where((r) => r.state == HealthState.normal).length,
    openAlarms: rs.where((r) => r.state == HealthState.alarm && !r.acknowledged).length,
    powerKw: rs.fold(0, (a, r) => a + (r.tick?.derived['power_kw'] ?? 0)),
  );
});

/// Urgency rank: unacknowledged alarm, acknowledged alarm, watch, healthy.
int urgencyRank(ReactorView r) => switch (r.state) {
  HealthState.alarm => r.acknowledged ? 1 : 0,
  HealthState.watch => 2,
  HealthState.normal => 3,
};

/// Worst state across a plant's reactors.
HealthState worstState(Iterable<ReactorView> rs) => rs.any((r) => r.state == HealthState.alarm)
    ? HealthState.alarm
    : rs.any((r) => r.state == HealthState.watch)
    ? HealthState.watch
    : HealthState.normal;

// ---------------------------------------------------------------------------
// Reactor list filters

enum ReactorSort {
  urgency('Urgency'),
  health('Health score'),
  yieldPct('Yield vs typical'),
  plant('Plant');

  const ReactorSort(this.label);
  final String label;
}

class ReactorFilter {
  const ReactorFilter({
    this.query = '',
    this.state,
    this.plantId,
    this.sort = ReactorSort.urgency,
    this.groupByPlant = false,
  });

  final String query;
  final HealthState? state;
  final String? plantId;
  final ReactorSort sort;
  final bool groupByPlant;

  bool get isActive => query.isNotEmpty || state != null || plantId != null;

  ReactorFilter copyWith({
    String? query,
    HealthState? Function()? state,
    String? Function()? plantId,
    ReactorSort? sort,
    bool? groupByPlant,
  }) => ReactorFilter(
    query: query ?? this.query,
    state: state != null ? state() : this.state,
    plantId: plantId != null ? plantId() : this.plantId,
    sort: sort ?? this.sort,
    groupByPlant: groupByPlant ?? this.groupByPlant,
  );
}

class ReactorFilterNotifier extends Notifier<ReactorFilter> {
  @override
  ReactorFilter build() => const ReactorFilter();

  void setQuery(String q) => state = state.copyWith(query: q);
  void setState(HealthState? s) => state = state.copyWith(state: () => s);
  void setPlant(String? id) => state = state.copyWith(plantId: () => id);
  void setSort(ReactorSort s) => state = state.copyWith(sort: s);
  void toggleGroup() => state = state.copyWith(groupByPlant: !state.groupByPlant);
  void reset() => state = ReactorFilter(sort: state.sort, groupByPlant: state.groupByPlant);
}

final reactorFilterProvider = NotifierProvider<ReactorFilterNotifier, ReactorFilter>(
  ReactorFilterNotifier.new,
);

/// Reactors after search, state and plant filters, in the chosen order.
final filteredReactorsProvider = Provider<List<ReactorView>>((ref) {
  final f = ref.watch(reactorFilterProvider);
  final plants = {for (final p in ref.watch(plantsProvider).value ?? const <PlantSummary>[]) p.id: p};
  final q = f.query.trim().toLowerCase();
  final list = ref.watch(reactorsProvider).values.where((r) {
    if (f.state != null && r.state != f.state) return false;
    if (f.plantId != null && r.plantId != f.plantId) return false;
    if (q.isEmpty) return true;
    final p = plants[r.plantId];
    return r.id.toLowerCase().contains(q) ||
        (p?.name.toLowerCase().contains(q) ?? false) ||
        (p?.city.toLowerCase().contains(q) ?? false) ||
        (p?.processName.toLowerCase().contains(q) ?? false);
  }).toList();
  int byId(ReactorView a, ReactorView b) => a.id.compareTo(b.id);
  switch (f.sort) {
    case ReactorSort.urgency:
      list.sort((a, b) {
        final c = urgencyRank(a).compareTo(urgencyRank(b));
        return c != 0 ? c : byId(a, b);
      });
    case ReactorSort.health:
      list.sort((a, b) => (a.tick?.health?.score ?? 101).compareTo(b.tick?.health?.score ?? 101));
    case ReactorSort.yieldPct:
      list.sort(
        (a, b) => (a.tick?.forecast?.vsGoldenPct ?? 999).compareTo(b.tick?.forecast?.vsGoldenPct ?? 999),
      );
    case ReactorSort.plant:
      list.sort((a, b) {
        final c = (plants[a.plantId]?.name ?? a.plantId).compareTo(plants[b.plantId]?.name ?? b.plantId);
        return c != 0 ? c : byId(a, b);
      });
  }
  return list;
});

// ---------------------------------------------------------------------------
// Alerts inbox

class AlertItem {
  const AlertItem({
    required this.reactorId,
    required this.state,
    required this.at,
    required this.tH,
    this.batchId = 0,
    this.ponrHours,
    this.acknowledged = false,
    this.resolved = false,
  });

  final String reactorId;
  final HealthState state;
  final DateTime at;
  final double tH;
  final int batchId;
  final double? ponrHours;
  final bool acknowledged;

  /// The reactor went back to normal (or a new batch started).
  final bool resolved;

  bool get open => !acknowledged && !resolved;

  AlertItem copyWith({bool? acknowledged, bool? resolved}) => AlertItem(
    reactorId: reactorId,
    state: state,
    at: at,
    tH: tH,
    batchId: batchId,
    ponrHours: ponrHours,
    acknowledged: acknowledged ?? this.acknowledged,
    resolved: resolved ?? this.resolved,
  );
}

/// Alarm and watch transitions seen this session, newest first. Seeded from the
/// snapshot so alarms already open when the app starts are listed too.
class AlertsNotifier extends Notifier<List<AlertItem>> {
  static const maxItems = 60;

  @override
  List<AlertItem> build() {
    final source = ref.watch(eventSourceProvider);
    if (source == null) return const [];
    final sub = source.frames.listen(_onFrame);
    ref.onDispose(sub.cancel);
    return const [];
  }

  void _onFrame(Frame frame) {
    switch (frame) {
      case SnapshotFrame(:final reactors):
        final seeded = [
          for (final r in reactors)
            if (r.state != HealthState.normal && !state.any((a) => a.reactorId == r.id && !a.resolved))
              AlertItem(
                reactorId: r.id,
                state: r.state,
                at: DateTime.now(),
                tH: r.lastTick?.tH ?? 0,
                batchId: r.batchId,
                acknowledged: r.acknowledged,
              ),
        ];
        if (seeded.isNotEmpty) state = [...seeded, ...state];
      case EventFrame(event: final AlarmEvent e):
        final rest = [
          for (final a in state) a.reactorId == e.reactorId && !a.resolved ? a.copyWith(resolved: true) : a,
        ];
        state = e.state == HealthState.normal
            ? rest
            : [
                AlertItem(
                  reactorId: e.reactorId,
                  state: e.state,
                  at: DateTime.fromMillisecondsSinceEpoch(e.ts),
                  tH: e.tH,
                  batchId: e.batchId,
                  ponrHours: e.ponrHours,
                ),
                ...rest,
              ].take(maxItems).toList();
      case EventFrame(event: final TickEvent e):
        // A new batch (loop, restart, simulated fault) closes that reactor's old alerts.
        final stale = state.any(
          (a) => a.reactorId == e.reactorId && !a.resolved && (a.batchId != e.batchId || e.tH + 0.5 < a.tH),
        );
        if (stale) {
          state = [
            for (final a in state)
              a.reactorId == e.reactorId && !a.resolved && (a.batchId != e.batchId || e.tH + 0.5 < a.tH)
                  ? a.copyWith(resolved: true)
                  : a,
          ];
        }
      case EventFrame(event: final AckEvent e):
        _markAck(e.reactorId);
      case EventFrame():
        break;
    }
  }

  void _markAck(String reactorId) => state = [
    for (final a in state) a.reactorId == reactorId && !a.resolved ? a.copyWith(acknowledged: true) : a,
  ];

  Future<void> acknowledge(String reactorId) async {
    _markAck(reactorId);
    await ref.read(reactorsProvider.notifier).acknowledge(reactorId);
  }
}

final alertsProvider = NotifierProvider<AlertsNotifier, List<AlertItem>>(AlertsNotifier.new);

enum AlertView {
  open('Open'),
  acknowledged('Acknowledged'),
  all('All');

  const AlertView(this.label);
  final String label;
}

class AlertFilter {
  const AlertFilter({this.view = AlertView.open, this.severity, this.plantId});

  final AlertView view;
  final HealthState? severity;
  final String? plantId;
}

class AlertFilterNotifier extends Notifier<AlertFilter> {
  @override
  AlertFilter build() => const AlertFilter();

  void setView(AlertView v) => state = AlertFilter(view: v, severity: state.severity, plantId: state.plantId);
  void setSeverity(HealthState? s) =>
      state = AlertFilter(view: state.view, severity: s, plantId: state.plantId);
  void setPlant(String? p) => state = AlertFilter(view: state.view, severity: state.severity, plantId: p);
}

final alertFilterProvider = NotifierProvider<AlertFilterNotifier, AlertFilter>(AlertFilterNotifier.new);

final filteredAlertsProvider = Provider<List<AlertItem>>((ref) {
  final f = ref.watch(alertFilterProvider);
  final reactors = ref.watch(reactorsProvider);
  return ref.watch(alertsProvider).where((a) {
    final ok = switch (f.view) {
      AlertView.open => a.open,
      AlertView.acknowledged => a.acknowledged,
      AlertView.all => true,
    };
    if (!ok) return false;
    if (f.severity != null && a.state != f.severity) return false;
    if (f.plantId != null && reactors[a.reactorId]?.plantId != f.plantId) return false;
    return true;
  }).toList();
});

/// Badge count for the Alerts tab.
final openAlertCountProvider = Provider<int>((ref) => ref.watch(alertsProvider).where((a) => a.open).length);
