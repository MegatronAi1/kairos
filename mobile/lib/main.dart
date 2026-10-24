import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kairos_pager/app/app.dart';
import 'package:kairos_pager/core/notifications/alarm_alerts.dart';
import 'package:kairos_pager/core/notifications/alarm_service.dart';
import 'package:kairos_pager/core/process_providers.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/storage/pairing_store.dart';
import 'package:kairos_pager/core/theme/theme_pref.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final pairing = await PairingStore().load();
  final themeMode = await ThemePrefStore().load();
  final processId = await ProcessPrefStore().load();
  await AlarmAlerts.instance.init();
  AlarmService.init();
  runApp(
    ProviderScope(
      overrides: [
        initialPairingProvider.overrideWithValue(pairing),
        initialThemeModeProvider.overrideWithValue(themeMode),
        initialProcessIdProvider.overrideWithValue(processId),
      ],
      child: const KairosApp(),
    ),
  );
}
