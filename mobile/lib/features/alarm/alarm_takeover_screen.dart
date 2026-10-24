import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';
import 'package:kairos_pager/widgets/format.dart';
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

  void _close() => context.canPop() ? context.pop() : context.go('/plant');

  @override
  Widget build(BuildContext context) {
    final r = ref.watch(reactorProvider(widget.reactorId));
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
                            child: Text('ALARM', style: KText.overline(color: KColors.bgBase)),
                          ),
                          const SizedBox(width: KSpace.s3),
                          Text(
                            '${widget.reactorId} · batch ${r?.batchId ?? '—'}',
                            style: KText.mono(KSize.md, color: KColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: KSpace.s6),
                      Text(title, style: KText.ui(KSize.x3xl, weight: FontWeight.w600)),
                      if (card?.summary != null) ...[
                        const SizedBox(height: KSpace.s2),
                        Text(card!.summary, style: KText.ui(KSize.lg, color: KColors.textSecondary)),
                      ],
                      const Spacer(),
                      if (remaining != null)
                        Center(
                          child: PonrCountdown(remainingH: remaining, totalH: r?.lastAlarm?.ponrHours),
                        ),
                      const Spacer(),
                      Text('Do this', style: KText.overline(color: KColors.accentX500)),
                      const SizedBox(height: KSpace.s1),
                      Text(action, style: KText.ui(KSize.x2xl, weight: FontWeight.w500)),
                      if (card != null && card.expectedEffect.isNotEmpty) ...[
                        const SizedBox(height: KSpace.s1),
                        Text(
                          'Expected: ${card.expectedEffect} (model estimate)',
                          style: KText.ui(KSize.md, color: KColors.textSecondary),
                        ),
                      ],
                      const SizedBox(height: KSpace.s8),
                      FilledButton(
                        onPressed: () async {
                          fireAndForget(ref.read(reactorsProvider.notifier).acknowledge(widget.reactorId));
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
