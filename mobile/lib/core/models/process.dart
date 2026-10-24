// Alternative-protein process library models, mirroring GET /api/v1/processes.
// Hand-written like models.dart; contract-tested against test/fixtures/process.json.

import 'package:kairos_pager/core/models/models.dart';

enum ProcessFamily {
  biomass,
  precision;

  static ProcessFamily parse(Object? v) => v == 'precision' ? precision : biomass;

  String get label => this == biomass ? 'Biomass fermentation' : 'Precision fermentation';
}

enum ReactorKind {
  airlift,
  stirredTank,
  photobioreactor,
  gasFermenter;

  static ReactorKind parse(Object? v) => switch (v) {
    'airlift' => airlift,
    'photobioreactor' => photobioreactor,
    'gas_fermenter' => gasFermenter,
    _ => stirredTank,
  };

  String get label => switch (this) {
    airlift => 'Airlift loop fermenter',
    stirredTank => 'Stirred-tank fermenter',
    photobioreactor => 'Photobioreactor',
    gasFermenter => 'Gas fermenter',
  };
}

enum BenchmarkFit {
  high,
  medium,
  low;

  static BenchmarkFit? parse(Object? v) => switch (v) {
    'high' => high,
    'medium' => medium,
    'low' => low,
    _ => null,
  };

  String get label => switch (this) {
    high => 'Strong match',
    medium => 'Partial match',
    low => 'Weak match',
  };
}

String _s(Object? v) => v is String ? v : '';
List<String> _strings(Object? v) => ((v as List?) ?? const []).map((e) => e.toString()).toList();

class ProcessExample {
  const ProcessExample({required this.company, this.productName, this.url});

  factory ProcessExample.fromJson(Object? j) {
    final m = (j as Map?) ?? const {};
    return ProcessExample(
      company: _s(m['company']),
      productName: m['product_name'] as String?,
      url: m['url'] as String?,
    );
  }

  final String company;
  final String? productName;
  final String? url;
}

class ProcessSummary {
  const ProcessSummary({
    required this.id,
    required this.family,
    required this.name,
    required this.product,
    required this.example,
    required this.organism,
    required this.reactor,
    required this.mode,
    this.benchmarkFit,
  });

  factory ProcessSummary.fromJson(Json j) => ProcessSummary(
    id: _s(j['id']),
    family: ProcessFamily.parse(j['family']),
    name: _s(j['name']),
    product: _s(j['product']),
    example: ProcessExample.fromJson(j['example']),
    organism: _s(j['organism']),
    reactor: ReactorKind.parse(j['reactor']),
    mode: _s(j['mode']),
    benchmarkFit: BenchmarkFit.parse(j['benchmark_fit'] ?? (j['kairos'] as Map?)?['benchmark_fit']),
  );

  final String id;
  final ProcessFamily family;
  final String name;
  final String product;
  final ProcessExample example;
  final String organism;
  final ReactorKind reactor;
  final String mode;
  final BenchmarkFit? benchmarkFit;
}

class SetpointRange {
  const SetpointRange({
    required this.provenance,
    required this.source,
    this.min,
    this.max,
    this.value,
    this.unit,
  });

  factory SetpointRange.fromJson(Object? j) {
    final m = (j as Map?) ?? const {};
    double? d(Object? v) => v is num ? v.toDouble() : null;
    return SetpointRange(
      min: d(m['min']),
      max: d(m['max']),
      value: d(m['value']),
      unit: m['unit'] as String?,
      provenance: Provenance.parse(m['provenance']),
      source: _s(m['source']),
    );
  }

  final double? min;
  final double? max;
  final double? value;
  final String? unit;
  final Provenance provenance;
  final String source;

  /// "28–32", "6", or null when the catalog gives no number.
  String? get text {
    String n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
    if (value != null) return n(value!);
    if (min != null && max != null) return min == max ? n(min!) : '${n(min!)}–${n(max!)}';
    if (min != null) return '≥ ${n(min!)}';
    if (max != null) return '≤ ${n(max!)}';
    return null;
  }
}

class ProcessPhase {
  const ProcessPhase({
    required this.name,
    required this.duration,
    required this.goal,
    required this.controls,
  });

  factory ProcessPhase.fromJson(Object? j) {
    final m = (j as Map?) ?? const {};
    return ProcessPhase(
      name: _s(m['name']),
      duration: _s(m['duration']),
      goal: _s(m['goal']),
      controls: [
        for (final c in (m['controls'] as List?) ?? const [])
          (param: _s((c as Map)['param']), action: _s(c['action'])),
      ],
    );
  }

  final String name;
  final String duration;
  final String goal;
  final List<({String param, String action})> controls;
}

class ProcessDetail extends ProcessSummary {
  const ProcessDetail({
    required super.id,
    required super.family,
    required super.name,
    required super.product,
    required super.example,
    required super.organism,
    required super.reactor,
    required super.mode,
    required this.productLocation,
    required this.setpoints,
    required this.phases,
    required this.controlLoops,
    required this.criticalRisks,
    required this.energyHotspots,
    required this.yieldSignal,
    required this.faultSignatures,
    required this.energyLevers,
    required this.benchmarkFitWhy,
    required this.sources,
    super.benchmarkFit,
    this.organismType = '',
    this.reactorNote,
    this.carbonSource,
    this.nitrogenSource,
    this.gases = const [],
    this.light = false,
    this.namingNote,
  });

  factory ProcessDetail.fromJson(Json j) {
    final base = ProcessSummary.fromJson(j);
    final k = (j['kairos'] as Map?) ?? const {};
    return ProcessDetail(
      id: base.id,
      family: base.family,
      name: base.name,
      product: base.product,
      example: base.example,
      organism: base.organism,
      reactor: base.reactor,
      mode: base.mode,
      benchmarkFit: base.benchmarkFit,
      organismType: _s(j['organism_type']),
      reactorNote: j['reactor_note'] as String?,
      productLocation: _s(j['product_location']),
      carbonSource: j['carbon_source'] as String?,
      nitrogenSource: j['nitrogen_source'] as String?,
      gases: _strings(j['gases']),
      light: j['light'] == true,
      namingNote: j['naming_note'] as String?,
      setpoints: {
        for (final e in ((j['setpoints'] as Map?) ?? const {}).entries)
          e.key.toString(): SetpointRange.fromJson(e.value),
      },
      phases: [for (final p in (j['phases'] as List?) ?? const []) ProcessPhase.fromJson(p)],
      controlLoops: [
        for (final c in (j['control_loops'] as List?) ?? const [])
          (
            measure: _s((c as Map)['measure']),
            actuator: _s(c['actuator']),
            purpose: _s(c['purpose']),
          ),
      ],
      criticalRisks: _strings(j['critical_risks']),
      energyHotspots: _strings(j['energy_hotspots']),
      yieldSignal: _s(k['yield_signal']),
      faultSignatures: _strings(k['fault_signatures']),
      energyLevers: _strings(k['energy_levers']),
      benchmarkFitWhy: _s(k['benchmark_fit_why']),
      sources: [
        for (final s in (j['sources'] as List?) ?? const [])
          (title: _s((s as Map)['title']), url: _s(s['url'])),
      ],
    );
  }

  final String organismType;
  final String? reactorNote;
  final String productLocation;
  final String? carbonSource;
  final String? nitrogenSource;
  final List<String> gases;
  final bool light;
  final String? namingNote;
  final Map<String, SetpointRange> setpoints;
  final List<ProcessPhase> phases;
  final List<({String measure, String actuator, String purpose})> controlLoops;
  final List<String> criticalRisks;
  final List<String> energyHotspots;
  final String yieldSignal;
  final List<String> faultSignatures;
  final List<String> energyLevers;
  final String benchmarkFitWhy;
  final List<({String title, String url})> sources;

  /// Range text for the first matching setpoint key, with its unit.
  String? rangeFor(List<String> keys) {
    for (final k in keys) {
      final r = setpoints[k];
      final t = r?.text;
      if (t != null) {
        final unit = r!.unit ?? (k.endsWith('_pct') ? '%' : (k == 'temp_c' ? ' °C' : ''));
        return '$t$unit';
      }
    }
    return null;
  }
}
