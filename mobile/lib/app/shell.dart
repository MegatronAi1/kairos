import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kairos_pager/core/fleet_providers.dart';
import 'package:kairos_pager/widgets/ui.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Tabbed frame: each tab keeps its own navigation stack; the floating bar sits on top.
class AppShell extends ConsumerWidget {
  const AppShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openAlerts = ref.watch(openAlertCountProvider);
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: FloatingNavBar(
        index: shell.currentIndex,
        onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        items: [
          const NavItem(LucideIcons.home, 'Home'),
          const NavItem(LucideIcons.factory, 'Reactors'),
          NavItem(LucideIcons.bell, 'Alerts', badge: openAlerts),
          const NavItem(LucideIcons.sparkles, 'Ask'),
          const NavItem(LucideIcons.user, 'Profile'),
        ],
      ),
    );
  }
}
