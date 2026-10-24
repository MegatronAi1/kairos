import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';
import 'package:kairos_pager/widgets/format.dart';

/// Gauge range with a shaded normal band and an optional critical threshold.
class GaugeSpec {
  const GaugeSpec({
    required this.label,
    required this.unit,
    required this.min,
    required this.max,
    required this.bandLo,
    required this.bandHi,
    this.critical,
    this.decimals = 1,
  });

  final String label;
  final String unit;
  final double min;
  final double max;
  final double bandLo;
  final double bandHi;

  /// Values below this are critical (dissolved oxygen).
  final double? critical;
  final int decimals;

  static const doPct = GaugeSpec(
    label: 'Dissolved O₂',
    unit: '% sat',
    min: 0,
    max: 120,
    bandLo: 60,
    bandHi: 95,
    critical: 25,
    decimals: 0,
  );
  static const ph = GaugeSpec(
    label: 'pH',
    unit: '',
    min: 5.8,
    max: 7.2,
    bandLo: 6.2,
    bandHi: 6.8,
    decimals: 2,
  );
  static const temp = GaugeSpec(
    label: 'Temperature',
    unit: '°C',
    min: 23.5,
    max: 26.5,
    bandLo: 24.5,
    bandHi: 25.5,
  );
}

/// Semicircular gauge: track, shaded normal band, critical zone, needle and value.
class Gauge extends StatelessWidget {
  const Gauge({required this.spec, required this.value, super.key, this.size = 104});

  final GaugeSpec spec;
  final double? value;
  final double size;

  Color _valueColor() {
    final v = value;
    if (v == null) return KColors.textMuted;
    if (spec.critical != null && v < spec.critical!) return KColors.stateAlarm;
    if (v < spec.bandLo || v > spec.bandHi) return KColors.stateWatch;
    return KColors.stateHealthy;
  }

  @override
  Widget build(BuildContext context) {
    final c = _valueColor();
    return Semantics(
      label: '${spec.label} ${fmt(value, decimals: spec.decimals)} ${spec.unit}',
      child: SizedBox(
        width: size,
        child: Column(
          children: [
            SizedBox(
              width: size,
              height: size * 0.56,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: value ?? spec.min),
                duration: KMotion.base,
                curve: KMotion.standard,
                builder: (context, v, _) => CustomPaint(
                  painter: _GaugePainter(
                    spec: spec,
                    value: v,
                    needle: c,
                    track: KColors.borderSubtle,
                    band: KColors.stateHealthy.withValues(alpha: 0.3),
                    critical: KColors.stateAlarm.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
            const SizedBox(height: KSpace.s1),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: fmt(value, decimals: spec.decimals),
                    style: KText.display(KSize.xl, color: c),
                  ),
                  if (spec.unit.isNotEmpty)
                    TextSpan(
                      text: ' ${spec.unit}',
                      style: KText.ui(KSize.xs, color: KColors.textMuted),
                    ),
                ],
              ),
            ),
            Text(spec.label, style: KText.ui(KSize.xs, color: KColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.spec,
    required this.value,
    required this.needle,
    required this.track,
    required this.band,
    required this.critical,
  });

  final GaugeSpec spec;
  final double value;
  final Color needle;
  final Color track;
  final Color band;
  final Color critical;

  double _angle(double v) {
    final f = ((v - spec.min) / (spec.max - spec.min)).clamp(0.0, 1.0);
    return math.pi + f * math.pi;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width / 11;
    final center = Offset(size.width / 2, size.height - 3);
    final radius = math.min(size.width / 2, size.height) - stroke / 2 - 3;
    final rect = Rect.fromCircle(center: center, radius: radius);
    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas
      ..drawArc(rect, math.pi, math.pi, false, arc(track))
      ..drawArc(rect, _angle(spec.bandLo), _angle(spec.bandHi) - _angle(spec.bandLo), false, arc(band));
    if (spec.critical != null) {
      canvas.drawArc(rect, math.pi, _angle(spec.critical!) - math.pi, false, arc(critical));
    }
    final a = _angle(value);
    final tip = center + Offset(math.cos(a), math.sin(a)) * (radius + stroke * 0.3);
    canvas
      ..drawLine(
        center,
        tip,
        Paint()
          ..color = needle
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      )
      ..drawCircle(center, stroke * 0.5, Paint()..color = needle);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.value != value || old.needle != needle || old.track != track || old.band != band;
}
