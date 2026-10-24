import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kairos_pager/core/api/kairos_api.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/storage/pairing_store.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';

class PairScreen extends ConsumerStatefulWidget {
  const PairScreen({super.key});

  @override
  ConsumerState<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends ConsumerState<PairScreen> {
  final _url = TextEditingController(text: 'http://');
  final _token = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final url = _url.text.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      setState(() => _error = 'Enter the server address, for example http://192.168.1.20:8000');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final pairing = Pairing(serverUrl: url, token: _token.text.trim());
    try {
      final ok = await KairosApi(pairing).ping();
      if (!ok) throw Exception('unexpected response');
      await ref.read(pairingProvider.notifier).pair(pairing);
    } on Object {
      if (mounted) {
        setState(
          () => _error = 'Could not reach Kairos at that address. Check the laptop is on the same Wi-Fi.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(KSpace.s6),
          children: [
            const SizedBox(height: KSpace.s12),
            Text('Kairos Pager', style: KText.ui(KSize.x3xl, weight: FontWeight.w600)),
            const SizedBox(height: KSpace.s2),
            Text(
              'Connect to the Kairos Control Room to receive reactor alarms on this phone.',
              style: KText.ui(KSize.lg, color: KColors.textSecondary),
            ),
            const SizedBox(height: KSpace.s8),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              autocorrect: false,
              style: KText.mono(KSize.lg),
              decoration: const InputDecoration(
                labelText: 'Server address',
                hintText: 'http://192.168.1.20:8000',
              ),
            ),
            const SizedBox(height: KSpace.s4),
            TextField(
              controller: _token,
              obscureText: true,
              autocorrect: false,
              style: KText.mono(KSize.lg),
              decoration: const InputDecoration(labelText: 'Access token (if set)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: KSpace.s3),
              Text(_error!, style: KText.ui(KSize.md, color: KColors.stateAlarm)),
            ],
            const SizedBox(height: KSpace.s6),
            FilledButton(
              onPressed: _busy ? null : _connect,
              child: _busy
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Connect'),
            ),
            const SizedBox(height: KSpace.s3),
            OutlinedButton(
              onPressed: _busy ? null : () => ref.read(pairingProvider.notifier).pair(const Pairing.demo()),
              child: const Text('Use demo data (no server)'),
            ),
            const SizedBox(height: KSpace.s6),
            Text(
              'Data shown is from the IndPenSim simulator (synthetic). No personal data is stored; '
              'the app keeps only the server address and token.',
              style: KText.ui(KSize.sm, color: KColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
