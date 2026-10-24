import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';
import 'package:kairos_pager/widgets/ui.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Demo control: replay a real IndPenSim fault batch on a reactor from two hours
/// before the fault starts. The server's detector, copilot and alarms then react
/// exactly as they would live, and the alarm reaches this phone in seconds.
Future<void> showSimulateSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: KColors.bgSurface,
  builder: (_) => const _SimulateSheet(),
);

const _kinds = [
  ('oxygen', 'Oxygen transfer drop', 'Aeration fails', LucideIcons.wind),
  ('feed', 'Feed drop', 'Substrate feed fails', LucideIcons.droplets),
  ('temperature', 'Temperature drift', 'Cooling fails', LucideIcons.thermometer),
];

class _SimulateSheet extends ConsumerStatefulWidget {
  const _SimulateSheet();

  @override
  ConsumerState<_SimulateSheet> createState() => _SimulateSheetState();
}

class _SimulateSheetState extends ConsumerState<_SimulateSheet> {
  String _kind = 'oxygen';
  String? _reactor;
  bool _busy = false;
  String? _result;

  Future<void> _fire() async {
    final api = ref.read(apiProvider);
    final id = _reactor;
    if (api == null || id == null) return;
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final secs = await api.triggerFault(id, _kind);
      if (!mounted) return;
      setState(
        () => _result = 'Fault replay started on $id. The alarm should arrive in about ${secs.round()} s.',
      );
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 900), () {
          if (mounted) Navigator.of(context).pop();
        }),
      );
    } on Object {
      if (mounted) {
        setState(() => _result = 'Could not reach the server. Check the connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(pairingProvider)?.demo ?? true;
    final reactors = ref.watch(reactorsProvider).values.toList()..sort((a, b) => a.id.compareTo(b.id));
    _reactor ??= reactors.isEmpty ? null : reactors.first.id;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(KSpace.s4, 0, KSpace.s4, KSpace.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Trigger a live alarm', style: KText.display(KSize.xl, weight: FontWeight.w800)),
            const SizedBox(height: KSpace.s1),
            Text(
              'Replays a real fault batch on the reactor you pick. Kairos must detect it from the sensors, '
              'exactly as in a plant.',
              style: KText.ui(KSize.sm, color: KColors.textSecondary),
            ),
            const SizedBox(height: KSpace.s4),
            Text('Fault', style: KText.ui(KSize.sm, weight: FontWeight.w600)),
            const SizedBox(height: KSpace.s2),
            for (final k in _kinds)
              Padding(
                padding: const EdgeInsets.only(bottom: KSpace.s2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => _kind = k.$1),
                  child: Container(
                    padding: const EdgeInsets.all(KSpace.s3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: _kind == k.$1 ? KColors.accentX500.withValues(alpha: 0.1) : KColors.bgBase,
                      border: Border.all(
                        color: _kind == k.$1 ? KColors.accentX500 : KColors.borderSubtle,
                        width: _kind == k.$1 ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          k.$4,
                          size: 20,
                          color: _kind == k.$1 ? KColors.accentX500 : KColors.textSecondary,
                        ),
                        const SizedBox(width: KSpace.s3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(k.$2, style: KText.ui(KSize.md, weight: FontWeight.w600)),
                              Text(k.$3, style: KText.ui(KSize.xs, color: KColors.textMuted)),
                            ],
                          ),
                        ),
                        if (_kind == k.$1)
                          Icon(LucideIcons.checkCircle2, size: 18, color: KColors.accentX500),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: KSpace.s2),
            Text('Reactor', style: KText.ui(KSize.sm, weight: FontWeight.w600)),
            const SizedBox(height: KSpace.s2),
            DropdownButtonFormField<String>(
              initialValue: _reactor,
              isExpanded: true,
              decoration: const InputDecoration(prefixIcon: Icon(LucideIcons.flaskConical, size: 18)),
              items: [for (final r in reactors) DropdownMenuItem(value: r.id, child: Text(r.id))],
              onChanged: (v) => setState(() => _reactor = v),
            ),
            if (_result != null) ...[
              const SizedBox(height: KSpace.s3),
              Text(_result!, style: KText.ui(KSize.sm, color: KColors.textSecondary)),
            ],
            const SizedBox(height: KSpace.s4),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: demo || _busy || _reactor == null ? null : _fire,
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(LucideIcons.zap, size: 18),
                label: Text(demo ? 'Needs a live server' : 'Start the fault'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small pill button used on the Alerts header.
class SimulateButton extends StatelessWidget {
  const SimulateButton({super.key});

  @override
  Widget build(BuildContext context) => Tag('Simulate', color: KColors.stateWatch, icon: LucideIcons.zap);
}
