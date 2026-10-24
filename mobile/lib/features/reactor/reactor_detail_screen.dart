import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';
import 'package:kairos_pager/features/feedback/feedback_sheet.dart';
import 'package:kairos_pager/widgets/chips.dart';
import 'package:kairos_pager/widgets/energy_donut.dart';
import 'package:kairos_pager/widgets/event_strip.dart';
import 'package:kairos_pager/widgets/forecast_fan.dart';
import 'package:kairos_pager/widgets/format.dart';
import 'package:kairos_pager/widgets/gauge.dart';
import 'package:kairos_pager/widgets/health_ring.dart';
import 'package:kairos_pager/widgets/insight_card.dart';
import 'package:kairos_pager/widgets/metric_readout.dart';
import 'package:kairos_pager/widgets/ponr_countdown.dart';
import 'package:kairos_pager/widgets/section.dart';
import 'package:kairos_pager/widgets/states.dart';
import 'package:kairos_pager/widgets/status_copy.dart';
import 'package:lucide_icons/lucide_icons.dart';

const _vitals = ['feed', 'aeration', 'rpm', 'our', 'co2_offgas_pct'];

class ReactorDetailScreen extends ConsumerWidget {
  const ReactorDetailScreen({required this.reactorId, super.key});

  final String reactorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(reactorProvider(reactorId));
    if (r == null) {
      return Scaffold(
        appBar: AppBar(title: Text(reactorId)),
        body: const EmptyState(
          title: 'This reactor is not in the current run',
          message: 'Go back to the plant view to see the active reactors.',
        ),
      );
    }
    final tick = r.tick;
    final remaining = r.ponrRemainingH;
    final markers = [
      if (r.lastAlarm != null && r.state != HealthState.normal)
        StripMarker(
          r.lastAlarm!.progress,
          stateColor(r.lastAlarm!.state),
          'Alarm at ${fmt(r.lastAlarm!.tH)} h',
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('${r.id} · batch ${r.batchId}', style: KText.display(KSize.xl)),
        actions: [
          IconButton(
            tooltip: 'Feedback',
            icon: const Icon(LucideIcons.messageSquare, size: 20),
            onPressed: () => showFeedbackSheet(context, page: 'reactor', reactorId: r.id),
          ),
          Padding(
            padding: const EdgeInsets.only(right: KSpace.s4),
            child: Center(child: StatusPill(state: r.state)),
          ),
        ],
      ),
      body: tick == null
          ? ListView(
              padding: const EdgeInsets.all(KSpace.s4),
              children: const [
                Skeleton(height: 96),
                SizedBox(height: KSpace.s4),
                Skeleton(height: 220),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(KSpace.s4, KSpace.s2, KSpace.s4, 112),
              children: [
                _Hero(r: r),
                const SizedBox(height: KSpace.s4),
                EventStrip(progress: tick.progress, tH: tick.tH, markers: markers),
                if (r.acknowledged && r.state != HealthState.normal) ...[
                  const SizedBox(height: KSpace.s2),
                  Row(
                    children: [
                      Icon(LucideIcons.checkCircle, size: 14, color: KColors.textMuted),
                      const SizedBox(width: KSpace.s1),
                      Text('Acknowledged by operator', style: KText.ui(KSize.xs, color: KColors.textMuted)),
                    ],
                  ),
                ],
                if (remaining != null) ...[
                  const SizedBox(height: KSpace.s6),
                  Center(
                    child: PonrCountdown(remainingH: remaining, totalH: r.lastAlarm?.ponrHours, size: 148),
                  ),
                ],
                if (r.insight != null && r.state != HealthState.normal) ...[
                  const SizedBox(height: KSpace.s6),
                  InsightCardView(insight: r.insight!, state: r.state),
                ],
                const SizedBox(height: KSpace.s8),
                const SectionHeader(
                  'Right now',
                  subtitle: 'Shaded arcs are the normal range for this process.',
                ),
                SurfaceCard(
                  padding: const EdgeInsets.symmetric(vertical: KSpace.s4, horizontal: KSpace.s2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Gauge(spec: GaugeSpec.doPct, value: tick.value('do_pct')),
                      Gauge(spec: GaugeSpec.ph, value: tick.value('ph')),
                      Gauge(spec: GaugeSpec.temp, value: tick.value('temp_c')),
                    ],
                  ),
                ),
                const SizedBox(height: KSpace.s8),
                _ForecastSection(r: r),
                const SizedBox(height: KSpace.s8),
                _EnergySection(r: r),
                const SizedBox(height: KSpace.s8),
                const SectionHeader('Process signals', subtitle: 'Recent trend from the simulated sensors.'),
                SurfaceCard(
                  padding: const EdgeInsets.symmetric(horizontal: KSpace.s4, vertical: KSpace.s1),
                  child: Column(
                    children: [
                      for (final (i, key) in _vitals.indexed)
                        if (tick.value(key) != null) ...[
                          if (i > 0) const Divider(),
                          MetricReadout(
                            label: sensorLabel(key),
                            value: tick.value(key),
                            unit: sensorMeta[key]?.unit ?? '',
                            decimals: sensorMeta[key]?.decimals ?? 1,
                            history: [for (final t in r.recent) t.value(key) ?? double.nan],
                            accent: _contributorColor(key, tick.health),
                          ),
                        ],
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: KColors.accentX500,
        foregroundColor: KColors.bgBase,
        onPressed: () => context.push('/chat?reactor=${r.id}'),
        icon: const Icon(LucideIcons.messageCircle, size: 18),
        label: Text(
          'Ask Kairos',
          style: KText.ui(KSize.md, weight: FontWeight.w500, color: KColors.bgBase),
        ),
      ),
    );
  }

  Color? _contributorColor(String key, Health? h) {
    if (h == null || h.state == HealthState.normal) return null;
    final hit = h.topContributors.any((c) => c.variable == key);
    return hit ? stateColor(h.state) : null;
  }
}

/// Status sentence next to the health ring.
class _Hero extends StatelessWidget {
  const _Hero({required this.r});

  final ReactorView r;

  @override
  Widget build(BuildContext context) {
    final h = r.tick?.health;
    final alerting = r.state != HealthState.normal;
    final latched = r.state == HealthState.alarm && h != null && h.state != HealthState.alarm;
    return SurfaceCard(
      child: Row(
        children: [
          HealthRing(score: h?.score, state: h?.state ?? r.state, size: 84),
          const SizedBox(width: KSpace.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusSentence(r),
                  style: KText.display(KSize.xl, color: alerting ? stateColor(r.state) : KColors.textPrimary),
                ),
                const SizedBox(height: KSpace.s1),
                Text(
                  latched
                      ? 'Readings look normal again, but the alarm stays until someone acknowledges it.'
                      : '${r.strategyLabel} · ${fmt(r.tick?.tH, decimals: 0)} h into the batch',
                  style: KText.ui(KSize.sm, color: KColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastSection extends StatelessWidget {
  const _ForecastSection({required this.r});

  final ReactorView r;

  @override
  Widget build(BuildContext context) {
    final f = r.tick?.forecast;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Final yield forecast',
          subtitle: 'Band = likely range (80%). Dashed line = a typical batch.',
          trailing: f == null
              ? null
              : ProvenanceChip(provenance: f.provenance, source: 'Model estimate, IndPenSim'),
        ),
        SurfaceCard(
          child: f == null
              ? Text(
                  'The forecast starts after the first hours of the batch.',
                  style: KText.ui(KSize.md, color: KColors.textMuted),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(fmtThousands(f.p50), style: KText.display(KSize.hero * 0.8)),
                        Text(' ${f.unit}', style: KText.ui(KSize.lg, color: KColors.textMuted)),
                        const Spacer(),
                        _Badge(
                          text: '${f.vsGoldenPct.round()}% of typical',
                          color: f.vsGoldenPct >= 95
                              ? KColors.stateHealthy
                              : f.vsGoldenPct >= 80
                              ? KColors.stateWatch
                              : KColors.stateAlarm,
                        ),
                      ],
                    ),
                    Text(
                      'Likely between ${fmtThousands(f.p10)} and ${fmtThousands(f.p90)} ${f.unit}',
                      style: KText.ui(KSize.sm, color: KColors.textSecondary),
                    ),
                    const SizedBox(height: KSpace.s4),
                    ForecastFan(ticks: r.recent),
                  ],
                ),
        ),
      ],
    );
  }
}

class _EnergySection extends ConsumerWidget {
  const _EnergySection({required this.r});

  final ReactorView r;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = r.tick?.derived ?? const <String, double?>{};
    final agit = d['agitator_kw'] ?? 0;
    final comp = d['compressor_kw'] ?? 0;
    final rec = ref.watch(recommendationProvider((id: r.id, bucket: recommendationBucket(), state: r.state)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          'Energy',
          subtitle: 'Agitation and aeration are the big electricity users.',
          trailing: ProvenanceChip(
            provenance: Provenance.assumed,
            source: 'Power and kLa correlations, assumed geometry',
          ),
        ),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  EnergyDonut(agitatorKw: agit, compressorKw: comp, size: 112),
                  const SizedBox(width: KSpace.s6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Legend(
                          color: EnergyDonut.agitatorColor(),
                          label: 'Agitator',
                          value: '${fmt(agit, decimals: 0)} kW',
                        ),
                        const SizedBox(height: KSpace.s2),
                        _Legend(
                          color: EnergyDonut.compressorColor(),
                          label: 'Air compressor',
                          value: '${fmt(comp, decimals: 0)} kW',
                        ),
                        const SizedBox(height: KSpace.s3),
                        Text('Used so far', style: KText.ui(KSize.xs, color: KColors.textMuted)),
                        Text('${fmtThousands(d['kwh_cum'] ?? 0)} kWh', style: KText.display(KSize.lg)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: KSpace.s4),
              const Divider(),
              const SizedBox(height: KSpace.s3),
              rec.when(
                loading: () => const Skeleton(height: 56),
                error: (_, _) => Text(
                  "Couldn't load an energy suggestion right now.",
                  style: KText.ui(KSize.sm, color: KColors.textMuted),
                ),
                data: (e) => e == null
                    ? const SizedBox.shrink()
                    : _Suggestion(e: e, rescue: r.state == HealthState.alarm),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Suggestion extends StatelessWidget {
  const _Suggestion({required this.e, required this.rescue});

  final EnergyRecommendation e;
  final bool rescue;

  @override
  Widget build(BuildContext context) {
    final saving = e.powerSavingKw > 0.5;
    final headline = rescue
        ? 'To restore oxygen'
        : saving
        ? 'Save ${fmt(e.powerSavingKw)} kW (${fmt(e.energyDeltaPct, decimals: 0)}%)'
        : 'Already efficient';
    final detail = saving && !rescue
        ? '~${fmtThousands(e.kwhSavedRestOfBatch)} kWh this batch · ${fmtThousands(e.co2SavedKg)} kg CO₂ · '
              '₹${fmtThousands(e.inrSaved)}. Dissolved oxygen stays near ${fmt(e.recommended.doPct, decimals: 0)}% '
              '(safe floor ${fmt(e.targetDoPct, decimals: 0)}%).'
        : 'Predicted dissolved oxygen ${fmt(e.recommended.doPct, decimals: 0)}% at the suggested setting.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(rescue ? Icons.air_rounded : Icons.eco_rounded, size: 18, color: KColors.accentX500),
            const SizedBox(width: KSpace.s2),
            Text(headline, style: KText.display(KSize.lg, color: KColors.accentX500)),
          ],
        ),
        const SizedBox(height: KSpace.s1),
        Text(e.action, style: KText.ui(KSize.md, weight: FontWeight.w500)),
        const SizedBox(height: KSpace.s1),
        Text(detail, style: KText.ui(KSize.sm, color: KColors.textSecondary)),
        const SizedBox(height: KSpace.s1),
        Text(
          e.demo
              ? 'Demo data. Model estimate; verify before changing setpoints.'
              : 'Model estimate; verify before changing setpoints.',
          style: KText.ui(KSize.xs, color: KColors.textMuted),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, required this.value});

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: KSpace.s2),
      Expanded(
        child: Text(label, style: KText.ui(KSize.sm, color: KColors.textSecondary)),
      ),
      Text(value, style: KText.mono(KSize.sm)),
    ],
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: KSpace.s2, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(KRadius.full),
    ),
    child: Text(
      text,
      style: KText.ui(KSize.xs, weight: FontWeight.w500, color: color),
    ),
  );
}
