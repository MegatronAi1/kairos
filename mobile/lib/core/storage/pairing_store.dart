import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the pager connects and who signed in. `demo` means the built-in mock
/// stream (no server).
class Pairing {
  const Pairing({
    required this.serverUrl,
    required this.token,
    this.demo = false,
    this.userName = '',
    this.userRole = '',
    this.userEmail = '',
    this.tenantName = '',
  });

  const Pairing.demo()
    : serverUrl = '',
      token = '',
      demo = true,
      userName = 'Demo operator',
      userRole = 'Operator',
      userEmail = '',
      tenantName = 'Demo plant';

  final String serverUrl;
  final String token;
  final bool demo;
  final String userName;
  final String userRole;
  final String userEmail;
  final String tenantName;

  String get firstName => userName.trim().isEmpty ? '' : userName.trim().split(' ').first;

  Uri get httpBase => Uri.parse(serverUrl.endsWith('/') ? serverUrl : '$serverUrl/');

  Uri get wsUri {
    final base = httpBase;
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '${base.path}ws',
      queryParameters: token.isEmpty ? null : {'token': token},
    );
  }

  String get label => demo ? 'Demo data (offline)' : httpBase.authority;
}

class PairingStore {
  PairingStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _kUrl = 'server_url';
  static const _kToken = 'token';
  static const _kDemo = 'demo';
  static const _kUser = 'user_name';
  static const _kRole = 'user_role';
  static const _kEmail = 'user_email';
  static const _kTenant = 'tenant_name';

  Future<Pairing?> load() async {
    try {
      if (await _storage.read(key: _kDemo) == '1') return const Pairing.demo();
      final url = await _storage.read(key: _kUrl);
      if (url == null || url.isEmpty) return null;
      return Pairing(
        serverUrl: url,
        token: await _storage.read(key: _kToken) ?? '',
        userName: await _storage.read(key: _kUser) ?? '',
        userRole: await _storage.read(key: _kRole) ?? '',
        userEmail: await _storage.read(key: _kEmail) ?? '',
        tenantName: await _storage.read(key: _kTenant) ?? '',
      );
    } on Object {
      return null; // corrupted keystore after reinstall: ask to pair again
    }
  }

  Future<void> save(Pairing p) async {
    await _storage.write(key: _kDemo, value: p.demo ? '1' : '0');
    await _storage.write(key: _kUrl, value: p.serverUrl);
    await _storage.write(key: _kToken, value: p.token);
    await _storage.write(key: _kUser, value: p.userName);
    await _storage.write(key: _kRole, value: p.userRole);
    await _storage.write(key: _kEmail, value: p.userEmail);
    await _storage.write(key: _kTenant, value: p.tenantName);
  }

  Future<void> clear() => _storage.deleteAll();
}
