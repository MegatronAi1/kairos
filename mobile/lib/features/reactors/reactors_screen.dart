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
import 'package:kairos_pager/widgets/health_ring.dart';
import 'package:kairos_pager/widgets/metric_readout.dart';
import 'package:kairos_pager/widgets/states.dart';
import 'package:kairos_pager/widgets/status_copy.dart';
import 'package:kairos_pager/widgets/ui.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Every reactor, searchable and filterable by state and plant, sortable.
class ReactorsScreen extends ConsumerStatefulWidget {
  const ReactorsScreen({super.key});

  @override
  ConsumerState<ReactorsScreen> createState() => _ReactorsScreenState();
}

class _ReactorsScreenState extends ConsumerState<ReactorsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(reactorFilterProvider);
    final counts = ref.watch(fleetCountsProvider);
    final list = ref.watch(filteredReactorsProvider);
    final plants = ref.watch(plantsProvider).value ?? const <PlantSummary>[];
    final byPlant = {for (final p in plants) p.id: p};
    final n = ref.read(reactorFilterProvider.notifier);
    final all = ref.watch(reactorsProvider);

    final states = <HealthState?>[null, HealthState.alarm, HealthState.watch, HealthState.normal];
    String stateText(HealthState? s) => switch (s) {
      null => 'All ${counts.total}',
      HealthState.alarm => 'Alarm ${counts.alarm}',
      HealthState.watch => 'Watch ${counts.watch}',
      HealthState.normal => 'Healthy ${counts.healthy}',
    };

    final rows = <Widget>[];
    if (f.groupByPlant) {
      final groups = <String, List<ReactorView>>{};
      for (final r in list) {
        groups.putIfAbsent(r.plantId, () => []).add(r);
      }
      for (final e in groups.entries) {
        final p = byPlant[e.key];
        rows
          ..add(
            Padding(
              padding: const EdgeInsets.fromLTRB(KSpace.s4, KSpace.s4, KSpace.s4, KSpace.s2),
              child: Row(
                children: [
                  StateDot(worstState(e.value)),
                  const SizedBox(width: KSpace.s2),
                  Expanded(child: Text(p?.name ?? e.key, style: KText.display(KSize.md + 1))),
                  Text(p?.processName ?? '', style: KText.ui(KSize.xs, color: KColors.textMuted)),
                ],
              ),
            ),
          )
          ..addAll([for (final r in e.value) _ReactorRow(r: r, plant: p)]);
      }
    } else {
      rows.addAll([for (final r in list) _ReactorRow(r: r, plant: byPlant[r.plantId])]);
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PageTitle(
                'Reactors',
                subtitle: '${list.length} of ${counts.total} shown',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: f.groupByPlant ? 'Show as one list' : 'Group by plant',
                      onPressed: n.toggleGroup,
                      icon: Icon(
                        f.groupByPlant ? LucideIcons.list : LucideIcons.layoutGrid,
                        color: f.groupByPlant ? KColors.accentX500 : KColors.textSecondary,
                      ),
                    ),
                    PopupMenuButton<ReactorSort>(
                      tooltip: 'Sort',
                      icon: Icon(LucideIcons.arrowUpDown, color: KColors.textSecondary),
                      initialValue: f.sort,
                      onSelected: n.setSort,
                      itemBuilder: (_) => [
                        for (final s in ReactorSort.values)
                          PopupMenuItem(
                            value: s,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  child: s == f.sort
                                      ? Icon(LucideIcons.check, size: 16, color: KColors.accentX500)
                                      : null,
                                ),
                                Text(s.label),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(KSpace.s4, 0, KSpace.s4, KSpace.s3),
                child: TextField(
                  controller: _search,
                  onChanged: n.setQuery,
                  textInputAction: TextInputAction.search,
                  style: KText.ui(KSize.md),
                  decoration: InputDecoration(
                    hintText: 'Search reactor, plant or process',
                    prefixIcon: Icon(LucideIcons.search, size: 18, color: KColors.textMuted),
                    suffixIcon: f.query.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(LucideIcons.x, size: 16, color: KColors.textMuted),
                            onPressed: () {
                              _search.clear();
                              n.setQuery('');
                            },
                          ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: FilterChipsRow<HealthState?>(
                options: states,
                selected: f.state,
                onSelected: n.setState,
                label: stateText,
                leading: (s) => s == null ? null : StateDot(s),
              ),
            ),
            if (plants.length > 1) ...[
              const SliverToBoxAdapter(child: SizedBox(height: KSpace.s2)),
              SliverToBoxAdapter(
                child: FilterChipsRow<String?>(
                  options: [null, ...plants.map((p) => p.id)],
                  selected: f.plantId,
                  onSelected: n.setPlant,
                  label: (id) => id == null ? 'All plants' : (byPlant[id]?.city ?? id),
                  leading: (id) => Icon(
                    id == null ? LucideIcons.globe : LucideIcons.mapPin,
                    size: 14,
                    color: KColors.textMuted,
                  ),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: KSpace.s2)),
            if (all.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(KSpace.s4),
                  child: Skeleton(height: 300, radius: KR.card),
                ),
              )
            else if (list.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: KSpace.s8),
                  child: Column(
                    children: [
                      Icon(LucideIcons.searchX, size: 32, color: KColors.textMuted),
                      const SizedBox(height: KSpace.s2),
                      Text('No reactors match', style: KText.display(KSize.lg)),
                      TextButton(
                        onPressed: () {
                          _search.clear();
                          n.reset();
                        },
                        child: const Text('Clear filters'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList.list(children: rows),
            const SliverToBoxAdapter(child: SizedBox(height: kNavClearance)),
          ],
        ),
      ),
    );
  }
}

/// Compact reactor row: health ring, id and plant, state, yield vs typical, DO and a trend.
class _ReactorRow extends StatelessWidget {
  const _ReactorRow({required this.r, required this.plant});

  final ReactorView r;
  final PlantSummary? plant;

  @override
  Widget build(BuildContext context) {
    final f = r.tick?.forecast;
    final doPct = r.tick?.sensors['do_pct'];
    final c = stateColor(r.state);
    final alerting = r.state != HealthState.normal;
    final yieldColor = f == null
        ? KColors.textMuted
        : f.vsGoldenPct >= 95
        ? KColors.stateHealthy
        : f.vsGoldenPct >= 80
        ? KColors.stateWatch
        : KColors.stateAlarm;
    return Padding(
      padding: const EdgeInsets.fromLTRB(KSpace.s4, 0, KSpace.s4, KSpace.s3),
      child: KCard(
        radius: KR.tile,
        padding: const EdgeInsets.all(14),
        borderColor: alerting ? c.withValues(alpha: 0.55) : null,
        onTap: () => context.push('/reactor/${r.id}'),
        child: Column(
          children: [
            Row(
              children: [
                HealthRing(score: r.tick?.health?.score, state: r.state, size: 46, label: null),
                const SizedBox(width: KSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(r.id, style: KText.display(KSize.lg)),
                          const SizedBox(width: KSpace.s2),
                          Tag(stateLabel(r.state), color: c),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        alerting ? statusSentence(r) : '${plant?.city ?? ''} · ${plant?.processName ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KText.ui(
                          KSize.sm,
                          weight: alerting ? FontWeight.w600 : FontWeight.w400,
                          color: alerting ? c : KColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronRight, size: 18, color: KColors.textMuted),
              ],
            ),
            const SizedBox(height: KSpace.s3),
            Row(
              children: [
                _Stat(
                  label: 'Yield',
                  value: f == null ? '—' : '${f.vsGoldenPct.round()}%',
                  color: yieldColor,
                ),
                _Stat(label: 'DO', value: doPct == null ? '—' : '${fmt(doPct, decimals: 0)}%'),
                _Stat(label: 'Batch', value: '${r.batchId}'),
                const SizedBox(width: KSpace.s2),
                Expanded(
                  child: SizedBox(
                    height: 28,
                    child: CustomPaint(
                      painter: SparklinePainter([
                        for (final t in r.recent) t.value('do_pct') ?? double.nan,
                      ], alerting ? c : KColors.accentX500),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 62,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: KText.ui(KSize.xs - 1, color: KColors.textMuted)),
        Text(value, style: KText.display(KSize.md + 1, color: color)),
      ],
    ),
  );
}
