import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';
import 'package:kairos_pager/core/ws/event_source.dart';
import 'package:kairos_pager/features/plant/reactor_card.dart';
import 'package:kairos_pager/features/process/process_picker.dart';
import 'package:kairos_pager/widgets/format.dart';
import 'package:kairos_pager/widgets/states.dart';
import 'package:lucide_icons/lucide_icons.dart';

class PlantScreen extends ConsumerWidget {
  const PlantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reactors = ref.watch(reactorsProvider).values.toList()..sort((a, b) => a.id.compareTo(b.id));
    final status = ref.watch(connectionStatusProvider).value ?? ConnectionStatus.connecting;
    final pairing = ref.watch(pairingProvider);

    Widget body;
    if (reactors.isEmpty && status == ConnectionStatus.offline) {
      body = ErrorState(
        title: "Can't reach the control room",
        message: "We'll keep retrying. Make sure the laptop running Kairos is on and on the same network.",
        onRetry: () => ref.invalidate(eventSourceProvider),
      );
    } else if (reactors.isEmpty) {
      body = ListView(
        padding: const EdgeInsets.all(KSpace.s4),
        children: [
          for (var i = 0; i < 4; i++) ...[
            const Skeleton(height: 132, radius: KRadius.card),
            const SizedBox(height: KSpace.s3),
          ],
        ],
      );
    } else {
      body = RefreshIndicator(
        color: KColors.accentX500,
        onRefresh: () async => ref.invalidate(eventSourceProvider),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(KSpace.s4, KSpace.s2, KSpace.s4, 96),
          itemCount: reactors.length + 1,
          separatorBuilder: (_, i) => SizedBox(height: i == 0 ? KSpace.s6 : KSpace.s4),
          itemBuilder: (context, i) => i == 0
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ProcessBanner(),
                    _PlantSummary(reactors: reactors),
                  ],
                )
              : ReactorCard(
                  reactor: reactors[i - 1],
                  onTap: () => context.push('/reactor/${reactors[i - 1].id}'),
                ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Plant', style: KText.display(KSize.xl)),
        actions: [
          _ConnectionDot(status: status, label: pairing?.label ?? ''),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(LucideIcons.settings, size: 20),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: body,
      floatingActionButton: reactors.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: KColors.bgElevated,
              foregroundColor: KColors.textPrimary,
              onPressed: () => context.push('/chat'),
              icon: const Icon(LucideIcons.messageCircle, size: 18),
              label: Text('Ask Kairos', style: KText.ui(KSize.md, weight: FontWeight.w500)),
            ),
    );
  }
}

class _ConnectionDot extends StatelessWidget {
  const _ConnectionDot({required this.status, required this.label});

  final ConnectionStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (color, text) = switch (status) {
      ConnectionStatus.live => (KColors.stateHealthy, 'Live'),
      ConnectionStatus.connecting => (KColors.stateWatch, 'Connecting'),
      ConnectionStatus.offline => (KColors.stateAlarm, 'Offline'),
    };
    return Tooltip(
      message: '$text · $label',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: KSpace.s2),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: KSpace.s1),
            Text(text, style: KText.ui(KSize.xs, color: KColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// Headline for the whole plant: one sentence, state counts and total power.
class _PlantSummary extends StatelessWidget {
  const _PlantSummary({required this.reactors});

  final List<ReactorView> reactors;

  @override
  Widget build(BuildContext context) {
    final alarms = reactors.where((r) => r.state == HealthState.alarm && !r.acknowledged).length;
    final watching = reactors.where((r) => r.state == HealthState.watch).length;
    final n = reactors.length;
    final headline = alarms > 0
        ? '$alarms of $n reactors ${alarms == 1 ? 'needs' : 'need'} attention'
        : watching > 0
        ? '$watching of $n drifting, Kairos is watching'
        : 'All $n reactors running smoothly';
    final power = reactors.fold<double>(0, (a, r) => a + (r.tick?.derived['power_kw'] ?? 0));
    final color = alarms > 0
        ? KColors.stateAlarm
        : watching > 0
        ? KColors.stateWatch
        : KColors.stateHealthy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(headline, style: KText.display(KSize.x3xl - 4, color: color)),
        const SizedBox(height: KSpace.s3),
        Row(
          children: [
            for (final r in reactors) ...[
              _Dot(color: stateColor(r.state), label: r.id),
              const SizedBox(width: KSpace.s3),
            ],
            const Spacer(),
            Icon(Icons.bolt_rounded, size: 16, color: KColors.textMuted),
            Text(' ${fmt(power, decimals: 0)} kW', style: KText.mono(KSize.sm, color: KColors.textSecondary)),
          ],
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: KSpace.s1),
      Text(label, style: KText.mono(KSize.sm, color: KColors.textSecondary)),
    ],
  );
}
