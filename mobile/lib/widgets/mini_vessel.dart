import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';

/// 2D animated vessel: bubbles follow aeration, impeller follows agitation,
/// rim colour follows health. Mirrors the web twin's bindings.
class MiniVessel extends StatefulWidget {
  const MiniVessel({
    required this.state,
    super.key,
    this.aeration = 60,
    this.rpm = 100,
    this.doPct,
    this.width = 64,
    this.height = 96,
  });

  final HealthState state;
  final double aeration;
  final double rpm;
  final double? doPct;
  final double width;
  final double height;

  @override
  State<MiniVessel> createState() => _MiniVesselState();
}

class _MiniVesselState extends State<MiniVessel> with SingleTickerProviderStateMixin {
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
    final reduce = MediaQuery.of(context).disableAnimations;
    return ExcludeSemantics(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _VesselPainter(
              t: reduce ? 0 : _c.value,
              state: widget.state,
              aeration: widget.aeration,
              rpm: widget.rpm,
              doPct: widget.doPct,
            ),
          ),
        ),
      ),
    );
  }
}

class _VesselPainter extends CustomPainter {
  _VesselPainter({
    required this.t,
    required this.state,
    required this.aeration,
    required this.rpm,
    this.doPct,
  });

  final double t;
  final HealthState state;
  final double aeration;
  final double rpm;
  final double? doPct;

  @override
  void paint(Canvas canvas, Size s) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 6, s.width - 8, s.height - 12),
      const Radius.circular(14),
    );
    final rim = stateColor(state);
    // Broth: teal, shifting warmer as DO falls.
    final doFrac = ((doPct ?? 60) / 100).clamp(0.0, 1.0);
    final broth = Color.lerp(const Color(0xFF7C5A1E), KColors.accentX600, doFrac)!.withValues(alpha: 0.35);
    final level = body.top + body.height * 0.22;

    canvas
      ..save()
      ..clipRRect(body)
      ..drawRect(Rect.fromLTRB(body.left, level, body.right, body.bottom), Paint()..color = broth);

    // Bubbles: count follows aeration.
    final n = (aeration / 8).clamp(3, 12).round();
    final bubble = Paint()..color = KColors.textPrimary.withValues(alpha: 0.35);
    for (var i = 0; i < n; i++) {
      final phase = (t * (1 + aeration / 80) + i / n) % 1.0;
      final x = body.left + body.width * (0.2 + 0.6 * ((i * 37) % n) / n) + math.sin((phase + i) * 6) * 2;
      final y = body.bottom - 8 - (body.bottom - 8 - level) * phase;
      canvas.drawCircle(Offset(x, y), 1.4 + (i % 3) * 0.5, bubble);
    }

    // Shaft and impeller: blade width oscillates with rotation speed.
    final cx = s.width / 2;
    final shaft = Paint()
      ..color = KColors.textSecondary
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(cx, 0), Offset(cx, body.bottom - body.height * 0.25), shaft);
    final angle = t * 2 * math.pi * (rpm / 25);
    final blade = 9 * math.cos(angle).abs() + 2;
    final iy = body.bottom - body.height * 0.25;
    canvas
      ..drawRect(
        Rect.fromCenter(center: Offset(cx, iy), width: blade * 2, height: 4),
        Paint()..color = KColors.textSecondary,
      )
      ..restore()
      ..drawRRect(
        body,
        Paint()
          ..color = rim.withValues(alpha: state == HealthState.normal ? 0.45 : 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = state == HealthState.normal ? 1.2 : 2,
      );
  }

  @override
  bool shouldRepaint(_VesselPainter old) => true;
}
