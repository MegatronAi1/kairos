import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kairos_pager/core/models/process.dart';
import 'package:kairos_pager/core/process_providers.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Bottom sheet listing processes grouped by family.
Future<void> showProcessPicker(BuildContext context, WidgetRef ref) {
  final list = ref.read(processesProvider).value ?? const <ProcessSummary>[];
  final current = ref.read(selectedProcessProvider)?.id;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: KColors.bgElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(KRadius.sheet)),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(KSpace.s4, KSpace.s4, KSpace.s4, KSpace.s8),
        children: [
          Text('Choose a process', style: KText.display(KSize.x2xl)),
          const SizedBox(height: KSpace.s1),
          Text(
            'Kairos configures its view of the fermenter for this alternative-protein process.',
            style: KText.ui(KSize.sm, color: KColors.textSecondary),
          ),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: KSpace.s6),
              child: Text(
                'Connect to a Kairos server to load the process library.',
                style: KText.ui(KSize.md, color: KColors.textMuted),
              ),
            ),
          for (final fam in ProcessFamily.values) ...[
            const SizedBox(height: KSpace.s6),
            Row(
              children: [
                Icon(
                  fam == ProcessFamily.biomass ? LucideIcons.sprout : LucideIcons.dna,
                  size: 14,
                  color: KColors.textMuted,
                ),
                const SizedBox(width: KSpace.s1),
                Text(fam.label.toUpperCase(), style: KText.overline()),
              ],
            ),
            const SizedBox(height: KSpace.s2),
            for (final p in list.where((p) => p.family == fam))
              _Option(
                p: p,
                selected: p.id == current,
                onTap: () {
                  fireAndForget(ref.read(selectedProcessIdProvider.notifier).select(p.id));
                  Navigator.of(context).pop();
                },
              ),
          ],
        ],
      ),
    ),
  );
}

class _Option extends StatelessWidget {
  const _Option({required this.p, required this.selected, required this.onTap});

  final ProcessSummary p;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: KSpace.s2),
    child: Material(
      color: selected ? KColors.accentGlow : KColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KRadius.card),
        side: BorderSide(color: selected ? KColors.accentX500 : KColors.borderSubtle),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(KRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(KSpace.s3),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: KText.display(KSize.lg)),
                    const SizedBox(height: 2),
                    Text(
                      [if (p.example.company.isNotEmpty) p.example.company, p.organism].join(' · '),
                      style: KText.ui(KSize.sm, color: KColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (selected) Icon(LucideIcons.check, size: 18, color: KColors.accentX500),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Plant-screen banner: which process Kairos is configured for. Opens the Process screen.
class ProcessBanner extends ConsumerWidget {
  const ProcessBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(selectedProcessProvider);
    if (p == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.s4),
      child: Material(
        color: KColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KRadius.card),
          side: BorderSide(color: KColors.borderSubtle),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(KRadius.card),
          onTap: () => context.push('/process'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpace.s3, vertical: KSpace.s3),
            child: Row(
              children: [
                Icon(
                  p.family == ProcessFamily.biomass ? LucideIcons.sprout : LucideIcons.dna,
                  size: 18,
                  color: KColors.accentX500,
                ),
                const SizedBox(width: KSpace.s2),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${p.family.label} · ',
                          style: KText.ui(KSize.sm, color: KColors.textSecondary),
                        ),
                        TextSpan(
                          text: p.name,
                          style: KText.ui(KSize.sm, weight: FontWeight.w600),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(LucideIcons.chevronRight, size: 16, color: KColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
