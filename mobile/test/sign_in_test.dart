import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_pager/app/app.dart';
import 'package:kairos_pager/core/models/plant.dart';
import 'package:kairos_pager/core/providers.dart';

void main() {
  testWidgets('unsigned users land on the sign-in screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [initialPairingProvider.overrideWithValue(null)],
        child: const KairosApp(),
      ),
    );
    await tester.pump();
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Use demo account'), findsOneWidget);
    expect(find.text('Work email'), findsOneWidget);
  });

  test('login result and plant parse from server JSON', () {
    final r = LoginResult.fromJson({
      'token': 't',
      'user': {'email': 'operator@aurora.demo', 'name': 'Priya Shah', 'role': 'Operator'},
      'tenant': {'id': 'aurora', 'name': 'Aurora Bioproteins'},
    });
    expect(r.userName, 'Priya Shah');
    expect(r.tenantName, 'Aurora Bioproteins');
    final p = PlantSummary.fromJson({
      'id': 'pune',
      'name': 'Pune Mycoprotein Works',
      'city': 'Pune',
      'country': 'India',
      'process_id': 'mycoprotein',
      'process_name': 'Mycoprotein',
      'process_family': 'biomass',
      'reactor_ids': ['PUN-R1'],
      'state': 'alarm',
      'alarms_open': 1,
      'power_kw': 540.5,
    });
    expect(p.state.name, 'alarm');
    expect(p.familyLabel, 'Biomass fermentation');
    expect(p.reactorIds, ['PUN-R1']);
  });
}
