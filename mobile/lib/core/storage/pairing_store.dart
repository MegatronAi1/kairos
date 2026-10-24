import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the pager connects. `demo` means the built-in mock stream (no server).
class Pairing {
  const Pairing({required this.serverUrl, required this.token, this.demo = false});

  const Pairing.demo() : serverUrl = '', token = '', demo = true;

  final String serverUrl;
  final String token;
  final bool demo;

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

  Future<Pairing?> load() async {
    try {
      if (await _storage.read(key: _kDemo) == '1') return const Pairing.demo();
      final url = await _storage.read(key: _kUrl);
      if (url == null || url.isEmpty) return null;
      return Pairing(
        serverUrl: url,
        token: await _storage.read(key: _kToken) ?? '',
      );
    } on Object {
      return null; // corrupted keystore after reinstall: ask to pair again
    }
  }

  Future<void> save(Pairing p) async {
    await _storage.write(key: _kDemo, value: p.demo ? '1' : '0');
    await _storage.write(key: _kUrl, value: p.serverUrl);
    await _storage.write(key: _kToken, value: p.token);
  }

  Future<void> clear() => _storage.deleteAll();
}
