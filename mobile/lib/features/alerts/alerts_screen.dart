import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kairos_pager/core/fleet_providers.dart';
import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/models/plant.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';
import 'package:kairos_pager/widgets/format.dart';
import 'package:kairos_pager/widgets/status_copy.dart';
import 'package:kairos_pager/widgets/ui.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Alarm inbox: open, acknowledged or all; filter by severity and plant.
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(alertFilterProvider);
    final n = ref.read(alertFilterProvider.notifier);
    final items = ref.watch(filteredAlertsProvider);
    final open = ref.watch(openAlertCountProvider);
    final plants = ref.watch(plantsProvider).value ?? const <PlantSummary>[];
    final byPlant = {for (final p in plants) p.id: p};

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PageTitle(
                'Alerts',
                subtitle: open == 0 ? 'Nothing waiting for you' : '$open waiting for you',
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(KSpace.s4, 0, KSpace.s4, KSpace.s3),
                child: SegmentedButton<AlertView>(
                  showSelectedIcon: false,
                  segments: [
                    for (final v in AlertView.values) ButtonSegment(value: v, label: Text(v.label)),
                  ],
                  selected: {f.view},
                  onSelectionChanged: (s) => n.setView(s.first),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: FilterChipsRow<String?>(
                options: [
                  null,
                  'sev:alarm',
                  'sev:watch',
                  ...plants.map((p) => 'plant:${p.id}'),
                ],
                selected: f.plantId != null
                    ? 'plant:${f.plantId}'
                    : f.severity != null
                    ? 'sev:${f.severity!.name}'
                    : null,
                onSelected: (o) {
                  if (o == null) {
                    n
                      ..setSeverity(null)
                      ..setPlant(null);
                  } else if (o.startsWith('sev:')) {
                    n
                      ..setPlant(null)
                      ..setSeverity(o == 'sev:alarm' ? HealthState.alarm : HealthState.watch);
                  } else {
                    n
                      ..setSeverity(null)
                      ..setPlant(o.substring(6));
                  }
                },
                label: (o) => switch (o) {
                  null => 'Everything',
                  'sev:alarm' => 'Alarms',
                  'sev:watch' => 'Watch',
                  _ => byPlant[o.substring(6)]?.city ?? o.substring(6),
                },
                leading: (o) => o == null
                    ? null
                    : o.startsWith('sev:')
                    ? StateDot(o == 'sev:alarm' ? HealthState.alarm : HealthState.watch)
                    : Icon(LucideIcons.mapPin, size: 14, color: KColors.textMuted),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: KSpace.s3)),
            if (items.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(KSpace.s4, KSpace.s8, KSpace.s4, 0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(color: KColors.accentGlow, shape: BoxShape.circle),
                        child: Icon(LucideIcons.bellOff, size: 28, color: KColors.accentX500),
                      ),
                      const SizedBox(height: KSpace.s4),
                      Text(
                        f.view == AlertView.open ? 'You are all caught up' : 'No alerts here yet',
                        style: KText.display(KSize.xl),
                      ),
                      const SizedBox(height: KSpace.s1),
                      Text(
                        'New alarms appear here and on your lock screen.',
                        style: KText.ui(KSize.sm, color: KColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList.builder(
                itemCount: items.length,
                itemBuilder: (_, i) => _AlertTile(item: items[i], plant: null),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: kNavClearance)),
          ],
        ),
      ),
    );
  }
}

class _AlertTile extends ConsumerWidget {
  const _AlertTile({required this.item, required this.plant});

  final AlertItem item;
  final PlantSummary? plant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(reactorProvider(item.reactorId));
    final p = plant ?? ref.watch(plantOfReactorProvider(item.reactorId));
    final c = stateColor(item.state);
    final title = item.state == HealthState.alarm
        ? (r?.insight?.card.title ?? 'Alarm')
        : (r == null ? 'Drifting from normal' : statusSentence(r));
    final left = !item.resolved && r != null ? r.ponrRemainingH : null;
    final ago = DateTime.now().difference(item.at);
    final when = ago.inMinutes < 1
        ? 'just now'
        : ago.inMinutes < 60
        ? '${ago.inMinutes} min ago'
        : '${ago.inHours} h ago';

    final tile = Padding(
      padding: const EdgeInsets.fromLTRB(KSpace.s4, 0, KSpace.s4, KSpace.s3),
      child: KCard(
        radius: KR.tile,
        padding: const EdgeInsets.all(14),
        borderColor: item.open ? c.withValues(alpha: 0.55) : null,
        onTap: () => context.push('/reactor/${item.reactorId}'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: c.withValues(alpha: item.open ? 0.14 : 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                item.state == HealthState.alarm ? LucideIcons.siren : LucideIcons.activity,
                size: 20,
                color: item.open ? c : KColors.textMuted,
              ),
            ),
            const SizedBox(width: KSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(item.reactorId, style: KText.display(KSize.md + 1)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          p?.city ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KText.ui(KSize.xs, color: KColors.textMuted),
                        ),
                      ),
                      Text(when, style: KText.ui(KSize.xs, color: KColors.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: KText.ui(
                      KSize.md,
                      weight: FontWeight.w600,
                      color: item.open ? KColors.textPrimary : KColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: KSpace.s2),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Tag(stateLabel(item.state), color: c),
                      if (left != null)
                        Tag(
                          left > 0 ? '${fmtHours(left)} to act' : 'PONR passed',
                          color: c,
                          icon: LucideIcons.timer,
                        ),
                      if (item.acknowledged)
                        Tag('Acknowledged', color: KColors.stateHealthy, icon: LucideIcons.check),
                      if (item.resolved && !item.acknowledged)
                        Tag('Resolved', color: KColors.textMuted, icon: LucideIcons.checkCircle2),
                    ],
                  ),
                  if (item.open && item.state == HealthState.alarm) ...[
                    const SizedBox(height: KSpace.s3),
                    SizedBox(
                      height: 36,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          textStyle: KText.ui(KSize.sm, weight: FontWeight.w600),
                        ),
                        onPressed: () =>
                            fireAndForget(ref.read(alertsProvider.notifier).acknowledge(item.reactorId)),
                        icon: const Icon(LucideIcons.check, size: 16),
                        label: const Text('Acknowledge'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (!item.open || item.state != HealthState.alarm) return tile;
    return Dismissible(
      key: ValueKey('${item.reactorId}-${item.at.millisecondsSinceEpoch}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        fireAndForget(ref.read(alertsProvider.notifier).acknowledge(item.reactorId));
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: KSpace.s8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.check, color: KColors.stateHealthy),
            const SizedBox(width: 6),
            Text(
              'Acknowledge',
              style: KText.ui(KSize.sm, weight: FontWeight.w600, color: KColors.stateHealthy),
            ),
          ],
        ),
      ),
      child: tile,
    );
  }
}
