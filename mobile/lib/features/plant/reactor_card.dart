import 'package:flutter/material.dart';
import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';
import 'package:kairos_pager/widgets/chips.dart';
import 'package:kairos_pager/widgets/format.dart';
import 'package:kairos_pager/widgets/mini_vessel.dart';

/// Tall plant-list card: vessel, status, forecast vs golden, health, DO.
class ReactorCard extends StatelessWidget {
  const ReactorCard({required this.reactor, required this.onTap, super.key});

  final ReactorView reactor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tick = reactor.tick;
    final f = tick?.forecast;
    final h = tick?.health;
    final rim = stateColor(reactor.state);
    return Semantics(
      button: true,
      label: 'Reactor ${reactor.id}, ${stateLabel(reactor.state)}',
      child: Material(
        color: KColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KRadius.card),
          side: BorderSide(
            color: reactor.state == HealthState.normal ? KColors.borderSubtle : rim.withValues(alpha: 0.6),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(KRadius.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(KSpace.s4),
            child: Row(
              children: [
                MiniVessel(
                  state: reactor.state,
                  aeration: tick?.sensors['aeration'] ?? 60,
                  rpm: tick?.sensors['rpm'] ?? 100,
                  doPct: tick?.sensors['do_pct'],
                ),
                const SizedBox(width: KSpace.s4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(reactor.id, style: KText.mono(KSize.xl, weight: FontWeight.w600)),
                          const SizedBox(width: KSpace.s2),
                          StatusPill(state: reactor.state, compact: true),
                          const Spacer(),
                          if (reactor.acknowledged && reactor.state != HealthState.normal)
                            Text('Acknowledged', style: KText.ui(KSize.xs, color: KColors.textMuted)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Batch ${reactor.batchId} · ${reactor.strategyLabel}',
                        style: KText.ui(KSize.sm, color: KColors.textSecondary),
                      ),
                      const SizedBox(height: KSpace.s3),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: _Stat(
                              label: 'Final yield forecast',
                              value: f == null ? '—' : '${fmt(f.p50)} ${f.unit}',
                              sub: f == null
                                  ? 'model loading'
                                  : '${fmt(f.p10)} to ${fmt(f.p90)} · ${f.vsGoldenPct.round()}% of typical',
                            ),
                          ),
                          _Stat(
                            label: 'Health',
                            value: h == null ? '—' : h.score.round().toString(),
                            sub: 'DO ${fmt(tick?.sensors['do_pct'], decimals: 0)}%',
                            alignEnd: true,
                          ),
                        ],
                      ),
                      if (reactor.state != HealthState.normal && reactor.insight != null) ...[
                        const SizedBox(height: KSpace.s3),
                        Text(
                          reactor.insight!.card.action,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: KText.ui(KSize.md, weight: FontWeight.w500, color: rim),
                        ),
                      ],
                      if (f != null) ...[
                        const SizedBox(height: KSpace.s2),
                        Row(
                          children: [
                            ProvenanceChip(provenance: f.provenance, source: 'IndPenSim simulator'),
                            const SizedBox(width: KSpace.s1),
                            Text('model estimate', style: KText.ui(KSize.xs, color: KColors.textMuted)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.sub, this.alignEnd = false});

  final String label;
  final String value;
  final String sub;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Text(label, style: KText.ui(KSize.xs, color: KColors.textMuted)),
      Text(value, style: KText.mono(KSize.lg, weight: FontWeight.w500)),
      Text(sub, style: KText.mono(KSize.xs, color: KColors.textSecondary)),
    ],
  );
}
