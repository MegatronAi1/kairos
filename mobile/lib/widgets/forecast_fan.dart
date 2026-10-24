import 'package:flutter/material.dart';
import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/theme/tokens.dart';

/// Yield forecast over recent ticks: p10-p90 band, p50 line, dashed typical batch.
class ForecastFan extends StatelessWidget {
  const ForecastFan({required this.ticks, super.key, this.height = 120, this.compact = false});

  final List<TickEvent> ticks;
  final double height;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pts = [
      for (final t in ticks)
        if (t.forecast != null) t.forecast!,
    ];
    if (pts.length < 2) return SizedBox(height: height);
    final last = pts.last;
    final typical = last.vsGoldenPct > 0 ? last.p50 / last.vsGoldenPct * 100 : null;
    return Semantics(
      label: 'Yield forecast trend, model estimate',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _FanPainter(
            pts: pts,
            typical: typical,
            band: KColors.accentX500.withValues(alpha: 0.18),
            line: KColors.accentX500,
            reference: KColors.textMuted,
            grid: KColors.borderSubtle,
            compact: compact,
          ),
        ),
      ),
    );
  }
}

class _FanPainter extends CustomPainter {
  _FanPainter({
    required this.pts,
    required this.typical,
    required this.band,
    required this.line,
    required this.reference,
    required this.grid,
    required this.compact,
  });

  final List<Forecast> pts;
  final double? typical;
  final Color band;
  final Color line;
  final Color reference;
  final Color grid;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    var lo = pts.map((p) => p.p10).reduce((a, b) => a < b ? a : b);
    var hi = pts.map((p) => p.p90).reduce((a, b) => a > b ? a : b);
    if (typical != null) {
      lo = lo < typical! ? lo : typical!;
      hi = hi > typical! ? hi : typical!;
    }
    final pad = (hi - lo) * 0.08 + 1;
    lo -= pad;
    hi += pad;
    double x(int i) => size.width * i / (pts.length - 1);
    double y(double v) => size.height * (1 - (v - lo) / (hi - lo));

    if (!compact) {
      final g = Paint()
        ..color = grid
        ..strokeWidth = 1;
      for (var k = 0; k <= 2; k++) {
        final gy = size.height * k / 2;
        canvas.drawLine(Offset(0, gy), Offset(size.width, gy), g);
      }
    }

    final bandPath = Path()..moveTo(x(0), y(pts.first.p90));
    for (var i = 1; i < pts.length; i++) {
      bandPath.lineTo(x(i), y(pts[i].p90));
    }
    for (var i = pts.length - 1; i >= 0; i--) {
      bandPath.lineTo(x(i), y(pts[i].p10));
    }
    bandPath.close();
    canvas.drawPath(bandPath, Paint()..color = band);

    if (typical != null) {
      final ty = y(typical!);
      final dash = Paint()
        ..color = reference
        ..strokeWidth = 1.2;
      for (var dx = 0.0; dx < size.width; dx += 8) {
        canvas.drawLine(Offset(dx, ty), Offset((dx + 4).clamp(0, size.width), ty), dash);
      }
    }

    final p50 = Path()..moveTo(x(0), y(pts.first.p50));
    for (var i = 1; i < pts.length; i++) {
      p50.lineTo(x(i), y(pts[i].p50));
    }
    canvas
      ..drawPath(
        p50,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = compact ? 1.5 : 2
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawCircle(Offset(x(pts.length - 1), y(pts.last.p50)), compact ? 2.5 : 3.5, Paint()..color = line);
  }

  @override
  bool shouldRepaint(_FanPainter old) => old.pts != pts || old.line != line || old.band != band;
}
