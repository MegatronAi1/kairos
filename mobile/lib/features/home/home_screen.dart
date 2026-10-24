import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kairos_pager/core/fleet_providers.dart';
import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/models/plant.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';
import 'package:kairos_pager/core/ws/event_source.dart';
import 'package:kairos_pager/widgets/format.dart';
import 'package:kairos_pager/widgets/health_ring.dart';
import 'package:kairos_pager/widgets/states.dart';
import 'package:kairos_pager/widgets/status_copy.dart';
import 'package:kairos_pager/widgets/ui.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// At a glance: fleet status, four numbers, what needs attention, the plants.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairing = ref.watch(pairingProvider);
    final status = ref.watch(connectionStatusProvider).value ?? ConnectionStatus.connecting;
    final counts = ref.watch(fleetCountsProvider);
    final reactors = ref.watch(reactorsProvider).values.toList();
    final plants = ref.watch(plantsProvider).value ?? const <PlantSummary>[];
    final attention = reactors.where((r) => r.state != HealthState.normal).toList()
      ..sort((a, b) => urgencyRank(a).compareTo(urgencyRank(b)));

    final hour = DateTime.now().hour;
    final greet = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final name = pairing?.firstName ?? '';

    Widget content;
    if (reactors.isEmpty && status == ConnectionStatus.offline) {
      content = Padding(
        padding: const EdgeInsets.only(top: KSpace.s12),
        child: ErrorState(
          title: "Can't reach Kairos",
          message: 'Retrying. Check the server in Profile.',
          onRetry: () => ref.invalidate(eventSourceProvider),
        ),
      );
    } else if (reactors.isEmpty) {
      content = const Padding(
        padding: EdgeInsets.all(KSpace.s4),
        child: Column(
          children: [
            Skeleton(height: 170, radius: KR.card),
            SizedBox(height: KSpace.s3),
            Skeleton(height: 180, radius: KR.card),
          ],
        ),
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.s4),
            child: _FleetHero(counts: counts),
          ),
          const SizedBox(height: KSpace.s3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.s4),
            child: _KpiGrid(counts: counts, plants: plants.length),
          ),
          SectionLabel(
            'Needs attention',
            action: attention.isEmpty ? null : 'See alerts',
            onAction: () => context.go('/alerts'),
          ),
          if (attention.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpace.s4),
              child: _AllClearCard(),
            )
          else
            SizedBox(
              height: 146,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: KSpace.s4),
                itemCount: attention.length,
                separatorBuilder: (_, _) => const SizedBox(width: KSpace.s3),
                itemBuilder: (_, i) => _AttentionCard(r: attention[i]),
              ),
            ),
          if (plants.isNotEmpty) ...[
            SectionLabel('Plants', action: 'All reactors', onAction: () => context.go('/reactors')),
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: KSpace.s4),
                itemCount: plants.length,
                separatorBuilder: (_, _) => const SizedBox(width: KSpace.s3),
                itemBuilder: (_, i) => _PlantTile(
                  plant: plants[i],
                  reactors: reactors.where((r) => r.plantId == plants[i].id).toList(),
                ),
              ),
            ),
          ],
        ],
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: KColors.accentX500,
          onRefresh: () async {
            ref
              ..invalidate(eventSourceProvider)
              ..invalidate(plantsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: kNavClearance + 56),
            children: [
              PageTitle(
                pairing?.tenantName.isNotEmpty ?? false ? pairing!.tenantName : 'Kairos',
                subtitle: name.isEmpty ? greet : '$greet, $name',
                trailing: _LiveChip(status: status),
              ),
              content,
            ],
          ),
        ),
      ),
      floatingActionButton: reactors.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 76),
              child: AskKairosButton(onPressed: () => context.go('/ask')),
            ),
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip({required this.status});

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, text) = switch (status) {
      ConnectionStatus.live => (KColors.stateHealthy, 'Live'),
      ConnectionStatus.connecting => (KColors.stateWatch, 'Connecting'),
      ConnectionStatus.offline => (KColors.stateAlarm, 'Offline'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(KR.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: KText.ui(KSize.xs, weight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

/// Big status: how many reactors need attention, with a segmented state bar.
class _FleetHero extends StatelessWidget {
  const _FleetHero({required this.counts});

  final FleetCounts counts;

  @override
  Widget build(BuildContext context) {
    final n = counts.needAttention;
    final color = counts.alarm > 0
        ? KColors.stateAlarm
        : counts.watch > 0
        ? KColors.stateWatch
        : KColors.stateHealthy;
    return KCard(
      padding: const EdgeInsets.all(KSpace.s6 - 4),
      color: Color.alphaBlend(color.withValues(alpha: 0.07), KColors.bgSurface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                n == 0 ? 'All clear' : '$n',
                style: KText.display(n == 0 ? 34 : 52, weight: FontWeight.w800, color: color),
              ),
              const SizedBox(width: KSpace.s3),
              if (n > 0)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'of ${counts.total} reactors\nneed attention',
                      style: KText.ui(KSize.md, weight: FontWeight.w500, color: KColors.textSecondary),
                    ),
                  ),
                )
              else
                const Spacer(),
              Icon(n == 0 ? LucideIcons.shieldCheck : LucideIcons.alertTriangle, color: color, size: 28),
            ],
          ),
          const SizedBox(height: KSpace.s4),
          ClipRRect(
            borderRadius: BorderRadius.circular(KR.pill),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (counts.alarm > 0)
                    Expanded(
                      flex: counts.alarm,
                      child: ColoredBox(color: KColors.stateAlarm),
                    ),
                  if (counts.watch > 0)
                    Expanded(
                      flex: counts.watch,
                      child: ColoredBox(color: KColors.stateWatch),
                    ),
                  if (counts.healthy > 0)
                    Expanded(
                      flex: counts.healthy,
                      child: ColoredBox(color: KColors.stateHealthy),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: KSpace.s3),
          Wrap(
            spacing: KSpace.s4,
            runSpacing: KSpace.s1,
            children: [
              _Legend(color: KColors.stateAlarm, n: counts.alarm, label: 'Alarm'),
              _Legend(color: KColors.stateWatch, n: counts.watch, label: 'Watch'),
              _Legend(color: KColors.stateHealthy, n: counts.healthy, label: 'Healthy'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.n, required this.label});

  final Color color;
  final int n;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text('$n ', style: KText.ui(KSize.sm, weight: FontWeight.w700)),
      Text(label, style: KText.ui(KSize.sm, color: KColors.textSecondary)),
    ],
  );
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.counts, required this.plants});

  final FleetCounts counts;
  final int plants;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      (LucideIcons.factory, '$plants', 'Plants online', KColors.accentX500),
      (LucideIcons.flaskConical, '${counts.total}', 'Reactors', KColors.stateInfo),
      (
        LucideIcons.bellRing,
        '${counts.openAlarms}',
        'Open alarms',
        counts.openAlarms > 0 ? KColors.stateAlarm : KColors.stateHealthy,
      ),
      (LucideIcons.zap, fmt(counts.powerKw / 1000, decimals: 2), 'MW live power', KColors.stateWatch),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      mainAxisSpacing: KSpace.s3,
      crossAxisSpacing: KSpace.s3,
      childAspectRatio: 1.9,
      children: [
        for (final (icon, value, label, color) in tiles)
          KCard(
            radius: KR.tile,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(value, style: KText.display(24, weight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KText.ui(KSize.xs, weight: FontWeight.w500, color: KColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AttentionCard extends ConsumerWidget {
  const _AttentionCard({required this.r});

  final ReactorView r;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plant = ref.watch(plantOfReactorProvider(r.id));
    final c = stateColor(r.state);
    final left = r.ponrRemainingH;
    return SizedBox(
      width: 268,
      child: KCard(
        borderColor: c.withValues(alpha: 0.6),
        onTap: () => context.push('/reactor/${r.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HealthRing(score: r.tick?.health?.score, state: r.state, size: 40, label: null),
                const SizedBox(width: KSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.id, style: KText.display(KSize.lg)),
                      Text(
                        plant?.city ?? '',
                        style: KText.ui(KSize.xs, color: KColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Tag(stateLabel(r.state), color: c),
              ],
            ),
            const Spacer(),
            Text(
              statusSentence(r),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: KText.ui(KSize.md, weight: FontWeight.w600, color: c),
            ),
            const SizedBox(height: KSpace.s2),
            Row(
              children: [
                if (left != null)
                  Tag(
                    left > 0 ? '${fmtHours(left)} to act' : 'PONR passed',
                    color: c,
                    icon: LucideIcons.timer,
                  )
                else if (r.acknowledged)
                  Tag('Acknowledged', color: KColors.textMuted, icon: LucideIcons.check),
                const Spacer(),
                Icon(LucideIcons.chevronRight, size: 18, color: KColors.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AllClearCard extends StatelessWidget {
  // Deliberately not const: rebuilt with the active palette after a theme switch.
  // ignore: prefer_const_constructors_in_immutables
  _AllClearCard();

  @override
  Widget build(BuildContext context) => KCard(
    child: Row(
      children: [
        Icon(LucideIcons.checkCircle2, color: KColors.stateHealthy),
        const SizedBox(width: KSpace.s3),
        Expanded(
          child: Text(
            'Every reactor matches healthy batches.',
            style: KText.ui(KSize.md, color: KColors.textSecondary),
          ),
        ),
      ],
    ),
  );
}

class _PlantTile extends ConsumerWidget {
  const _PlantTile({required this.plant, required this.reactors});

  final PlantSummary plant;
  final List<ReactorView> reactors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worst = reactors.isEmpty ? plant.state : worstState(reactors);
    final alarms = reactors.where((r) => r.state == HealthState.alarm).length;
    return SizedBox(
      width: 168,
      child: KCard(
        radius: KR.tile,
        padding: const EdgeInsets.all(14),
        onTap: () {
          ref.read(reactorFilterProvider.notifier)
            ..reset()
            ..setPlant(plant.id);
          unawaited(Future.microtask(() => context.mounted ? context.go('/reactors') : null));
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StateDot(worst),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    plant.city.isEmpty ? plant.name : plant.city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KText.display(KSize.lg),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              plant.processName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KText.ui(KSize.xs, color: KColors.textSecondary),
            ),
            const Spacer(),
            Row(
              children: [
                Icon(LucideIcons.flaskConical, size: 13, color: KColors.textMuted),
                const SizedBox(width: 4),
                Text('${reactors.length}', style: KText.ui(KSize.sm, weight: FontWeight.w600)),
                const Spacer(),
                if (alarms > 0) Tag('$alarms alarm', color: KColors.stateAlarm),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
