import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';
import 'package:kairos_pager/widgets/format.dart';

/// Power split: agitator vs compressor, total kW in the centre.
class EnergyDonut extends StatelessWidget {
  const EnergyDonut({required this.agitatorKw, required this.compressorKw, super.key, this.size = 120});

  final double agitatorKw;
  final double compressorKw;
  final double size;

  static Color agitatorColor() => KColors.accentX500;
  static Color compressorColor() => KColors.stateInfo;

  @override
  Widget build(BuildContext context) {
    final total = agitatorKw + compressorKw;
    return Semantics(
      label:
          'Power ${fmt(total, decimals: 0)} kilowatts, agitator ${fmt(agitatorKw, decimals: 0)}, '
          'compressor ${fmt(compressorKw, decimals: 0)}',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _DonutPainter(
            parts: [agitatorKw, compressorKw],
            colors: [agitatorColor(), compressorColor()],
            gap: KColors.bgSurface,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(fmt(total, decimals: 0), style: KText.display(size * 0.22)),
                Text('kW now', style: KText.ui(KSize.xs, color: KColors.textMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.parts, required this.colors, required this.gap});

  final List<double> parts;
  final List<Color> colors;
  final Color gap;

  @override
  void paint(Canvas canvas, Size size) {
    final total = parts.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    final stroke = size.width / 8;
    final rect = (Offset.zero & size).deflate(stroke / 2 + 1);
    var start = -math.pi / 2;
    for (var i = 0; i < parts.length; i++) {
      final sweep = math.pi * 2 * parts[i] / total;
      canvas.drawArc(
        rect,
        start + 0.03,
        math.max(0, sweep - 0.06),
        false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.parts != parts || old.colors != colors;
}
