import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kairos_pager/core/fleet_providers.dart';
import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';
import 'package:kairos_pager/features/reactor/reactor_detail_screen.dart' show expectedText;
import 'package:kairos_pager/widgets/format.dart';
import 'package:kairos_pager/widgets/gauge.dart';
import 'package:kairos_pager/widgets/ponr_countdown.dart';

/// Full-screen alarm: title, reactor, countdown, the action in large type.
/// One pulse on entry, then calm (no endless flashing).
class AlarmTakeoverScreen extends ConsumerStatefulWidget {
  const AlarmTakeoverScreen({required this.reactorId, super.key});

  final String reactorId;

  @override
  ConsumerState<AlarmTakeoverScreen> createState() => _AlarmTakeoverScreenState();
}

class _AlarmTakeoverScreenState extends ConsumerState<AlarmTakeoverScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: KMotion.slow * 2)
    ..forward();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _close() => context.canPop() ? context.pop() : context.go('/home');

  @override
  Widget build(BuildContext context) {
    final r = ref.watch(reactorProvider(widget.reactorId));
    final plant = ref.watch(plantOfReactorProvider(widget.reactorId));
    final card = r?.insight?.card;
    final contributors = r?.lastAlarm?.contributors ?? const <Contribution>[];
    final remaining = r?.ponrRemainingH;
    final title = card?.title ?? 'Alarm on ${widget.reactorId}';
    final action =
        card?.action ??
        (contributors.isEmpty
            ? 'Open details for the diagnosis.'
            : 'Check ${sensorLabel(contributors.first.variable).toLowerCase()} now.');

    return Scaffold(
      backgroundColor: KColors.bgBase,
      body: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final glow = (1 - (_pulse.value * 2 - 1).abs()) * 0.35 + 0.08;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.6),
                radius: 1.2,
                colors: [
                  KColors.stateAlarm.withValues(alpha: glow),
                  KColors.bgBase,
                ],
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              padding: const EdgeInsets.all(KSpace.s6),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight - KSpace.s6 * 2),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: KSpace.s3, vertical: KSpace.s1),
                            decoration: BoxDecoration(
                              color: KColors.stateAlarm,
                              borderRadius: BorderRadius.circular(KRadius.full),
                            ),
                            child: Text('ALARM', style: KText.overline(color: Colors.white)),
                          ),
                          const SizedBox(width: KSpace.s3),
                          Expanded(
                            child: Text(
                              plant == null
                                  ? '${widget.reactorId} · batch ${r?.batchId ?? '—'}'
                                  : '${plant.name} · ${r?.shortId ?? widget.reactorId}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: KText.mono(KSize.md, color: KColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: KSpace.s6),
                      Text(title, style: KText.display(KSize.x3xl + 2, weight: FontWeight.w800)),
                      if (card?.summary != null) ...[
                        const SizedBox(height: KSpace.s2),
                        Text(card!.summary, style: KText.ui(KSize.lg, color: KColors.textSecondary)),
                      ],
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (remaining != null)
                            PonrCountdown(remainingH: remaining, totalH: r?.lastAlarm?.ponrHours, size: 150),
                          Gauge(spec: GaugeSpec.doPct, value: r?.tick?.value('do_pct'), size: 128),
                        ],
                      ),
                      const Spacer(),
                      Text('Do this', style: KText.overline(color: KColors.accentX500)),
                      const SizedBox(height: KSpace.s1),
                      Text(action, style: KText.display(KSize.xl + 2)),
                      if (card != null && card.expectedEffect.isNotEmpty) ...[
                        const SizedBox(height: KSpace.s1),
                        Text(
                          expectedText(card.expectedEffect),
                          style: KText.ui(KSize.md, color: KColors.textSecondary),
                        ),
                      ],
                      const SizedBox(height: KSpace.s8),
                      FilledButton(
                        onPressed: () async {
                          fireAndForget(ref.read(alertsProvider.notifier).acknowledge(widget.reactorId));
                          _close();
                        },
                        child: const Text('Acknowledge'),
                      ),
                      const SizedBox(height: KSpace.s3),
                      OutlinedButton(
                        onPressed: () => context.pushReplacement('/reactor/${widget.reactorId}'),
                        child: const Text('View details'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
