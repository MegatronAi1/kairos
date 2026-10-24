import 'package:flutter/material.dart';
import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';

/// Healthy / Watch / Alarm with a state dot.
class StatusPill extends StatelessWidget {
  const StatusPill({required this.state, super.key, this.compact = false});

  final HealthState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = stateColor(state);
    return Semantics(
      label: 'Status ${stateLabel(state)}',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? KSpace.s2 : KSpace.s3, vertical: KSpace.s1),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(KRadius.full),
          border: Border.all(color: c.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: KSpace.s2 - 2),
            Text(
              stateLabel(state),
              style: KText.ui(KSize.xs, weight: FontWeight.w500, color: c),
            ),
          ],
        ),
      ),
    );
  }
}

/// M / P / A / S data-provenance label with a tooltip.
class ProvenanceChip extends StatelessWidget {
  const ProvenanceChip({required this.provenance, super.key, this.source});

  final Provenance provenance;
  final String? source;

  @override
  Widget build(BuildContext context) {
    final c = provenanceColor(provenance);
    final name = provenance.name[0].toUpperCase() + provenance.name.substring(1);
    return Tooltip(
      message: source == null ? '$name data' : '$name: $source',
      child: Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: c.withValues(alpha: 0.6)),
        ),
        child: Text(
          name[0],
          style: KText.mono(10, weight: FontWeight.w600, color: c),
        ),
      ),
    );
  }
}

/// Low / medium / high as three segments.
class ConfidenceMeter extends StatelessWidget {
  const ConfidenceMeter({required this.confidence, super.key});

  final Confidence confidence;

  @override
  Widget build(BuildContext context) {
    final filled = confidence.index + 1;
    return Semantics(
      label: 'Confidence ${confidence.name}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 14,
              height: 4,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                color: i < filled ? KColors.accentX500 : KColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          const SizedBox(width: KSpace.s1),
          Text(confidence.name, style: KText.ui(KSize.xs, color: KColors.textSecondary)),
        ],
      ),
    );
  }
}

/// "Based on: fault detector".
class EvidenceChip extends StatelessWidget {
  const EvidenceChip({required this.source, super.key});

  final String source;

  static String label(String s) => switch (s) {
    'fault_detector' => 'fault detector',
    'yield_model' => 'yield model',
    'energy_model' => 'energy model',
    'why_engine' => 'drivers',
    'ponr' => 'point of no return',
    _ => s.replaceAll('_', ' '),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: KSpace.s2, vertical: 2),
      decoration: BoxDecoration(
        color: KColors.bgInset,
        borderRadius: BorderRadius.circular(KRadius.full),
        border: Border.all(color: KColors.borderSubtle),
      ),
      child: Text(label(source), style: KText.ui(KSize.xs, color: KColors.textSecondary)),
    );
  }
}
