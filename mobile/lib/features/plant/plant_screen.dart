import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/models/plant.dart';
import 'package:kairos_pager/core/process_providers.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';
import 'package:kairos_pager/core/ws/event_source.dart';
import 'package:kairos_pager/features/plant/reactor_card.dart';
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
      final plants = ref.watch(plantsProvider).value ?? const <PlantSummary>[];
      final groups = _groupByPlant(reactors, plants);
      body = RefreshIndicator(
        color: KColors.accentX500,
        onRefresh: () async {
          ref
            ..invalidate(eventSourceProvider)
            ..invalidate(plantsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(KSpace.s4, KSpace.s2, KSpace.s4, 96),
          children: [
            if (pairing != null && pairing.firstName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: KSpace.s1),
                child: Text(
                  'Hi ${pairing.firstName}',
                  style: KText.ui(KSize.lg, color: KColors.textSecondary),
                ),
              ),
            _PlantSummary(reactors: reactors, plantCount: groups.length),
            for (final g in groups) ...[
              const SizedBox(height: KSpace.s8),
              _PlantHeader(plant: g.plant, fallbackId: g.plantId, reactors: g.reactors),
              const SizedBox(height: KSpace.s3),
              for (final r in g.reactors) ...[
                ReactorCard(reactor: r, onTap: () => context.push('/reactor/${r.id}')),
                const SizedBox(height: KSpace.s4),
              ],
            ],
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          pairing == null || pairing.tenantName.isEmpty ? 'Plants' : pairing.tenantName,
          style: KText.display(KSize.xl),
          overflow: TextOverflow.ellipsis,
        ),
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
  const _PlantSummary({required this.reactors, required this.plantCount});

  final List<ReactorView> reactors;
  final int plantCount;

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
    final where = plantCount > 1 ? ' across $plantCount plants' : '';
    final power = reactors.fold<double>(0, (a, r) => a + (r.tick?.derived['power_kw'] ?? 0));
    final color = alarms > 0
        ? KColors.stateAlarm
        : watching > 0
        ? KColors.stateWatch
        : KColors.stateHealthy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$headline$where', style: KText.display(KSize.x3xl - 4, color: color)),
        const SizedBox(height: KSpace.s3),
        Row(
          children: [
            _Dot(
              color: KColors.stateAlarm,
              label: '${reactors.where((r) => r.state == HealthState.alarm).length} alarm',
            ),
            const SizedBox(width: KSpace.s3),
            _Dot(color: KColors.stateWatch, label: '$watching watch'),
            const SizedBox(width: KSpace.s3),
            _Dot(
              color: KColors.stateHealthy,
              label: '${reactors.where((r) => r.state == HealthState.normal).length} healthy',
            ),
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

class _PlantGroup {
  _PlantGroup(this.plantId, this.plant, this.reactors);

  final String plantId;
  final PlantSummary? plant;
  final List<ReactorView> reactors;
}

/// Reactors grouped by plant: the demo plant (Pune) first, then plants with alarms, then by name.
List<_PlantGroup> _groupByPlant(List<ReactorView> reactors, List<PlantSummary> plants) {
  final byId = <String, List<ReactorView>>{};
  for (final r in reactors) {
    byId.putIfAbsent(r.plantId, () => []).add(r);
  }
  final groups = [
    for (final e in byId.entries)
      _PlantGroup(
        e.key,
        plants.where((p) => p.id == e.key).firstOrNull,
        e.value..sort((a, b) => a.id.compareTo(b.id)),
      ),
  ];
  int rank(_PlantGroup g) {
    if (g.plantId == 'pune') return 0;
    if (g.reactors.any((r) => r.state == HealthState.alarm)) return 1;
    return 2;
  }

  groups.sort((a, b) {
    final c = rank(a).compareTo(rank(b));
    return c != 0 ? c : (a.plant?.name ?? a.plantId).compareTo(b.plant?.name ?? b.plantId);
  });
  return groups;
}

/// Section header for one plant: name, city, process, worst state. Tap for the process.
class _PlantHeader extends ConsumerWidget {
  const _PlantHeader({required this.plant, required this.fallbackId, required this.reactors});

  final PlantSummary? plant;
  final String fallbackId;
  final List<ReactorView> reactors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worst = reactors.any((r) => r.state == HealthState.alarm)
        ? HealthState.alarm
        : reactors.any((r) => r.state == HealthState.watch)
        ? HealthState.watch
        : HealthState.normal;
    final p = plant;
    final name = p?.name ?? (fallbackId.isEmpty ? 'Reactors' : fallbackId);
    final sub = [
      if (p != null && p.city.isNotEmpty) p.city,
      if (p != null && p.processName.isNotEmpty) p.processName,
    ].join(' · ');
    return InkWell(
      borderRadius: BorderRadius.circular(KRadius.control),
      onTap: p == null || p.processId.isEmpty
          ? null
          : () {
              fireAndForget(ref.read(selectedProcessIdProvider.notifier).select(p.processId));
              unawaited(context.push('/process'));
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpace.s1),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: stateColor(worst), shape: BoxShape.circle),
            ),
            const SizedBox(width: KSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: KText.display(KSize.xl), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (sub.isNotEmpty)
                    Text(
                      sub,
                      style: KText.ui(KSize.sm, color: KColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (p != null && p.processId.isNotEmpty)
              Icon(
                p.processFamily == 'precision' ? LucideIcons.dna : LucideIcons.sprout,
                size: 18,
                color: KColors.accentX500,
              ),
          ],
        ),
      ),
    );
  }
}
