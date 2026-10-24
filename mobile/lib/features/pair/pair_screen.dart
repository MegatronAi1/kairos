import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kairos_pager/core/api/kairos_api.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/storage/pairing_store.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/core/theme/tokens.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Sign in to the company's Kairos server. Demo accounts are offered by the server.
/// The live Kairos deployment (CloudFront, HTTPS/WSS).
const kLiveServer = 'https://dppjlgz96ztew.cloudfront.net';

/// The laptop over a USB port forward (`adb reverse tcp:8000 tcp:8000`).
const kLocalServer = 'http://localhost:8000';

class PairScreen extends ConsumerStatefulWidget {
  const PairScreen({super.key});

  @override
  ConsumerState<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends ConsumerState<PairScreen> {
  final _url = TextEditingController(text: kLiveServer);
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showServer = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Validated server address, or null (with an error shown).
  String? _server() {
    final url = _url.text.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      setState(() {
        _showServer = true;
        _error = 'Enter the server address, for example http://192.168.1.20:8000';
      });
      return null;
    }
    return url;
  }

  Future<void> _useDemoAccount() async {
    final url = _server();
    if (url == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final accounts = await KairosApi(Pairing(serverUrl: url, token: '')).demoAccounts();
      if (accounts.isEmpty) throw StateError('no demo accounts');
      final a = accounts.firstWhere((x) => x.role.toLowerCase() == 'operator', orElse: () => accounts.first);
      _email.text = a.email;
      _password.text = a.password;
    } on Object {
      if (mounted) setState(() => _error = "Couldn't reach Kairos at $url to fetch the demo account.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    final url = _server();
    if (url == null) return;
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your email and password, or use the demo account.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await KairosApi(Pairing(serverUrl: url, token: '')).login(_email.text.trim(), _password.text);
      await ref
          .read(pairingProvider.notifier)
          .pair(
            Pairing(
              serverUrl: url,
              token: r.token,
              userName: r.userName,
              userRole: r.userRole,
              userEmail: r.userEmail,
              tenantName: r.tenantName,
            ),
          );
    } on DioException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.response?.statusCode == 401
              ? "That email and password don't match. Try the demo account."
              : "Couldn't reach Kairos at $url. Check the laptop is on and on the same network.",
        );
      }
    } on Object {
      if (mounted) setState(() => _error = 'Something went wrong signing in. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(KSpace.s6, KSpace.s12, KSpace.s6, KSpace.s6),
          children: [
            Row(
              children: [
                Image.asset('assets/brand/kairos_mark.png', width: 30, height: 30, semanticLabel: 'Kairos'),
                const SizedBox(width: KSpace.s2),
                Text('Kairos', style: KText.display(KSize.xl)),
              ],
            ),
            const SizedBox(height: KSpace.s8),
            Text('Sign in', style: KText.display(KSize.x3xl)),
            const SizedBox(height: KSpace.s2),
            Text(
              'Your plants, your reactors and their alarms, in your pocket.',
              style: KText.ui(KSize.lg, color: KColors.textSecondary),
            ),
            const SizedBox(height: KSpace.s8),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              style: KText.ui(KSize.lg),
              decoration: const InputDecoration(labelText: 'Work email', hintText: 'name@company.com'),
            ),
            const SizedBox(height: KSpace.s4),
            TextField(
              controller: _password,
              obscureText: true,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _busy ? null : _signIn(),
              style: KText.ui(KSize.lg),
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            if (_error != null) ...[
              const SizedBox(height: KSpace.s3),
              Text(_error!, style: KText.ui(KSize.md, color: KColors.stateAlarm)),
            ],
            const SizedBox(height: KSpace.s6),
            FilledButton(
              onPressed: _busy ? null : _signIn,
              child: _busy
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Sign in'),
            ),
            const SizedBox(height: KSpace.s3),
            OutlinedButton.icon(
              onPressed: _busy ? null : _useDemoAccount,
              icon: const Icon(LucideIcons.userCheck, size: 18),
              label: const Text('Use demo account'),
            ),
            const SizedBox(height: KSpace.s4),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: ValueKey(_showServer),
                initiallyExpanded: _showServer,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: KSpace.s2),
                leading: Icon(LucideIcons.server, size: 18, color: KColors.textSecondary),
                title: Text('Server', style: KText.ui(KSize.md, color: KColors.textSecondary)),
                subtitle: Text(_url.text, style: KText.mono(KSize.sm, color: KColors.textMuted)),
                children: [
                  TextField(
                    controller: _url,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    onChanged: (_) => setState(() {}),
                    style: KText.mono(KSize.md),
                    decoration: const InputDecoration(
                      labelText: 'Server address',
                      hintText: 'https://your-kairos-server',
                    ),
                  ),
                  const SizedBox(height: KSpace.s2),
                  Wrap(
                    spacing: KSpace.s2,
                    children: [
                      ActionChip(
                        label: const Text('Live server'),
                        onPressed: () => setState(() => _url.text = kLiveServer),
                      ),
                      ActionChip(
                        label: const Text('Use local laptop (http://localhost:8000)'),
                        onPressed: () => setState(() => _url.text = kLocalServer),
                      ),
                    ],
                  ),
                  const SizedBox(height: KSpace.s2),
                ],
              ),
            ),
            Align(
              child: TextButton(
                onPressed: _busy ? null : () => ref.read(pairingProvider.notifier).pair(const Pairing.demo()),
                child: Text(
                  'No server? Explore with offline demo data',
                  style: KText.ui(KSize.sm, color: KColors.textSecondary),
                ),
              ),
            ),
            const SizedBox(height: KSpace.s4),
            Text(
              'Demo company: Aurora Bioproteins (fictional). Reactor data replays the IndPenSim simulator '
              '(synthetic). The app stores only the server address, your session and your name.',
              style: KText.ui(KSize.sm, color: KColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
