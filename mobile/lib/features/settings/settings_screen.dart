import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kairos_pager/core/notifications/alarm_alerts.dart';
import 'package:kairos_pager/core/process_providers.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/theme_pref.dart';
import 'package:kairos_pager/core/theme/tokens.dart';
import 'package:kairos_pager/core/ws/event_source.dart';
import 'package:kairos_pager/features/process/process_picker.dart';

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
          Text('ACCOUNT', style: KText.overline()),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: KColors.accentGlow,
              foregroundColor: KColors.accentX500,
              child: Text(
                (pairing?.firstName.isNotEmpty ?? false) ? pairing!.firstName[0] : '?',
                style: KText.display(KSize.lg, color: KColors.accentX500),
              ),
            ),
            title: Text(
              (pairing?.userName.isNotEmpty ?? false) ? pairing!.userName : 'Not signed in',
              style: KText.ui(KSize.md, weight: FontWeight.w500),
            ),
            subtitle: Text(
              [
                if (pairing?.userRole.isNotEmpty ?? false) pairing!.userRole,
                if (pairing?.tenantName.isNotEmpty ?? false) pairing!.tenantName,
              ].join(' · '),
              style: KText.ui(KSize.sm, color: KColors.textSecondary),
            ),
          ),
          const SizedBox(height: KSpace.s4),
          Text('SERVER', style: KText.overline()),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(pairing?.label ?? 'Not connected', style: KText.mono(KSize.md)),
            subtitle: Text(
              switch (status) {
                ConnectionStatus.live => 'Live',
                ConnectionStatus.connecting => 'Connecting',
                ConnectionStatus.offline => 'Offline, retrying',
              },
              style: KText.ui(KSize.sm, color: KColors.textSecondary),
            ),
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
            child: const Text('Sign out'),
          ),
          const SizedBox(height: KSpace.s8),
          Text('PROCESS', style: KText.overline()),
          Builder(
            builder: (context) {
              final p = ref.watch(selectedProcessProvider);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  p?.name ?? 'No process library',
                  style: KText.ui(KSize.md, weight: FontWeight.w500),
                ),
                subtitle: Text(
                  p == null ? 'Connect to a Kairos server to load it' : p.family.label,
                  style: KText.ui(KSize.sm, color: KColors.textSecondary),
                ),
                trailing: p == null
                    ? null
                    : TextButton(onPressed: () => context.push('/process'), child: const Text('View')),
                onTap: p == null ? null : () => showProcessPicker(context, ref),
              );
            },
          ),
          const SizedBox(height: KSpace.s8),
          Text('THEME', style: KText.overline()),
          const SizedBox(height: KSpace.s2),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
            ],
            selected: {ref.watch(themeModeProvider)},
            onSelectionChanged: (s) => fireAndForget(ref.read(themeModeProvider.notifier).set(s.first)),
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
