// Wire models mirroring backend/app/schemas.py (see docs/API.md).
// Hand-written (see docs/DECISIONS.md); contract-tested against test/fixtures.

enum HealthState {
  normal,
  watch,
  alarm;

  static HealthState parse(Object? v) =>
      HealthState.values.firstWhere((s) => s.name == v, orElse: () => HealthState.normal);
}

enum Confidence {
  low,
  medium,
  high;

  static Confidence parse(Object? v) =>
      Confidence.values.firstWhere((c) => c.name == v, orElse: () => Confidence.low);
}

enum Provenance {
  measured,
  published,
  assumed,
  synthetic,
  fitted;

  static Provenance parse(Object? v) =>
      Provenance.values.firstWhere((p) => p.name == v, orElse: () => Provenance.assumed);
}

typedef Json = Map<String, dynamic>;

double? _d(Object? v) => v is num ? v.toDouble() : null;
double _d0(Object? v) => v is num ? v.toDouble() : 0;

Map<String, double?> _numMap(Object? v) => {
  for (final e in ((v as Map?) ?? const {}).entries) e.key as String: _d(e.value),
};

class Contribution {
  const Contribution({required this.variable, required this.pct, required this.low});

  factory Contribution.fromJson(Json j) =>
      Contribution(variable: j['var'] as String, pct: _d0(j['pct']), low: j['dir'] == 'low');

  final String variable;
  final double pct;
  final bool low;
}

class Forecast {
  const Forecast({
    required this.p50,
    required this.p10,
    required this.p90,
    required this.unit,
    required this.vsGoldenPct,
    required this.confidence,
    required this.provenance,
  });

  factory Forecast.fromJson(Json j) => Forecast(
    p50: _d0(j['p50']),
    p10: _d0(j['p10']),
    p90: _d0(j['p90']),
    unit: j['unit'] as String? ?? '',
    vsGoldenPct: _d0(j['vs_golden_pct']),
    confidence: Confidence.parse(j['confidence']),
    provenance: Provenance.parse(j['provenance']),
  );

  final double p50;
  final double p10;
  final double p90;
  final String unit;
  final double vsGoldenPct;
  final Confidence confidence;
  final Provenance provenance;
}

class Health {
  const Health({
    required this.score,
    required this.state,
    required this.topContributors,
    this.sinceH,
  });

  factory Health.fromJson(Json j) => Health(
    score: _d0(j['score']),
    state: HealthState.parse(j['state']),
    topContributors: _contributions(j['top_contributors']),
    sinceH: _d(j['since_h']),
  );

  final double score;
  final HealthState state;
  final List<Contribution> topContributors;
  final double? sinceH;
}

List<Contribution> _contributions(Object? v) =>
    ((v as List?) ?? const []).map((e) => Contribution.fromJson(e as Json)).toList();

class InsightCard {
  const InsightCard({
    required this.title,
    required this.summary,
    required this.action,
    required this.expectedEffect,
    required this.confidence,
    required this.evidence,
    this.ponrHours,
  });

  factory InsightCard.fromJson(Json j) => InsightCard(
    title: j['title'] as String? ?? '',
    summary: j['summary'] as String? ?? '',
    action: j['action'] as String? ?? '',
    expectedEffect: j['expected_effect'] as String? ?? '',
    confidence: Confidence.parse(j['confidence']),
    ponrHours: _d(j['ponr_hours']),
    evidence: ((j['evidence'] as List?) ?? const []).cast<String>(),
  );

  final String title;
  final String summary;
  final String action;
  final String expectedEffect;
  final Confidence confidence;
  final double? ponrHours;
  final List<String> evidence;
}

/// Every server event. `KEvent.fromJson` dispatches on `type`.
sealed class KEvent {
  const KEvent({
    required this.reactorId,
    required this.ts,
    required this.tH,
    required this.progress,
    required this.batchId,
  });

  final String reactorId;
  final int ts;
  final double tH;
  final double progress;
  final int batchId;

  static KEvent? fromJson(Json j) => switch (j['type']) {
    'tick' => TickEvent.fromJson(j),
    'alarm' => AlarmEvent.fromJson(j),
    'insight' => InsightEvent.fromJson(j),
    'ack' => AckEvent.fromJson(j),
    _ => null,
  };
}

class TickEvent extends KEvent {
  const TickEvent({
    required super.reactorId,
    required super.ts,
    required super.tH,
    required super.progress,
    required super.batchId,
    required this.sensors,
    required this.derived,
    this.forecast,
    this.health,
  });

  factory TickEvent.fromJson(Json j) => TickEvent(
    reactorId: j['reactor_id'] as String,
    ts: (j['ts'] as num).toInt(),
    tH: _d0(j['t_h']),
    progress: _d0(j['progress']),
    batchId: (j['batch_id'] as num).toInt(),
    sensors: _numMap(j['sensors']),
    derived: _numMap(j['derived']),
    forecast: j['forecast'] == null ? null : Forecast.fromJson(j['forecast'] as Json),
    health: j['health'] == null ? null : Health.fromJson(j['health'] as Json),
  );

  final Map<String, double?> sensors;
  final Map<String, double?> derived;
  final Forecast? forecast;
  final Health? health;

  double? value(String key) => sensors[key] ?? derived[key];
}

class AlarmEvent extends KEvent {
  const AlarmEvent({
    required super.reactorId,
    required super.ts,
    required super.tH,
    required super.progress,
    required super.batchId,
    required this.state,
    required this.previousState,
    required this.severity,
    required this.contributors,
    this.ponrHours,
  });

  factory AlarmEvent.fromJson(Json j) => AlarmEvent(
    reactorId: j['reactor_id'] as String,
    ts: (j['ts'] as num).toInt(),
    tH: _d0(j['t_h']),
    progress: _d0(j['progress']),
    batchId: (j['batch_id'] as num).toInt(),
    state: HealthState.parse(j['state']),
    previousState: HealthState.parse(j['previous_state']),
    severity: j['severity'] as String? ?? 'info',
    contributors: _contributions(j['contributors']),
    ponrHours: _d(j['ponr_hours']),
  );

  final HealthState state;
  final HealthState previousState;
  final String severity;
  final List<Contribution> contributors;
  final double? ponrHours;
}

class InsightEvent extends KEvent {
  const InsightEvent({
    required super.reactorId,
    required super.ts,
    required super.tH,
    required super.progress,
    required super.batchId,
    required this.card,
    required this.fromAgent,
  });

  factory InsightEvent.fromJson(Json j) => InsightEvent(
    reactorId: j['reactor_id'] as String,
    ts: (j['ts'] as num).toInt(),
    tH: _d0(j['t_h']),
    progress: _d0(j['progress']),
    batchId: (j['batch_id'] as num).toInt(),
    card: InsightCard.fromJson(j['card'] as Json),
    fromAgent: j['source'] == 'agent',
  );

  final InsightCard card;
  final bool fromAgent;
}

class AckEvent extends KEvent {
  const AckEvent({
    required super.reactorId,
    required super.ts,
    required super.tH,
    required super.progress,
    required super.batchId,
    required this.by,
  });

  factory AckEvent.fromJson(Json j) => AckEvent(
    reactorId: j['reactor_id'] as String,
    ts: (j['ts'] as num).toInt(),
    tH: _d0(j['t_h']),
    progress: _d0(j['progress']),
    batchId: (j['batch_id'] as num).toInt(),
    by: j['by'] as String? ?? 'operator',
  );

  final String by;
}

/// Reactor slot summary from REST `/reactors` and the WS `snapshot`.
class ReactorSummary {
  const ReactorSummary({
    required this.id,
    required this.batchId,
    required this.strategy,
    required this.isFaultBatch,
    required this.running,
    required this.state,
    required this.acknowledged,
    required this.tEndH,
    this.plantId = '',
    this.lastTick,
    this.lastInsight,
  });

  factory ReactorSummary.fromJson(Json j) => ReactorSummary(
    id: j['id'] as String,
    plantId: j['plant_id'] as String? ?? '',
    batchId: (j['batch_id'] as num).toInt(),
    strategy: j['strategy'] as String? ?? '',
    isFaultBatch: j['is_fault_batch'] as bool? ?? false,
    running: j['running'] as bool? ?? false,
    state: HealthState.parse(j['state']),
    acknowledged: j['acknowledged'] as bool? ?? false,
    tEndH: _d0(j['t_end_h']),
    lastTick: j['last_tick'] == null ? null : TickEvent.fromJson(j['last_tick'] as Json),
    lastInsight: j['last_insight'] == null ? null : InsightEvent.fromJson(j['last_insight'] as Json),
  );

  final String id;
  final String plantId;
  final int batchId;
  final String strategy;
  final bool isFaultBatch;
  final bool running;
  final HealthState state;
  final bool acknowledged;
  final double tEndH;
  final TickEvent? lastTick;
  final InsightEvent? lastInsight;
}

/// One agitation/aeration setting with its power and predicted DO.
class SetpointOption {
  const SetpointOption({
    required this.rpm,
    required this.aeration,
    required this.powerKw,
    required this.doPct,
  });

  factory SetpointOption.fromJson(Json j) => SetpointOption(
    rpm: _d0(j['rpm']),
    aeration: _d0(j['aeration']),
    powerKw: _d0(j['power_kw']),
    doPct: _d0(j['do_pct']),
  );

  final double rpm;
  final double aeration;
  final double powerKw;
  final double doPct;
}

/// Energy-saving (or rescue) setpoints from GET /reactors/{id}/recommendation.
class EnergyRecommendation {
  const EnergyRecommendation({
    required this.action,
    required this.current,
    required this.recommended,
    required this.powerSavingKw,
    required this.energyDeltaPct,
    required this.kwhSavedRestOfBatch,
    required this.co2SavedKg,
    required this.inrSaved,
    required this.targetDoPct,
    this.demo = false,
  });

  factory EnergyRecommendation.fromJson(Json j) => EnergyRecommendation(
    action: j['action'] as String? ?? '',
    current: SetpointOption.fromJson(j['current'] as Json),
    recommended: SetpointOption.fromJson(j['recommended'] as Json),
    powerSavingKw: _d0(j['power_saving_kw']),
    energyDeltaPct: _d0(j['energy_delta_pct']),
    kwhSavedRestOfBatch: _d0(j['kwh_saved_rest_of_batch']),
    co2SavedKg: _d0(j['co2_saved_kg']),
    inrSaved: _d0(j['inr_saved']),
    targetDoPct: _d0(j['target_do_pct']),
  );

  final String action;
  final SetpointOption current;
  final SetpointOption recommended;
  final double powerSavingKw;
  final double energyDeltaPct;
  final double kwhSavedRestOfBatch;
  final double co2SavedKg;
  final double inrSaved;
  final double targetDoPct;

  /// True when produced by the offline demo source rather than the server.
  final bool demo;
}
