import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kairos_pager/core/fleet_providers.dart';
import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';
import 'package:kairos_pager/features/reactor/reactor_detail_screen.dart' show expectedText;
import 'package:kairos_pager/widgets/format.dart';
import 'package:kairos_pager/widgets/ui.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Full-screen alarm. Red hero with the three numbers that matter (time to act,
/// health, dissolved oxygen), then the one action, then why, with the decision
/// buttons pinned to the bottom. One pulse on entry, then calm.
class AlarmTakeoverScreen extends ConsumerStatefulWidget {
  const AlarmTakeoverScreen({required this.reactorId, super.key});

  final String reactorId;

  @override
  ConsumerState<AlarmTakeoverScreen> createState() => _AlarmTakeoverScreenState();
}

class _AlarmTakeoverScreenState extends ConsumerState<AlarmTakeoverScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: KMotion.slow * 3)
    ..forward();
  bool _showWhy = false;

  @override
  void initState() {
    super.initState();
    unawaited(HapticFeedback.heavyImpact());
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _close() => context.canPop() ? context.pop() : context.go('/home');

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final r = ref.watch(reactorProvider(widget.reactorId));
    final plant = ref.watch(plantOfReactorProvider(widget.reactorId));
    final card = r?.insight?.card;
    final contributors = (r?.lastAlarm?.contributors ?? const <Contribution>[]).take(3).toList();
    final remaining = r?.ponrRemainingH;
    final title = card?.title ?? 'Alarm on ${widget.reactorId}';
    final action =
        card?.action ??
        (contributors.isEmpty
            ? 'Open details for the diagnosis.'
            : 'Check ${sensorLabel(contributors.first.variable).toLowerCase()} now.');
    final doPct = r?.tick?.value('do_pct');
    final where = [
      plant?.name ?? widget.reactorId,
      if (plant != null) r?.shortId ?? '',
      if (r != null) 'Batch ${r.batchId}',
    ].where((s) => s.isNotEmpty).join('  ·  ');

    return Scaffold(
      backgroundColor: KColors.bgBase,
      body: Column(
        children: [
          _Hero(
            pulse: _pulse,
            title: title,
            where: where,
            onClose: _close,
            stats: [
              (
                'Time to act',
                remaining == null ? '—' : (remaining <= 0 ? 'Passed' : fmtHours(remaining)),
                LucideIcons.timer,
              ),
              (
                'Detected at',
                r?.lastAlarm == null ? '—' : '${r!.lastAlarm!.tH.toStringAsFixed(0)} h',
                LucideIcons.radar,
              ),
              ('Dissolved O₂', doPct == null ? '—' : '${doPct.toStringAsFixed(0)}%', LucideIcons.wind),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(KSpace.s4, KSpace.s6, KSpace.s4, KSpace.s4),
              children: [
                _ActionCard(
                  action: action,
                  expected: card != null && card.expectedEffect.isNotEmpty
                      ? expectedText(card.expectedEffect)
                      : null,
                ),
                const SizedBox(height: KSpace.s3),
                if (contributors.isNotEmpty || card?.summary != null)
                  KCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(LucideIcons.searchCode, size: 16, color: KColors.textSecondary),
                            const SizedBox(width: KSpace.s2),
                            Text(
                              'What changed',
                              style: KText.display(KSize.md + 1),
                            ),
                          ],
                        ),
                        const SizedBox(height: KSpace.s3),
                        for (final c in contributors) _ContributorBar(c),
                        if (card?.summary != null) ...[
                          InkWell(
                            onTap: () => setState(() => _showWhy = !_showWhy),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: KSpace.s2),
                              child: Row(
                                children: [
                                  Text(
                                    _showWhy ? 'Hide the full diagnosis' : 'Read the full diagnosis',
                                    style: KText.ui(
                                      KSize.sm,
                                      weight: FontWeight.w600,
                                      color: KColors.accentX500,
                                    ),
                                  ),
                                  Icon(
                                    _showWhy ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                                    size: 16,
                                    color: KColors.accentX500,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AnimatedCrossFade(
                            duration: KMotion.base,
                            crossFadeState: _showWhy ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                            firstChild: const SizedBox(width: double.infinity),
                            secondChild: Text(
                              card!.summary,
                              style: KText.ui(KSize.sm, color: KColors.textSecondary),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: KSpace.s3),
                Row(
                  children: [
                    Icon(LucideIcons.info, size: 13, color: KColors.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Model estimate on benchmark data. Verify before changing setpoints.',
                        style: KText.ui(KSize.xs, color: KColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _Actions(
            onAck: () {
              fireAndForget(ref.read(alertsProvider.notifier).acknowledge(widget.reactorId));
              _close();
            },
            onDetails: () => context.pushReplacement('/reactor/${widget.reactorId}'),
            onAsk: () => context.push('/chat?reactor=${widget.reactorId}'),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.pulse,
    required this.title,
    required this.where,
    required this.onClose,
    required this.stats,
  });

  final Animation<double> pulse;
  final String title;
  final String where;
  final VoidCallback onClose;
  final List<(String, String, IconData)> stats;

  @override
  Widget build(BuildContext context) {
    final red = KColors.stateAlarm;
    final deep = Color.lerp(red, Colors.black, 0.38)!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [red, deep]),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(KSpace.s4, KSpace.s2, KSpace.s4, KSpace.s6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Glass(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text('ALARM', style: KText.overline(color: Colors.white)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onClose,
                    tooltip: 'Close',
                    icon: const Icon(LucideIcons.x, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: KSpace.s3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedBuilder(
                    animation: pulse,
                    builder: (_, _) {
                      final t = Curves.easeOut.transform(pulse.value);
                      return SizedBox(
                        width: 64,
                        height: 64,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 52 + 12 * t,
                              height: 52 + 12 * t,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.25 * (1 - t)),
                              ),
                            ),
                            Container(
                              width: 52,
                              height: 52,
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: Icon(LucideIcons.siren, color: KColors.stateAlarm, size: 26),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: KSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: KText.display(KSize.x2xl + 2, weight: FontWeight.w800, color: Colors.white),
                        ),
                        const SizedBox(height: KSpace.s1),
                        Text(
                          where,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: KText.ui(KSize.sm, color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: KSpace.s6),
              Row(
                children: [
                  for (final (i, s) in stats.indexed) ...[
                    if (i > 0) const SizedBox(width: KSpace.s2),
                    Expanded(
                      child: _Glass(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(s.$3, size: 13, color: Colors.white.withValues(alpha: 0.85)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    s.$1,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: KText.ui(KSize.xs, color: Colors.white.withValues(alpha: 0.85)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.$2,
                              style: KText.display(KSize.xl, weight: FontWeight.w800, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({required this.child, this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
    ),
    child: child,
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action, this.expected});

  final String action;
  final String? expected;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(KSpace.s4),
    decoration: BoxDecoration(
      color: KColors.accentX500.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: KColors.accentX500.withValues(alpha: 0.35)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: KColors.accentX500, borderRadius: BorderRadius.circular(10)),
              child: const Icon(LucideIcons.zap, size: 14, color: Colors.white),
            ),
            const SizedBox(width: KSpace.s2),
            Text(
              'Do this now',
              style: KText.ui(KSize.sm, weight: FontWeight.w700, color: KColors.accentX500),
            ),
          ],
        ),
        const SizedBox(height: KSpace.s3),
        Text(action, style: KText.display(KSize.lg + 1)),
        if (expected != null) ...[
          const SizedBox(height: KSpace.s2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.trendingUp, size: 14, color: KColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(expected!, style: KText.ui(KSize.sm, color: KColors.textSecondary)),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _ContributorBar extends StatelessWidget {
  const _ContributorBar(this.c);

  final Contribution c;

  @override
  Widget build(BuildContext context) {
    final share = (c.pct / 100).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                c.low ? LucideIcons.arrowDownRight : LucideIcons.arrowUpRight,
                size: 15,
                color: KColors.stateAlarm,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${sensorLabel(c.variable)} ${c.low ? 'low' : 'high'}',
                  style: KText.ui(KSize.sm, weight: FontWeight.w600),
                ),
              ),
              Text('${c.pct.toStringAsFixed(0)}%', style: KText.mono(KSize.sm, color: KColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 6,
              backgroundColor: KColors.bgInset,
              color: KColors.stateAlarm,
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onAck, required this.onDetails, required this.onAsk});

  final VoidCallback onAck;
  final VoidCallback onDetails;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: KColors.bgSurface,
      border: Border(top: BorderSide(color: KColors.borderSubtle)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(KSpace.s4, KSpace.s3, KSpace.s4, KSpace.s3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: KColors.stateAlarm,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: onAck,
                icon: const Icon(LucideIcons.checkCircle2, size: 20),
                label: Text(
                  'Acknowledge alarm',
                  style: KText.ui(KSize.md, weight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: KSpace.s2),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: onDetails,
                      icon: const Icon(LucideIcons.gauge, size: 18),
                      label: const Text('Reactor details'),
                    ),
                  ),
                ),
                const SizedBox(width: KSpace.s2),
                AskKairosButton(onPressed: onAsk, compact: true),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
