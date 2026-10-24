import 'package:flutter/material.dart';
import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';
import 'package:kairos_pager/widgets/chips.dart';

/// The agent's alarm card: title, summary, action, expected effect, confidence, evidence.
class InsightCardView extends StatelessWidget {
  const InsightCardView({required this.insight, super.key, this.state = HealthState.watch});

  final InsightEvent insight;
  final HealthState state;

  @override
  Widget build(BuildContext context) {
    final card = insight.card;
    final c = stateColor(state);
    return Container(
      decoration: BoxDecoration(
        color: KColors.bgSurface,
        borderRadius: BorderRadius.circular(KRadius.card),
        border: Border.all(color: KColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: c),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(KSpace.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(insight.fromAgent ? 'KAIROS' : 'KAIROS · RULES', style: KText.overline()),
                        const Spacer(),
                        ConfidenceMeter(confidence: card.confidence),
                      ],
                    ),
                    const SizedBox(height: KSpace.s2),
                    Text(card.title, style: KText.ui(KSize.lg, weight: FontWeight.w500)),
                    const SizedBox(height: KSpace.s1),
                    Text(card.summary, style: KText.ui(KSize.md, color: KColors.textSecondary)),
                    const SizedBox(height: KSpace.s3),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(KSpace.s3),
                      decoration: BoxDecoration(
                        color: KColors.accentGlow,
                        borderRadius: BorderRadius.circular(KRadius.control),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Do this', style: KText.overline(color: KColors.accentX500)),
                          const SizedBox(height: 2),
                          Text(card.action, style: KText.ui(KSize.md, weight: FontWeight.w500)),
                          if (card.expectedEffect.isNotEmpty) ...[
                            const SizedBox(height: KSpace.s1),
                            Text(
                              'Expected: ${card.expectedEffect} (model estimate)',
                              style: KText.ui(KSize.sm, color: KColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (card.evidence.isNotEmpty) ...[
                      const SizedBox(height: KSpace.s3),
                      Wrap(
                        spacing: KSpace.s1,
                        runSpacing: KSpace.s1,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('Based on', style: KText.ui(KSize.xs, color: KColors.textMuted)),
                          for (final e in card.evidence) EvidenceChip(source: e),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
