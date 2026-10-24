import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kairos_pager/core/fleet_providers.dart';
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
import 'package:kairos_pager/widgets/metric_readout.dart';
import 'package:kairos_pager/widgets/states.dart';
import 'package:kairos_pager/widgets/status_copy.dart';
import 'package:kairos_pager/widgets/ui.dart';
import 'package:lucide_icons/lucide_icons.dart';

const _vitals = ['do_pct', 'ph', 'temp_c', 'feed', 'aeration', 'rpm', 'our', 'co2_offgas_pct'];

/// "Model estimate" once, however the agent phrased the expected effect.
String expectedText(String effect) =>
    'Expected: $effect${effect.toLowerCase().contains('model estimate') ? '' : ' (model estimate)'}';

/// One reactor: header with health and countdown, then Overview / Forecast / Energy / Signals tabs.
class ReactorDetailScreen extends ConsumerWidget {
  const ReactorDetailScreen({required this.reactorId, super.key});

  final String reactorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(reactorProvider(reactorId));
    final plant = ref.watch(plantOfReactorProvider(reactorId));
    if (r == null) {
      return Scaffold(
        appBar: AppBar(title: Text(reactorId)),
        body: const EmptyState(
          title: 'This reactor is not in the current run',
          message: 'Go back to see the active reactors.',
        ),
      );
    }
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.id, style: KText.display(KSize.xl)),
              Text(
                [if (plant != null) plant.name, 'Batch ${r.batchId}'].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KText.ui(KSize.xs, color: KColors.textMuted),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Feedback',
              icon: Icon(LucideIcons.messageSquare, size: 20, color: KColors.textSecondary),
              onPressed: () => showFeedbackSheet(context, page: 'reactor', reactorId: r.id),
            ),
            Padding(
              padding: const EdgeInsets.only(right: KSpace.s4),
              child: Center(child: Tag(stateLabel(r.state), color: stateColor(r.state))),
            ),
          ],
        ),
        body: r.tick == null
            ? const Padding(
                padding: EdgeInsets.all(KSpace.s4),
                child: Column(children: [Skeleton(height: 120, radius: KR.card)]),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(KSpace.s4, KSpace.s2, KSpace.s4, KSpace.s3),
                    child: _Header(r: r),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: KSpace.s4),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: KColors.bgInset,
                        borderRadius: BorderRadius.circular(KR.pill),
                      ),
                      child: TabBar(
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: KColors.bgSurface,
                          borderRadius: BorderRadius.circular(KR.pill),
                          boxShadow: const [
                            BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2)),
                          ],
                        ),
                        labelColor: KColors.textPrimary,
                        unselectedLabelColor: KColors.textMuted,
                        labelStyle: KText.ui(KSize.sm, weight: FontWeight.w700),
                        unselectedLabelStyle: KText.ui(KSize.sm, weight: FontWeight.w500),
                        labelPadding: EdgeInsets.zero,
                        tabs: const [
                          Tab(text: 'Overview'),
                          Tab(text: 'Forecast'),
                          Tab(text: 'Energy'),
                          Tab(text: 'Signals'),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _Overview(r: r),
                        _ForecastTab(r: r),
                        _EnergyTab(r: r),
                        _SignalsTab(r: r),
                      ],
                    ),
                  ),
                ],
              ),
        floatingActionButton: AskKairosButton(onPressed: () => context.push('/chat?reactor=${r.id}')),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.r});

  final ReactorView r;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = r.tick?.health;
    final c = stateColor(r.state);
    final alerting = r.state != HealthState.normal;
    final left = r.ponrRemainingH;
    final openAlarm = r.state == HealthState.alarm && !r.acknowledged;
    return KCard(
      color: alerting ? Color.alphaBlend(c.withValues(alpha: 0.06), KColors.bgSurface) : null,
      borderColor: alerting ? c.withValues(alpha: 0.5) : null,
      child: Column(
        children: [
          Row(
            children: [
              HealthRing(score: h?.score, state: r.state, size: 68),
              const SizedBox(width: KSpace.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusSentence(r),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: KText.display(KSize.lg + 1, color: alerting ? c : KColors.textPrimary),
                    ),
                    const SizedBox(height: KSpace.s2),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Tag(
                          '${fmt(r.tick?.tH, decimals: 0)} h in',
                          color: KColors.textSecondary,
                          icon: LucideIcons.clock,
                        ),
                        if (left != null)
                          Tag(
                            left > 0 ? '${fmtHours(left)} to act' : 'PONR passed',
                            color: c,
                            icon: LucideIcons.timer,
                          ),
                        if (r.acknowledged && alerting)
                          Tag('Acknowledged', color: KColors.stateHealthy, icon: LucideIcons.check),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (openAlarm) ...[
            const SizedBox(height: KSpace.s3),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: KColors.stateAlarm,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(42),
                ),
                onPressed: () => fireAndForget(ref.read(alertsProvider.notifier).acknowledge(r.id)),
                icon: const Icon(LucideIcons.check, size: 18),
                label: const Text('Acknowledge alarm'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

EdgeInsets get _tabPad => const EdgeInsets.fromLTRB(KSpace.s4, KSpace.s4, KSpace.s4, 96);

class _Overview extends StatelessWidget {
  const _Overview({required this.r});

  final ReactorView r;

  @override
  Widget build(BuildContext context) {
    final tick = r.tick!;
    final markers = [
      if (r.lastAlarm != null && r.state != HealthState.normal)
        StripMarker(
          r.lastAlarm!.progress,
          stateColor(r.lastAlarm!.state),
          'Alarm at ${fmt(r.lastAlarm!.tH)} h',
        ),
    ];
    return ListView(
      padding: _tabPad,
      children: [
        if (r.insight != null && r.state != HealthState.normal) ...[
          _InsightCard(insight: r.insight!, state: r.state),
          const SizedBox(height: KSpace.s4),
        ],
        Text('Right now', style: KText.display(KSize.lg)),
        const SizedBox(height: KSpace.s2),
        KCard(
          padding: const EdgeInsets.symmetric(vertical: KSpace.s4, horizontal: KSpace.s2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Gauge(spec: GaugeSpec.doPct, value: tick.value('do_pct'), size: 96),
              Gauge(spec: GaugeSpec.ph, value: tick.value('ph'), size: 96),
              Gauge(spec: GaugeSpec.temp, value: tick.value('temp_c'), size: 96),
            ],
          ),
        ),
        const SizedBox(height: KSpace.s4),
        KCard(
          child: EventStrip(progress: tick.progress, tH: tick.tH, markers: markers),
        ),
      ],
    );
  }
}

/// AI card: title and the one action up front; the reasoning on demand.
class _InsightCard extends StatefulWidget {
  const _InsightCard({required this.insight, required this.state});

  final InsightEvent insight;
  final HealthState state;

  @override
  State<_InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<_InsightCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final card = widget.insight.card;
    final c = stateColor(widget.state);
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.sparkles, size: 16, color: KColors.accentX500),
              const SizedBox(width: 6),
              Text(
                widget.insight.fromAgent ? 'KAIROS AI' : 'KAIROS RULES',
                style: KText.overline(color: KColors.accentX500),
              ),
              const Spacer(),
              ConfidenceMeter(confidence: card.confidence),
            ],
          ),
          const SizedBox(height: KSpace.s2),
          Text(card.title, style: KText.display(KSize.lg + 1, color: c)),
          const SizedBox(height: KSpace.s3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(KSpace.s3),
            decoration: BoxDecoration(color: KColors.accentGlow, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Do this', style: KText.overline(color: KColors.accentX500)),
                const SizedBox(height: 2),
                Text(card.action, style: KText.ui(KSize.md, weight: FontWeight.w600)),
              ],
            ),
          ),
          AnimatedSize(
            duration: MediaQuery.of(context).disableAnimations ? Duration.zero : KMotion.base,
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: KSpace.s3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(card.summary, style: KText.ui(KSize.md, color: KColors.textSecondary)),
                        if (card.expectedEffect.isNotEmpty) ...[
                          const SizedBox(height: KSpace.s2),
                          Text(
                            expectedText(card.expectedEffect),
                            style: KText.ui(KSize.sm, color: KColors.textMuted),
                          ),
                        ],
                        if (card.evidence.isNotEmpty) ...[
                          const SizedBox(height: KSpace.s2),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [for (final e in card.evidence) EvidenceChip(source: e)],
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
            onPressed: () => setState(() => _open = !_open),
            icon: Icon(_open ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 16),
            label: Text(_open ? 'Less' : 'Why and evidence'),
          ),
        ],
      ),
    );
  }
}

class _ForecastTab extends StatelessWidget {
  const _ForecastTab({required this.r});

  final ReactorView r;

  @override
  Widget build(BuildContext context) {
    final f = r.tick?.forecast;
    if (f == null) {
      return const EmptyState(
        icon: LucideIcons.lineChart,
        title: 'Forecast starts soon',
        message: 'The yield forecast begins after the first hours of the batch.',
      );
    }
    final c = f.vsGoldenPct >= 95
        ? KColors.stateHealthy
        : f.vsGoldenPct >= 80
        ? KColors.stateWatch
        : KColors.stateAlarm;
    return ListView(
      padding: _tabPad,
      children: [
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Final yield', style: KText.ui(KSize.sm, color: KColors.textMuted)),
                  const Spacer(),
                  ProvenanceChip(provenance: f.provenance, source: 'Model estimate, IndPenSim'),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(fmtThousands(f.p50), style: KText.display(40, weight: FontWeight.w800)),
                  Text(' ${f.unit}', style: KText.ui(KSize.lg, color: KColors.textMuted)),
                  const Spacer(),
                  Tag('${f.vsGoldenPct.round()}% of typical', color: c),
                ],
              ),
              const SizedBox(height: KSpace.s3),
              Row(
                children: [
                  _RangeStat('Low', '${fmtThousands(f.p10)} ${f.unit}'),
                  _RangeStat('Likely', '${fmtThousands(f.p50)} ${f.unit}'),
                  _RangeStat('High', '${fmtThousands(f.p90)} ${f.unit}'),
                ],
              ),
              const SizedBox(height: KSpace.s4),
              ForecastFan(ticks: r.recent, height: 160),
              const SizedBox(height: KSpace.s2),
              Text(
                'Band: likely range (80%). Dashed: a typical batch.',
                style: KText.ui(KSize.xs, color: KColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RangeStat extends StatelessWidget {
  const _RangeStat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: KText.ui(KSize.xs, color: KColors.textMuted)),
        Text(value, style: KText.ui(KSize.sm, weight: FontWeight.w700)),
      ],
    ),
  );
}

class _EnergyTab extends ConsumerWidget {
  const _EnergyTab({required this.r});

  final ReactorView r;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = r.tick?.derived ?? const <String, double?>{};
    final agit = d['agitator_kw'] ?? 0;
    final comp = d['compressor_kw'] ?? 0;
    final rec = ref.watch(recommendationProvider((id: r.id, bucket: recommendationBucket(), state: r.state)));
    return ListView(
      padding: _tabPad,
      children: [
        KCard(
          child: Row(
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
                    Text('Used this batch', style: KText.ui(KSize.xs, color: KColors.textMuted)),
                    Text('${fmtThousands(d['kwh_cum'] ?? 0)} kWh', style: KText.display(KSize.xl)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: KSpace.s4),
        rec.when(
          loading: () => const Skeleton(height: 120, radius: KR.card),
          error: (_, _) => KCard(
            child: Text(
              "Couldn't load a suggestion right now.",
              style: KText.ui(KSize.sm, color: KColors.textMuted),
            ),
          ),
          data: (e) =>
              e == null ? const SizedBox.shrink() : _Suggestion(e: e, rescue: r.state == HealthState.alarm),
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
        ? 'Save ${fmt(e.powerSavingKw)} kW'
        : 'Already efficient';
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(rescue ? LucideIcons.wind : LucideIcons.leaf, size: 18, color: KColors.accentX500),
              const SizedBox(width: KSpace.s2),
              Expanded(
                child: Text(headline, style: KText.display(KSize.lg, color: KColors.accentX500)),
              ),
              if (saving && !rescue)
                Tag('${fmt(e.energyDeltaPct, decimals: 0)}%', color: KColors.stateHealthy),
            ],
          ),
          const SizedBox(height: KSpace.s2),
          Text(e.action, style: KText.ui(KSize.md, weight: FontWeight.w600)),
          if (saving && !rescue) ...[
            const SizedBox(height: KSpace.s3),
            Row(
              children: [
                _RangeStat('This batch', '${fmtThousands(e.kwhSavedRestOfBatch)} kWh'),
                _RangeStat('CO₂', '${fmtThousands(e.co2SavedKg)} kg'),
                _RangeStat('Cost', '₹${fmtThousands(e.inrSaved)}'),
              ],
            ),
          ],
          const SizedBox(height: KSpace.s3),
          Text(
            'DO stays near ${fmt(e.recommended.doPct, decimals: 0)}% (floor ${fmt(e.targetDoPct, decimals: 0)}%). '
            '${e.demo ? 'Demo data. ' : ''}Model estimate; verify first.',
            style: KText.ui(KSize.xs, color: KColors.textMuted),
          ),
        ],
      ),
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
      Text(value, style: KText.ui(KSize.sm, weight: FontWeight.w700)),
    ],
  );
}

class _SignalsTab extends StatelessWidget {
  const _SignalsTab({required this.r});

  final ReactorView r;

  @override
  Widget build(BuildContext context) {
    final tick = r.tick!;
    final h = tick.health;
    Color? accent(String key) {
      if (h == null || h.state == HealthState.normal) return null;
      return h.topContributors.any((c) => c.variable == key) ? stateColor(h.state) : null;
    }

    final keys = [
      for (final k in _vitals)
        if (tick.value(k) != null) k,
    ];
    return ListView(
      padding: _tabPad,
      children: [
        KCard(
          padding: const EdgeInsets.symmetric(horizontal: KSpace.s4, vertical: KSpace.s1),
          child: Column(
            children: [
              for (final (i, key) in keys.indexed) ...[
                if (i > 0) const Divider(),
                MetricReadout(
                  label: sensorLabel(key),
                  value: tick.value(key),
                  unit: sensorMeta[key]?.unit ?? '',
                  decimals: sensorMeta[key]?.decimals ?? 1,
                  history: [for (final t in r.recent) t.value(key) ?? double.nan],
                  accent: accent(key),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: KSpace.s2),
        Text(
          'Highlighted signals are the ones driving the current state.',
          style: KText.ui(KSize.xs, color: KColors.textMuted),
        ),
      ],
    );
  }
}
