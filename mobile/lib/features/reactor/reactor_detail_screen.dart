import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';
import 'package:kairos_pager/widgets/chips.dart';
import 'package:kairos_pager/widgets/event_strip.dart';
import 'package:kairos_pager/widgets/format.dart';
import 'package:kairos_pager/widgets/insight_card.dart';
import 'package:kairos_pager/widgets/metric_readout.dart';
import 'package:kairos_pager/widgets/ponr_countdown.dart';
import 'package:kairos_pager/widgets/states.dart';
import 'package:lucide_icons/lucide_icons.dart';

const _vitals = ['do_pct', 'ph', 'temp_c', 'feed', 'aeration', 'rpm', 'our', 'power_kw', 'kwh_cum'];
const _assumedKeys = {'power_kw', 'kwh_cum'};

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
          title: 'Reactor not found',
          message: 'It may have been removed from the scenario.',
        ),
      );
    }
    final tick = r.tick;
    final f = tick?.forecast;
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
        title: Text('${r.id} · batch ${r.batchId}'),
        actions: [
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
                Skeleton(height: 40),
                SizedBox(height: KSpace.s4),
                Skeleton(height: 220),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(KSpace.s4, KSpace.s2, KSpace.s4, 96),
              children: [
                Text(r.strategyLabel, style: KText.ui(KSize.sm, color: KColors.textSecondary)),
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
                const SizedBox(height: KSpace.s6),
                Text('FORECAST', style: KText.overline()),
                if (f == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: KSpace.s3),
                    child: Text(
                      'Yield model not loaded yet.',
                      style: KText.ui(KSize.md, color: KColors.textMuted),
                    ),
                  )
                else
                  MetricReadout(
                    label: 'Final penicillin (${f.vsGoldenPct.round()}% of typical)',
                    decimals: unitDecimals(f.unit),
                    value: f.p50,
                    unit: f.unit,
                    range: (f.p10, f.p90),
                    provenance: f.provenance,
                    history: [
                      for (final t in r.recent)
                        if (t.forecast != null) t.forecast!.p50,
                    ],
                  ),
                const SizedBox(height: KSpace.s4),
                Text('VITALS', style: KText.overline()),
                for (final key in _vitals)
                  if (tick.value(key) != null) ...[
                    MetricReadout(
                      label: sensorLabel(key),
                      value: tick.value(key),
                      unit: sensorMeta[key]?.unit ?? '',
                      decimals: sensorMeta[key]?.decimals ?? 1,
                      provenance: _assumedKeys.contains(key) ? Provenance.assumed : Provenance.synthetic,
                      history: [for (final t in r.recent) t.value(key) ?? double.nan],
                      accent: _contributorColor(key, tick.health),
                    ),
                    const Divider(),
                  ],
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
