import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kairos_pager/core/models/process.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';

/// Simplified fermenter schematic per reactor kind, with probe labels showing the
/// catalog's typical setpoint ranges. Mirrors web/src/features/process/FermenterDiagram.tsx.
class FermenterSchematic extends StatefulWidget {
  const FermenterSchematic({required this.process, super.key});

  final ProcessDetail process;

  @override
  State<FermenterSchematic> createState() => _FermenterSchematicState();
}

class _FermenterSchematicState extends State<FermenterSchematic> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void initState() {
    super.initState();
    unawaited(_c.repeat());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.process;
    final reduce = MediaQuery.of(context).disableAnimations;
    final palette = _Palette(
      line: KColors.textSecondary,
      muted: KColors.textMuted,
      inset: KColors.bgInset,
      surface: KColors.bgSurface,
      elevated: KColors.bgElevated,
      border: KColors.borderStrong,
      accent: KColors.accentX500,
      broth: KColors.accentX500.withValues(alpha: 0.16),
      text: KColors.textPrimary,
      alarm: KColors.stateAlarm,
      light: KColors.stateWatch,
      gas: KColors.chartSeries2,
    );
    final probes = <({String label, String? value})>[
      if (p.reactor == ReactorKind.photobioreactor) (label: 'Light', value: p.rangeFor(['light_umol_m2_s'])),
      if (p.reactor == ReactorKind.gasFermenter)
        (label: 'Gas', value: p.rangeFor(['h2_o2_ratio', 'pressure_bar', 'gas_flow_vvm'])),
      (label: 'DO', value: p.rangeFor(['do_pct', 'dissolved_oxygen_pct'])),
      (label: 'pH', value: p.rangeFor(['ph'])),
      (label: 'Temp', value: p.rangeFor(['temp_c', 'temperature_c'])),
    ];
    return Semantics(
      label: '${p.reactor.label} schematic for ${p.name}',
      child: AspectRatio(
        aspectRatio: 1.1,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _SchematicPainter(
              kind: p.reactor,
              t: reduce ? 0 : _c.value,
              colors: palette,
              probes: probes,
            ),
          ),
        ),
      ),
    );
  }
}

class _Palette {
  const _Palette({
    required this.line,
    required this.muted,
    required this.inset,
    required this.surface,
    required this.elevated,
    required this.border,
    required this.accent,
    required this.broth,
    required this.text,
    required this.alarm,
    required this.light,
    required this.gas,
  });

  final Color line;
  final Color muted;
  final Color inset;
  final Color surface;
  final Color elevated;
  final Color border;
  final Color accent;
  final Color broth;
  final Color text;
  final Color alarm;
  final Color light;
  final Color gas;
}

class _SchematicPainter extends CustomPainter {
  _SchematicPainter({required this.kind, required this.t, required this.colors, required this.probes});

  final ReactorKind kind;
  final double t;
  final _Palette colors;
  final List<({String label, String? value})> probes;

  late Size _s;

  // Design space is 300 x 272; scale to the canvas.
  double get _k => _s.width / 300;
  Offset _o(double x, double y) => Offset(x * _k, y * _k);
  Rect _r(double x, double y, double w, double h) => Rect.fromLTWH(x * _k, y * _k, w * _k, h * _k);

  Paint get _stroke => Paint()
    ..color = colors.line
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6 * _k;

  Paint _fill(Color c) => Paint()..color = c;

  void _text(
    Canvas canvas,
    String s,
    Offset at, {
    double size = 9,
    Color? color,
    bool bold = false,
    bool center = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: KText.ui(
          size * _k,
          weight: bold ? FontWeight.w600 : FontWeight.w400,
          color: color ?? colors.muted,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 140 * _k);
    tp.paint(canvas, center ? at - Offset(tp.width / 2, tp.height / 2) : at);
  }

  void _box(Canvas canvas, double x, double y, double w, double h, String title) {
    final rr = RRect.fromRectAndRadius(_r(x, y, w, h), Radius.circular(6 * _k));
    canvas
      ..drawRRect(rr, _fill(colors.surface))
      ..drawRRect(
        rr,
        Paint()
          ..color = colors.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 * _k,
      );
    _text(canvas, title, _o(x + w / 2, y + h / 2), size: 8.5, color: colors.text, bold: true, center: true);
  }

  /// Dashed flow line whose dashes move with t.
  void _flow(Canvas canvas, List<Offset> pts, Color c) {
    final path = Path()..moveTo(pts.first.dx * _k, pts.first.dy * _k);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx * _k, p.dy * _k);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * _k
        ..strokeCap = StrokeCap.round,
    );
    final dash = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * _k
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      const seg = 6.0;
      final offset = (t * 4 * seg * 2) % (seg * 2);
      for (var d = -seg * 2 + offset; d < metric.length / _k; d += seg * 2) {
        final a = math.max(0, d) * _k;
        final b = math.min(metric.length, (d + seg) * _k);
        if (b > a) canvas.drawPath(metric.extractPath(a, b), dash);
      }
    }
  }

  void _bubbles(Canvas canvas, Rect area, int n) {
    final p = _fill(colors.text.withValues(alpha: 0.35));
    for (var i = 0; i < n; i++) {
      final phase = (t * (1 + (i % 4) * 0.2) + i / n) % 1.0;
      final x = area.left + area.width * (((i * 37) % 100) / 100);
      final y = area.bottom - area.height * phase;
      canvas.drawCircle(Offset(x, y), (1.4 + (i % 3) * 0.6) * _k, p);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _s = size;
    switch (kind) {
      case ReactorKind.stirredTank:
        _stirredTank(canvas);
      case ReactorKind.airlift:
        _airlift(canvas);
      case ReactorKind.photobioreactor:
        _photobioreactor(canvas);
      case ReactorKind.gasFermenter:
        _gasFermenter(canvas);
    }
    _probes(canvas);
    _controller(canvas);
  }

  void _stirredTank(Canvas canvas) {
    _box(canvas, 6, 20, 60, 26, 'Feed');
    _box(canvas, 6, 70, 60, 26, 'Acid / base');
    _box(canvas, 6, 200, 60, 26, 'Air');
    _flow(canvas, const [Offset(66, 33), Offset(110, 33), Offset(110, 52)], colors.accent);
    _flow(canvas, const [Offset(66, 83), Offset(100, 83), Offset(100, 76), Offset(106, 76)], colors.gas);
    _flow(canvas, const [Offset(66, 213), Offset(150, 213), Offset(150, 205)], colors.line);
    final body = RRect.fromRectAndRadius(_r(106, 52, 90, 160), Radius.circular(18 * _k));
    canvas
      ..drawRRect(body, _fill(colors.inset))
      ..save()
      ..clipRRect(body)
      ..drawRect(_r(106, 80, 90, 140), _fill(colors.broth))
      ..restore()
      ..drawRRect(body, _stroke);
    _bubbles(canvas, _r(118, 90, 66, 112), 16);
    canvas.drawLine(_o(151, 40), _o(151, 190), _stroke);
    for (final y in [120.0, 170.0]) {
      final w = 22 * (0.3 + 0.7 * math.cos(t * 2 * math.pi * 3).abs());
      canvas.drawRect(_r(151 - w / 2, y - 2, w, 4), _fill(colors.line));
    }
    canvas.drawLine(_o(131, 202), _o(171, 202), _stroke);
  }

  void _airlift(Canvas canvas) {
    _box(canvas, 6, 150, 60, 26, 'Feed');
    _box(canvas, 6, 200, 60, 26, 'Air');
    _box(canvas, 234, 150, 60, 26, 'Harvest');
    final riser = RRect.fromRectAndRadius(_r(96, 40, 36, 180), Radius.circular(14 * _k));
    final down = RRect.fromRectAndRadius(_r(168, 40, 36, 180), Radius.circular(14 * _k));
    for (final r in [riser, down]) {
      canvas
        ..drawRRect(r, _fill(colors.inset))
        ..save()
        ..clipRRect(r)
        ..drawRect(_r(90, 60, 120, 170), _fill(colors.broth))
        ..restore()
        ..drawRRect(r, _stroke);
    }
    canvas
      ..drawArc(_r(108, 14, 84, 52), math.pi, math.pi, false, _stroke)
      ..drawArc(_r(108, 194, 84, 52), 0, math.pi, false, _stroke);
    _bubbles(canvas, _r(102, 60, 24, 150), 12);
    _flow(canvas, const [Offset(114, 205), Offset(114, 55)], colors.accent);
    _flow(canvas, const [Offset(186, 55), Offset(186, 205)], colors.accent);
    _flow(canvas, const [Offset(66, 163), Offset(96, 163)], colors.accent);
    _flow(canvas, const [Offset(66, 213), Offset(114, 213)], colors.line);
    _flow(canvas, const [Offset(204, 163), Offset(234, 163)], colors.light);
    _text(canvas, 'riser', _o(114, 228), size: 8, center: true);
    _text(canvas, 'downcomer', _o(186, 228), size: 8, center: true);
  }

  void _photobioreactor(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(_r(80, 40, 140, 140), Radius.circular(8 * _k)),
      _fill(colors.light.withValues(alpha: 0.08)),
    );
    for (var i = 0; i < 7; i++) {
      canvas.drawLine(
        _o(88 + i * 20.0, 30),
        _o(88 + i * 20.0, 37),
        Paint()
          ..color = colors.light.withValues(alpha: 0.5 + 0.5 * math.sin(t * 2 * math.pi + i).abs())
          ..strokeWidth = 2 * _k
          ..strokeCap = StrokeCap.round,
      );
    }
    for (var i = 0; i < 6; i++) {
      final y = 52.0 + i * 22;
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(_r(86, y - 7, 128, 14), Radius.circular(7 * _k)),
          _fill(colors.broth),
        )
        ..drawRRect(RRect.fromRectAndRadius(_r(86, y - 7, 128, 14), Radius.circular(7 * _k)), _stroke);
    }
    _flow(canvas, const [
      Offset(90, 52),
      Offset(210, 52),
      Offset(210, 74),
      Offset(90, 74),
      Offset(90, 96),
      Offset(210, 96),
    ], colors.accent);
    _box(canvas, 6, 60, 60, 26, 'Degasser');
    _box(canvas, 6, 140, 60, 26, 'CO₂');
    _box(canvas, 234, 140, 60, 26, 'Harvest');
    _flow(canvas, const [Offset(66, 153), Offset(86, 153)], colors.line);
    _flow(canvas, const [Offset(214, 153), Offset(234, 153)], colors.light);
  }

  void _gasFermenter(Canvas canvas) {
    _box(canvas, 6, 20, 60, 26, 'H₂');
    _box(canvas, 6, 70, 60, 26, 'CO₂');
    _box(canvas, 6, 120, 60, 26, 'Medium');
    _box(canvas, 234, 20, 60, 26, 'Recycle');
    _box(canvas, 234, 150, 60, 26, 'Harvest');
    final col = RRect.fromRectAndRadius(_r(116, 34, 68, 180), Radius.circular(20 * _k));
    canvas
      ..drawRRect(col, _fill(colors.inset))
      ..save()
      ..clipRRect(col)
      ..drawRect(_r(110, 64, 80, 160), _fill(colors.broth))
      ..restore()
      ..drawRRect(col, _stroke);
    _bubbles(canvas, _r(124, 70, 52, 135), 18);
    _flow(canvas, const [
      Offset(66, 33),
      Offset(92, 33),
      Offset(92, 220),
      Offset(130, 220),
      Offset(130, 214),
    ], colors.gas);
    _flow(canvas, const [
      Offset(66, 83),
      Offset(86, 83),
      Offset(86, 226),
      Offset(150, 226),
      Offset(150, 214),
    ], colors.line);
    _flow(canvas, const [Offset(66, 133), Offset(116, 133)], colors.accent);
    _flow(canvas, const [Offset(150, 34), Offset(150, 22), Offset(234, 22)], colors.muted);
    _flow(canvas, const [Offset(184, 163), Offset(234, 163)], colors.light);
    final warn = RRect.fromRectAndRadius(_r(196, 60, 98, 26), Radius.circular(6 * _k));
    canvas
      ..drawRRect(warn, _fill(colors.alarm.withValues(alpha: 0.12)))
      ..drawRRect(
        warn,
        Paint()
          ..color = colors.alarm
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 * _k,
      );
    _text(
      canvas,
      'H₂ / O₂ safety limit',
      _o(245, 73),
      size: 8,
      color: colors.alarm,
      bold: true,
      center: true,
    );
  }

  /// Probe labels down the right-hand side: name + typical range from the catalog.
  void _probes(Canvas canvas) {
    final x = kind == ReactorKind.airlift || kind == ReactorKind.photobioreactor ? 222.0 : 204.0;
    final top = kind == ReactorKind.photobioreactor
        ? 190.0
        : kind == ReactorKind.gasFermenter
        ? 92.0
        : 52.0;
    for (var i = 0; i < probes.length; i++) {
      final y = top + i * 22.0;
      final pr = probes[i];
      final pill = RRect.fromRectAndRadius(
        _r(x - (kind == ReactorKind.photobioreactor ? 140 : 0), y, 90, 18),
        Radius.circular(9 * _k),
      );
      canvas
        ..drawRRect(pill, _fill(colors.elevated))
        ..drawRRect(
          pill,
          Paint()
            ..color = colors.accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1 * _k,
        )
        ..drawCircle(pill.outerRect.centerLeft + Offset(8 * _k, 0), 3 * _k, _fill(colors.accent));
      _text(
        canvas,
        pr.value == null ? pr.label : '${pr.label}  ${pr.value}',
        pill.outerRect.topLeft + Offset(15 * _k, 3.5 * _k),
        size: 8,
        color: colors.text,
        bold: true,
      );
    }
  }

  void _controller(Canvas canvas) {
    final r = RRect.fromRectAndRadius(_r(90, 244, 120, 24), Radius.circular(8 * _k));
    canvas
      ..drawRRect(r, _fill(colors.accent.withValues(alpha: 0.14)))
      ..drawRRect(
        r,
        Paint()
          ..color = colors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 * _k,
      );
    _text(
      canvas,
      'Kairos + PLC · reads probes, advises setpoints',
      _o(150, 256),
      size: 7.5,
      color: colors.text,
      center: true,
    );
  }

  @override
  bool shouldRepaint(_SchematicPainter old) => old.t != t || old.kind != kind || old.colors != colors;
}
