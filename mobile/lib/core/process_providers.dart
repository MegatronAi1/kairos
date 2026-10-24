import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kairos_pager/core/models/process.dart';
import 'package:kairos_pager/core/providers.dart';

/// Remembers which alternative-protein process the operator configured.
class ProcessPrefStore {
  ProcessPrefStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'process';

  Future<String?> load() async {
    try {
      return await _storage.read(key: _key);
    } on Object {
      return null;
    }
  }

  Future<void> save(String id) async {
    try {
      await _storage.write(key: _key, value: id);
    } on Object {
      // A preference only: failing to persist must not break the app.
    }
  }
}

/// Loaded before `runApp`; overridden in main.
final initialProcessIdProvider = Provider<String?>((ref) => null);

class SelectedProcessIdNotifier extends Notifier<String?> {
  @override
  String? build() => ref.read(initialProcessIdProvider);

  Future<void> select(String id) async {
    state = id;
    await ProcessPrefStore().save(id);
  }
}

final selectedProcessIdProvider = NotifierProvider<SelectedProcessIdNotifier, String?>(
  SelectedProcessIdNotifier.new,
);

/// The catalog list from the paired server (empty in demo mode or when unpaired).
final processesProvider = FutureProvider<List<ProcessSummary>>((ref) async {
  final api = ref.watch(apiProvider);
  if (api == null) return const [];
  return api.processes();
});

/// Selected process, defaulting to the first in the catalog.
final selectedProcessProvider = Provider<ProcessSummary?>((ref) {
  final list = ref.watch(processesProvider).value ?? const [];
  if (list.isEmpty) return null;
  final id = ref.watch(selectedProcessIdProvider);
  return list.firstWhere((p) => p.id == id, orElse: () => list.first);
});

final processDetailProvider = FutureProvider.family<ProcessDetail, String>((ref, id) async {
  final api = ref.watch(apiProvider);
  if (api == null) throw StateError('Not paired');
  return api.process(id);
});
