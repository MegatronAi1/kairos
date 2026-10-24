import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Saved theme choice (system / dark / light). Dark is the default.
class ThemePrefStore {
  ThemePrefStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'theme';

  Future<ThemeMode> load() async {
    try {
      return switch (await _storage.read(key: _key)) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };
    } on Object {
      return ThemeMode.dark;
    }
  }

  Future<void> save(ThemeMode mode) async {
    try {
      await _storage.write(key: _key, value: mode.name);
    } on Object {
      // A preference only: failing to persist must not break the app.
    }
  }
}

/// Loaded before `runApp`; overridden in main.
final initialThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.dark);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(initialThemeModeProvider);

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ThemePrefStore().save(mode);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
