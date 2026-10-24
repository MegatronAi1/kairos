import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/widgets/format.dart';

/// Thousands separator for whole numbers ("3,300").
String fmtThousands(double v) {
  final s = v.round().abs().toString();
  final b = StringBuffer(v < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// Plain-language direction for a deviating variable ("dissolved oxygen running low").
String deviationPhrase(Contribution c) =>
    '${sensorLabel(c.variable).toLowerCase()} running ${c.low ? 'low' : 'high'}';

/// One human sentence for a reactor, used on cards and headers.
String statusSentence(ReactorView r) {
  final f = r.tick?.forecast;
  final h = r.tick?.health;
  switch (r.state) {
    case HealthState.alarm:
      final title = r.insight?.card.title;
      if (r.acknowledged) return '${title ?? 'Alarm'} · acknowledged';
      return title ?? 'Needs attention now';
    case HealthState.watch:
      final contributors = h?.topContributors ?? const <Contribution>[];
      return contributors.isEmpty
          ? 'Drifting from normal batches'
          : 'Drifting · ${deviationPhrase(contributors.first)}';
    case HealthState.normal:
      if (r.tick == null) return 'Waiting for the first readings';
      if (f == null) return 'Running smoothly · forecast starts shortly';
      final pct = f.vsGoldenPct.round();
      final track = pct >= 95 ? 'on track for' : (pct >= 80 ? 'heading for' : 'below typical, heading for');
      return 'Running smoothly · $track ${fmtThousands(f.p50)} ${f.unit}';
  }
}
