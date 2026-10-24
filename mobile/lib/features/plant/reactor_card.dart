import 'package:flutter/material.dart';
import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';
import 'package:kairos_pager/widgets/chips.dart';
import 'package:kairos_pager/widgets/forecast_fan.dart';
import 'package:kairos_pager/widgets/format.dart';
import 'package:kairos_pager/widgets/health_ring.dart';
import 'package:kairos_pager/widgets/mini_vessel.dart';
import 'package:kairos_pager/widgets/status_copy.dart';

/// Plant-list card: vessel, a plain-language status line, health ring and forecast trend.
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
    final alerting = reactor.state != HealthState.normal;
    return Semantics(
      button: true,
      label: 'Reactor ${reactor.id}. ${statusSentence(reactor)}',
      child: Material(
        color: KColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KRadius.sheet),
          side: BorderSide(
            color: alerting ? rim.withValues(alpha: 0.7) : KColors.borderSubtle,
            width: alerting ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (alerting) Container(height: 3, color: rim),
              Padding(
                padding: const EdgeInsets.fromLTRB(KSpace.s4, KSpace.s4, KSpace.s4, KSpace.s3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MiniVessel(
                      state: reactor.state,
                      aeration: tick?.sensors['aeration'] ?? 60,
                      rpm: tick?.sensors['rpm'] ?? 100,
                      doPct: tick?.sensors['do_pct'],
                      width: 56,
                      height: 84,
                    ),
                    const SizedBox(width: KSpace.s4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(reactor.shortId, style: KText.display(KSize.x2xl)),
                              const SizedBox(width: KSpace.s2),
                              StatusPill(state: reactor.state, compact: true),
                            ],
                          ),
                          const SizedBox(height: KSpace.s1),
                          Text(
                            statusSentence(reactor),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: KText.ui(
                              KSize.lg,
                              weight: FontWeight.w500,
                              color: alerting ? rim : KColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: KSpace.s1),
                          Text(
                            'Batch ${reactor.batchId} · ${reactor.strategyLabel}',
                            style: KText.ui(KSize.sm, color: KColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: KSpace.s2),
                    HealthRing(score: h?.score, state: reactor.state, size: 60),
                  ],
                ),
              ),
              if (alerting && reactor.insight != null && !reactor.acknowledged)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: KSpace.s4),
                  padding: const EdgeInsets.all(KSpace.s3),
                  decoration: BoxDecoration(
                    color: rim.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(KRadius.control),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.bolt_rounded, size: 18, color: rim),
                      const SizedBox(width: KSpace.s2),
                      Expanded(
                        child: Text(
                          reactor.insight!.card.action,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: KText.ui(KSize.md, weight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(KSpace.s4, KSpace.s3, KSpace.s4, KSpace.s4),
                child: f == null
                    ? Text(
                        'Yield forecast starts after the first hours of the batch.',
                        style: KText.ui(KSize.sm, color: KColors.textMuted),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Final yield', style: KText.ui(KSize.xs, color: KColors.textMuted)),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(text: fmtThousands(f.p50), style: KText.display(KSize.xl)),
                                    TextSpan(
                                      text: ' ${f.unit}',
                                      style: KText.ui(KSize.sm, color: KColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    '${f.vsGoldenPct.round()}% of typical',
                                    style: KText.mono(KSize.xs, color: KColors.textSecondary),
                                  ),
                                  const SizedBox(width: KSpace.s1),
                                  ProvenanceChip(
                                    provenance: f.provenance,
                                    source: 'Model estimate, IndPenSim',
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(width: KSpace.s4),
                          Expanded(child: ForecastFan(ticks: reactor.recent, height: 46, compact: true)),
                          const SizedBox(width: KSpace.s3),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('DO', style: KText.ui(KSize.xs, color: KColors.textMuted)),
                              Text(
                                '${fmt(tick?.sensors['do_pct'], decimals: 0)}%',
                                style: KText.display(KSize.lg),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
