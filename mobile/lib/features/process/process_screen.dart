import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kairos_pager/core/models/process.dart';
import 'package:kairos_pager/core/process_providers.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';
import 'package:kairos_pager/features/process/fermenter_schematic.dart';
import 'package:kairos_pager/features/process/process_picker.dart';
import 'package:kairos_pager/widgets/chips.dart';
import 'package:kairos_pager/widgets/section.dart';
import 'package:kairos_pager/widgets/states.dart';
import 'package:lucide_icons/lucide_icons.dart';

const _setpointLabel = <String, String>{
  'temp_c': 'Temperature',
  'ph': 'pH',
  'do_pct': 'Dissolved oxygen',
  'dilution_rate_per_h': 'Dilution rate',
  'methanol_g_l': 'Methanol',
  'glucose_g_l': 'Glucose',
  'light_umol_m2_s': 'Light',
  'h2_o2_ratio': 'H₂ : O₂ ratio',
  'co2_pct': 'CO₂',
  'pressure_bar': 'Pressure',
};

const _setpointUnit = <String, String>{
  'temp_c': '°C',
  'do_pct': '% sat',
  'dilution_rate_per_h': '1/h',
  'methanol_g_l': 'g/L',
  'glucose_g_l': 'g/L',
  'light_umol_m2_s': 'µmol/m²/s',
  'co2_pct': '%',
  'pressure_bar': 'bar',
};

Color fitColor(BenchmarkFit? f) => switch (f) {
  BenchmarkFit.high => KColors.stateHealthy,
  BenchmarkFit.medium => KColors.stateWatch,
  BenchmarkFit.low => KColors.stateAlarm,
  null => KColors.textMuted,
};

/// How the selected alternative-protein process is run and controlled, and where Kairos helps.
class ProcessScreen extends ConsumerWidget {
  const ProcessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(processesProvider);
    final selected = ref.watch(selectedProcessProvider);
    final demo = ref.watch(pairingProvider)?.demo ?? false;

    Widget body;
    if (list.isLoading) {
      body = ListView(
        padding: const EdgeInsets.all(KSpace.s4),
        children: const [
          Skeleton(height: 120, radius: KRadius.card),
          SizedBox(height: KSpace.s4),
          Skeleton(height: 280, radius: KRadius.card),
        ],
      );
    } else if (list.hasError) {
      body = ErrorState(
        title: "Couldn't load the process library",
        message: 'Check the connection to the Kairos server.',
        onRetry: () => ref.invalidate(processesProvider),
      );
    } else if (selected == null) {
      body = EmptyState(
        icon: LucideIcons.factory,
        title: demo
            ? 'Connect to a Kairos server to load the process library'
            : 'The process library is empty',
        message: demo ? 'Demo mode has no process catalog. Pair with the control room in Settings.' : null,
      );
    } else {
      final detail = ref.watch(processDetailProvider(selected.id));
      body = detail.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(KSpace.s4),
          child: Skeleton(height: 280, radius: KRadius.card),
        ),
        error: (_, _) => ErrorState(
          title: "Couldn't load this process",
          onRetry: () => ref.invalidate(processDetailProvider(selected.id)),
        ),
        data: (p) => _ProcessBody(process: p),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Process'),
        actions: [
          if (selected != null)
            TextButton.icon(
              onPressed: () => showProcessPicker(context, ref),
              icon: const Icon(LucideIcons.repeat, size: 16),
              label: const Text('Change'),
            ),
        ],
      ),
      body: body,
    );
  }
}

class _ProcessBody extends StatelessWidget {
  const _ProcessBody({required this.process});

  final ProcessDetail process;

  @override
  Widget build(BuildContext context) {
    final p = process;
    return ListView(
      padding: const EdgeInsets.fromLTRB(KSpace.s4, KSpace.s2, KSpace.s4, KSpace.s12),
      children: [
        _Hero(p: p),
        const SizedBox(height: KSpace.s6),
        SectionHeader(p.reactor.label, subtitle: p.reactorNote ?? 'How the fermenter is controlled'),
        SurfaceCard(
          padding: const EdgeInsets.all(KSpace.s3),
          child: FermenterSchematic(process: p),
        ),
        const SizedBox(height: KSpace.s6),
        const SectionHeader('From inoculation to harvest'),
        for (var i = 0; i < p.phases.length; i++)
          _PhaseStep(index: i, phase: p.phases[i], last: i == p.phases.length - 1),
        const SizedBox(height: KSpace.s6),
        const SectionHeader('Control loops', subtitle: 'What is measured and what it moves'),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final c in p.controlLoops)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: KSpace.s2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: c.measure),
                            TextSpan(
                              text: '  →  ',
                              style: KText.ui(KSize.md, color: KColors.textMuted),
                            ),
                            TextSpan(text: c.actuator),
                          ],
                        ),
                        style: KText.ui(KSize.md, weight: FontWeight.w500),
                      ),
                      Text(c.purpose, style: KText.ui(KSize.sm, color: KColors.textSecondary)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: KSpace.s6),
        const SectionHeader('Typical setpoints'),
        SurfaceCard(
          child: Column(
            children: [
              for (final e in p.setpoints.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: KSpace.s2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _setpointLabel[e.key] ?? e.key.replaceAll('_', ' '),
                          style: KText.ui(KSize.md, color: KColors.textSecondary),
                        ),
                      ),
                      Text(
                        '${e.value.text ?? '—'} ${e.value.unit ?? _setpointUnit[e.key] ?? ''}',
                        style: KText.mono(KSize.md),
                      ),
                      const SizedBox(width: KSpace.s2),
                      ProvenanceChip(provenance: e.value.provenance, source: e.value.source),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: KSpace.s6),
        const SectionHeader('How Kairos helps', subtitle: 'Mapped to the hackathon KPIs'),
        _HelpCard(
          icon: LucideIcons.trendingUp,
          kpi: 'KPI 1 · EARLY YIELD',
          title: 'Know the outcome early',
          items: [p.yieldSignal],
        ),
        const SizedBox(height: KSpace.s3),
        _HelpCard(
          icon: LucideIcons.shieldAlert,
          kpi: 'KPI 2 + 3 · FAULTS, FEW FALSE ALARMS',
          title: 'Catch drift and contamination',
          items: p.faultSignatures,
        ),
        const SizedBox(height: KSpace.s3),
        _HelpCard(
          icon: LucideIcons.zap,
          kpi: 'KPI 4 · ENERGY VS OXYGEN',
          title: 'Use less energy',
          items: p.energyLevers,
        ),
        if (p.criticalRisks.isNotEmpty || p.energyHotspots.isNotEmpty) ...[
          const SizedBox(height: KSpace.s6),
          if (p.criticalRisks.isNotEmpty) _Bullets(title: 'What can go wrong', items: p.criticalRisks),
          if (p.energyHotspots.isNotEmpty) ...[
            const SizedBox(height: KSpace.s4),
            _Bullets(title: 'Where the energy goes', items: p.energyHotspots),
          ],
        ],
        const SizedBox(height: KSpace.s6),
        Text(
          'Live reactors replay the IndPenSim penicillin benchmark (synthetic). '
          'Setpoints are typical published ranges.',
          style: KText.ui(KSize.sm, color: KColors.textMuted),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.p});

  final ProcessDetail p;

  @override
  Widget build(BuildContext context) {
    final fit = fitColor(p.benchmarkFit);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              p.family == ProcessFamily.biomass ? LucideIcons.sprout : LucideIcons.dna,
              size: 16,
              color: KColors.accentX500,
            ),
            const SizedBox(width: KSpace.s1),
            Text(
              p.family.label,
              style: KText.ui(KSize.sm, weight: FontWeight.w500, color: KColors.accentX500),
            ),
          ],
        ),
        const SizedBox(height: KSpace.s1),
        Text(p.name, style: KText.display(KSize.x3xl)),
        const SizedBox(height: KSpace.s1),
        Text(p.product, style: KText.ui(KSize.lg, color: KColors.textSecondary)),
        const SizedBox(height: KSpace.s3),
        Wrap(
          spacing: KSpace.s2,
          runSpacing: KSpace.s2,
          children: [
            _Chip(p.organism, italic: true),
            _Chip(p.mode.replaceAll('_', '-')),
            if (p.productLocation.isNotEmpty) _Chip('product: ${p.productLocation}'),
            if (p.example.company.isNotEmpty) _Chip('e.g. ${p.example.company}'),
          ],
        ),
        if (p.namingNote != null && p.namingNote!.isNotEmpty) ...[
          const SizedBox(height: KSpace.s2),
          Text(p.namingNote!, style: KText.ui(KSize.xs, color: KColors.textMuted)),
        ],
        const SizedBox(height: KSpace.s4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(KSpace.s3),
          decoration: BoxDecoration(
            color: fit.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(KRadius.card),
            border: Border.all(color: fit.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BENCHMARK FIT', style: KText.overline()),
              const SizedBox(height: 2),
              Text(p.benchmarkFit?.label ?? 'Not rated', style: KText.display(KSize.lg, color: fit)),
              const SizedBox(height: 2),
              Text(p.benchmarkFitWhy, style: KText.ui(KSize.sm, color: KColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {this.italic = false});

  final String text;
  final bool italic;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: KSpace.s3, vertical: KSpace.s1),
    decoration: BoxDecoration(
      color: KColors.bgInset,
      borderRadius: BorderRadius.circular(KRadius.full),
      border: Border.all(color: KColors.borderSubtle),
    ),
    child: Text(
      text,
      style: KText.ui(
        KSize.xs,
        color: KColors.textSecondary,
      ).copyWith(fontStyle: italic ? FontStyle.italic : null),
    ),
  );
}

class _PhaseStep extends StatelessWidget {
  const _PhaseStep({required this.index, required this.phase, required this.last});

  final int index;
  final ProcessPhase phase;
  final bool last;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: KColors.accentGlow, shape: BoxShape.circle),
              child: Text('${index + 1}', style: KText.display(KSize.md, color: KColors.accentX500)),
            ),
            if (!last) Expanded(child: Container(width: 2, color: KColors.borderSubtle)),
          ],
        ),
        const SizedBox(width: KSpace.s3),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : KSpace.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(phase.name, style: KText.display(KSize.lg))),
                    if (phase.duration.isNotEmpty)
                      Text(phase.duration, style: KText.ui(KSize.xs, color: KColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(phase.goal, style: KText.ui(KSize.md, color: KColors.textSecondary)),
                const SizedBox(height: KSpace.s2),
                for (final c in phase.controls)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: c.param,
                            style: KText.ui(KSize.sm, weight: FontWeight.w600),
                          ),
                          TextSpan(text: ' · ${c.action}'),
                        ],
                      ),
                      style: KText.ui(KSize.sm, color: KColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({required this.icon, required this.kpi, required this.title, required this.items});

  final IconData icon;
  final String kpi;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: KColors.accentGlow,
                borderRadius: BorderRadius.circular(KRadius.control),
              ),
              child: Icon(icon, size: 16, color: KColors.accentX500),
            ),
            const SizedBox(width: KSpace.s2),
            Expanded(child: Text(kpi, style: KText.overline())),
          ],
        ),
        const SizedBox(height: KSpace.s2),
        Text(title, style: KText.display(KSize.lg)),
        const SizedBox(height: KSpace.s1),
        for (final i in items.where((s) => s.isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text('•  $i', style: KText.ui(KSize.md, color: KColors.textSecondary)),
          ),
      ],
    ),
  );
}

class _Bullets extends StatelessWidget {
  const _Bullets({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: KText.display(KSize.lg)),
        const SizedBox(height: KSpace.s1),
        for (final i in items)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text('•  $i', style: KText.ui(KSize.md, color: KColors.textSecondary)),
          ),
      ],
    ),
  );
}
