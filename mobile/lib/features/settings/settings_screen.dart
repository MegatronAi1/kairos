import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kairos_pager/core/notifications/alarm_alerts.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';
import 'package:kairos_pager/core/ws/event_source.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairing = ref.watch(pairingProvider);
    final status = ref.watch(connectionStatusProvider).value ?? ConnectionStatus.connecting;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(KSpace.s4),
        children: [
          Text('SERVER', style: KText.overline()),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(pairing?.label ?? 'Not paired', style: KText.mono(KSize.md)),
            subtitle: Text(status.name, style: KText.ui(KSize.sm, color: KColors.textSecondary)),
          ),
          const SizedBox(height: KSpace.s2),
          OutlinedButton(
            onPressed: () async {
              final alerts = AlarmAlerts.instance;
              await alerts.buzz();
              await alerts.notify(
                reactorId: 'TEST',
                title: 'Test alarm',
                body: 'Kairos notifications are working on this phone.',
              );
            },
            child: const Text('Send test alarm'),
          ),
          const SizedBox(height: KSpace.s3),
          OutlinedButton(
            onPressed: () => ref.read(pairingProvider.notifier).unpair(),
            child: const Text('Disconnect and pair again'),
          ),
          const SizedBox(height: KSpace.s8),
          Text('ABOUT', style: KText.overline()),
          const SizedBox(height: KSpace.s2),
          Text(
            'Kairos is an AI co-pilot for fermentation bioreactors. Predictions are model estimates '
            'trained on the IndPenSim industrial-scale penicillin simulator (synthetic data). '
            'Energy figures use published correlations with stated assumptions. '
            'Always verify a setpoint change before applying it.',
            style: KText.ui(KSize.md, color: KColors.textSecondary),
          ),
          const SizedBox(height: KSpace.s4),
          Text(
            'Data labels: M measured · P published · A assumed · S synthetic',
            style: KText.ui(KSize.sm, color: KColors.textMuted),
          ),
        ],
      ),
    );
  }
}
