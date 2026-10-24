import 'package:flutter/material.dart';
import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';
import 'package:kairos_pager/widgets/chips.dart';
import 'package:kairos_pager/widgets/format.dart';

/// Label, value, unit, optional p10-p90 range, provenance chip and a sparkline.
class MetricReadout extends StatelessWidget {
  const MetricReadout({
    required this.label,
    required this.value,
    required this.unit,
    super.key,
    this.decimals = 1,
    this.range,
    this.provenance = Provenance.synthetic,
    this.history = const [],
    this.accent,
  });

  final String label;
  final double? value;
  final String unit;
  final int decimals;
  final (double, double)? range;
  final Provenance provenance;
  final List<double> history;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label ${fmt(value, decimals: decimals)} $unit',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpace.s3),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: KText.ui(KSize.sm, color: KColors.textSecondary),
                        ),
                      ),
                      const SizedBox(width: KSpace.s2),
                      ProvenanceChip(provenance: provenance),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: fmt(value, decimals: decimals),
                          style: KText.mono(KSize.xl, weight: FontWeight.w500, color: accent),
                        ),
                        if (unit.isNotEmpty)
                          TextSpan(
                            text: ' $unit',
                            style: KText.ui(KSize.sm, color: KColors.textMuted),
                          ),
                      ],
                    ),
                  ),
                  if (range != null)
                    Text(
                      '${fmt(range!.$1, decimals: decimals)} to ${fmt(range!.$2, decimals: decimals)} $unit',
                      style: KText.mono(KSize.xs, color: KColors.textMuted),
                    ),
                ],
              ),
            ),
            if (history.length > 2)
              SizedBox(
                width: 88,
                height: 28,
                child: CustomPaint(painter: SparklinePainter(history, accent ?? KColors.accentX500)),
              ),
          ],
        ),
      ),
    );
  }
}

class SparklinePainter extends CustomPainter {
  SparklinePainter(this.values, this.color);

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final finite = values.where((v) => v.isFinite).toList();
    if (finite.length < 2) return;
    var lo = finite.reduce((a, b) => a < b ? a : b);
    var hi = finite.reduce((a, b) => a > b ? a : b);
    if (hi - lo < 1e-9) {
      lo -= 1;
      hi += 1;
    }
    final path = Path();
    for (var i = 0; i < finite.length; i++) {
      final x = size.width * i / (finite.length - 1);
      final y = size.height * (1 - (finite[i] - lo) / (hi - lo));
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(SparklinePainter old) => old.values != values || old.color != color;
}
