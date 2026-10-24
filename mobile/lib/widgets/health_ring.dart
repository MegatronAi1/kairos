import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';

/// Health 0-100 as a ring coloured by state, score in the centre.
class HealthRing extends StatelessWidget {
  const HealthRing({
    required this.score,
    required this.state,
    super.key,
    this.size = 64,
    this.label = 'health',
  });

  final double? score;
  final HealthState state;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = stateColor(state);
    final v = (score ?? 0).clamp(0, 100) / 100;
    return Semantics(
      label: 'Health ${score?.round() ?? 'unknown'} of 100',
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: v),
          duration: KMotion.slow,
          curve: KMotion.standard,
          builder: (context, t, _) => CustomPaint(
            painter: _RingPainter(t, c, KColors.borderSubtle, size / 11),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(score == null ? '—' : '${score!.round()}', style: KText.display(size * 0.3)),
                  if (label != null && size >= 56)
                    Text(label!, style: KText.ui(size * 0.13, color: KColors.textMuted)),
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
  _RingPainter(this.fraction, this.color, this.track, this.stroke);

  final double fraction;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(stroke / 2 + 1);
    canvas
      ..drawArc(
        r,
        0,
        math.pi * 2,
        false,
        Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      )
      ..drawArc(
        r,
        -math.pi / 2,
        math.pi * 2 * fraction,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke,
      );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}
