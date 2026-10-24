import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';
import 'package:kairos_pager/widgets/format.dart';

/// Large monospace countdown to the point of no return, with a draining ring.
class PonrCountdown extends StatelessWidget {
  const PonrCountdown({required this.remainingH, super.key, this.totalH, this.size = 168});

  final double remainingH;
  final double? totalH;
  final double size;

  static const tooltip =
      'Point of no return: the latest time the best available correction '
      'still recovers at least 90% of a normal batch yield, according to Kairos models. '
      'Model estimate, not a guarantee.';

  @override
  Widget build(BuildContext context) {
    final frac = totalH == null || totalH! <= 0 ? 1.0 : (remainingH / totalH!).clamp(0.0, 1.0);
    final color = remainingH <= 1 ? KColors.stateAlarm : KColors.stateWatch;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: 'Point of no return in ${fmtHours(remainingH)}, model estimate',
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _RingPainter(frac, color),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    remainingH > 0 ? fmtHours(remainingH) : 'Passed',
                    style: KText.mono(size > 140 ? KSize.hero * 0.75 : KSize.x2xl, weight: FontWeight.w600),
                  ),
                  Text(
                    remainingH > 0 ? 'to point of no return' : 'act now to limit the loss',
                    style: KText.ui(KSize.xs, color: KColors.textSecondary),
                  ),
                  Text('model estimate', style: KText.ui(KSize.xs - 1, color: KColors.textMuted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.color);

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(6);
    final track = Paint()
      ..color = KColors.borderSubtle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6;
    canvas
      ..drawArc(r, 0, 2 * math.pi, false, track)
      ..drawArc(r, -math.pi / 2, 2 * math.pi * fraction, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.color != color;
}
