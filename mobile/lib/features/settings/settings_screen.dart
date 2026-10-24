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
import 'package:kairos_pager/features/alerts/simulate_sheet.dart';
import 'package:kairos_pager/features/feedback/feedback_sheet.dart';
import 'package:kairos_pager/features/process/process_picker.dart';
import 'package:kairos_pager/widgets/ui.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Profile tab: account, connection, appearance, process, help.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairing = ref.watch(pairingProvider);
    final status = ref.watch(connectionStatusProvider).value ?? ConnectionStatus.connecting;
    final process = ref.watch(selectedProcessProvider);
    final name = (pairing?.userName.isNotEmpty ?? false) ? pairing!.userName : 'Not signed in';
    final initials = name.split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
    final (statusColor, statusText) = switch (status) {
      ConnectionStatus.live => (KColors.stateHealthy, 'Live'),
      ConnectionStatus.connecting => (KColors.stateWatch, 'Connecting'),
      ConnectionStatus.offline => (KColors.stateAlarm, 'Offline, retrying'),
    };

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: kNavClearance),
          children: [
            const PageTitle('Profile'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpace.s4),
              child: KCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AskKairosButton.background(context),
                      child: Text(
                        initials.isEmpty ? '?' : initials,
                        style: KText.display(KSize.xl, color: AskKairosButton.foreground(context)),
                      ),
                    ),
                    const SizedBox(width: KSpace.s4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: KText.display(KSize.xl)),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (pairing?.userRole.isNotEmpty ?? false) pairing!.userRole,
                              if (pairing?.tenantName.isNotEmpty ?? false) pairing!.tenantName,
                            ].join(' · '),
                            style: KText.ui(KSize.sm, color: KColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SectionLabel('Connection'),
            _Group(
              children: [
                _Tile(
                  icon: LucideIcons.server,
                  title: pairing?.label ?? 'Not connected',
                  trailing: Tag(statusText, color: statusColor),
                ),
              ],
            ),
            const SectionLabel('Appearance'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpace.s4),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(LucideIcons.sun, size: 16),
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(LucideIcons.moon, size: 16),
                      label: Text('Dark'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(LucideIcons.smartphone, size: 16),
                      label: Text('System'),
                    ),
                  ],
                  selected: {ref.watch(themeModeProvider)},
                  onSelectionChanged: (s) => fireAndForget(ref.read(themeModeProvider.notifier).set(s.first)),
                ),
              ),
            ),
            const SectionLabel('Process'),
            _Group(
              children: [
                _Tile(
                  icon: process?.family.name == 'precision' ? LucideIcons.dna : LucideIcons.sprout,
                  title: process?.name ?? 'No process library',
                  subtitle: process == null ? 'Available when connected to a server' : process.family.label,
                  onTap: process == null ? null : () => showProcessPicker(context, ref),
                  trailing: process == null ? null : Text('Change', style: _link()),
                ),
                if (process != null)
                  _Tile(
                    icon: LucideIcons.bookOpen,
                    title: 'Process library',
                    subtitle: 'Fermenter, control loops, setpoints',
                    onTap: () => context.push('/process'),
                  ),
              ],
            ),
            const SectionLabel('Help'),
            _Group(
              children: [
                _Tile(
                  icon: LucideIcons.zap,
                  title: 'Trigger a live alarm',
                  subtitle: 'Replay a real fault on any reactor',
                  onTap: () => showSimulateSheet(context),
                ),
                _Tile(
                  icon: LucideIcons.bellRing,
                  title: 'Send test alarm',
                  subtitle: 'Check sound and notifications',
                  onTap: () async {
                    final alerts = AlarmAlerts.instance;
                    await alerts.buzz();
                    await alerts.notify(
                      reactorId: 'TEST',
                      title: 'Test alarm',
                      body: 'Kairos notifications are working on this phone.',
                    );
                  },
                ),
                _Tile(
                  icon: LucideIcons.messageSquare,
                  title: 'Send feedback',
                  subtitle: 'Tell the Kairos team',
                  onTap: () => showFeedbackSheet(context, page: 'profile'),
                ),
                _Tile(
                  icon: LucideIcons.info,
                  title: 'About Kairos',
                  subtitle: 'Model estimates on IndPenSim data',
                  onTap: () => showAboutSheet(context),
                ),
              ],
            ),
            const SizedBox(height: KSpace.s6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpace.s4),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: KColors.stateAlarm,
                  side: BorderSide(color: KColors.stateAlarm.withValues(alpha: 0.4)),
                ),
                onPressed: () => ref.read(pairingProvider.notifier).unpair(),
                icon: const Icon(LucideIcons.logOut, size: 18),
                label: const Text('Sign out'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _link() => KText.ui(KSize.sm, weight: FontWeight.w600, color: KColors.accentX500);
}

Future<void> showAboutSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  showDragHandle: true,
  backgroundColor: KColors.bgSurface,
  builder: (context) => Padding(
    padding: const EdgeInsets.fromLTRB(KSpace.s6, 0, KSpace.s6, KSpace.s8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About Kairos', style: KText.display(KSize.xl)),
        const SizedBox(height: KSpace.s3),
        Text(
          'An AI co-pilot for fermentation bioreactors. Predictions are model estimates trained on '
          'the IndPenSim industrial penicillin simulator (synthetic data). Energy figures use published '
          'correlations with stated assumptions. Always verify a setpoint change before applying it.',
          style: KText.ui(KSize.md, color: KColors.textSecondary),
        ),
        const SizedBox(height: KSpace.s3),
        Text(
          'Data labels: M measured · P published · A assumed · S synthetic',
          style: KText.ui(KSize.sm, color: KColors.textMuted),
        ),
      ],
    ),
  ),
);

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: KSpace.s4),
    child: KCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, c) in children.indexed) ...[
            if (i > 0) Divider(indent: 60, color: KColors.borderSubtle),
            c,
          ],
        ],
      ),
    ),
  );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, this.subtitle, this.trailing, this.onTap});

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: KSpace.s4, vertical: 2),
    leading: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: KColors.accentGlow, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 18, color: KColors.accentX500),
    ),
    title: Text(title, style: KText.ui(KSize.md, weight: FontWeight.w600)),
    subtitle: subtitle == null ? null : Text(subtitle!, style: KText.ui(KSize.xs, color: KColors.textMuted)),
    trailing:
        trailing ??
        (onTap == null ? null : Icon(LucideIcons.chevronRight, size: 18, color: KColors.textMuted)),
  );
}
