import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kairos_pager/app/app.dart';
import 'package:kairos_pager/core/notifications/alarm_alerts.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/storage/pairing_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final pairing = await PairingStore().load();
  await AlarmAlerts.instance.init();
  runApp(
    ProviderScope(
      overrides: [initialPairingProvider.overrideWithValue(pairing)],
      child: const KairosApp(),
    ),
  );
}
