import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';
import 'package:kairos_pager/core/ws/event_source.dart';
import 'package:kairos_pager/features/plant/reactor_card.dart';
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
        title: 'Cannot reach Kairos',
        message: 'Retrying automatically. Check the laptop is on the same Wi-Fi.',
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
          padding: const EdgeInsets.all(KSpace.s4),
          itemCount: reactors.length,
          separatorBuilder: (_, _) => const SizedBox(height: KSpace.s3),
          itemBuilder: (context, i) => ReactorCard(
            reactor: reactors[i],
            onTap: () => context.push('/reactor/${reactors[i].id}'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plant'),
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
