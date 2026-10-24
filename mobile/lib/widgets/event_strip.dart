import 'package:flutter/material.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';

class StripMarker {
  const StripMarker(this.progress, this.color, this.label);

  final double progress;
  final Color color;
  final String label;
}

/// Batch progress bar with markers for alarm onset, PONR and interventions.
class EventStrip extends StatelessWidget {
  const EventStrip({required this.progress, required this.tH, super.key, this.markers = const []});

  final double progress;
  final double tH;
  final List<StripMarker> markers;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Batch progress ${(progress * 100).round()} percent',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Batch progress', style: KText.ui(KSize.xs, color: KColors.textSecondary)),
              const Spacer(),
              Text(
                '${tH.toStringAsFixed(1)} h · ${(progress * 100).round()}%',
                style: KText.mono(KSize.xs, color: KColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: KSpace.s2),
          LayoutBuilder(
            builder: (context, c) => SizedBox(
              height: 14,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    top: 5,
                    bottom: 5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: KColors.bgInset,
                        borderRadius: BorderRadius.circular(KRadius.full),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 5,
                    bottom: 5,
                    width: c.maxWidth * progress.clamp(0, 1),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: KColors.accentX600,
                        borderRadius: BorderRadius.circular(KRadius.full),
                      ),
                    ),
                  ),
                  for (final m in markers)
                    Positioned(
                      left: (c.maxWidth * m.progress.clamp(0, 1)) - 1,
                      top: 0,
                      bottom: 0,
                      width: 3,
                      child: Tooltip(
                        message: m.label,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: m.color, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
