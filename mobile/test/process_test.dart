import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/models/process.dart';
import 'package:kairos_pager/core/process_providers.dart';
import 'package:kairos_pager/core/theme/kairos_theme.dart';
import 'package:kairos_pager/features/process/process_screen.dart';

Json _fixture() => jsonDecode(File('test/fixtures/process.json').readAsStringSync()) as Json;

void main() {
  test('process detail parses the catalog shape', () {
    final p = ProcessDetail.fromJson(_fixture());
    expect(p.family, ProcessFamily.biomass);
    expect(p.reactor, ReactorKind.airlift);
    expect(p.example.company, startsWith('Quorn'));
    expect(p.benchmarkFit, BenchmarkFit.high);
    expect(p.setpoints['temp_c']!.text, '30');
    expect(p.setpoints['dilution_rate_per_h']!.text, '0.17–0.2');
    expect(p.setpoints['do_pct']!.provenance, Provenance.assumed);
    expect(p.rangeFor(['do_pct']), '20–40%');
    expect(p.rangeFor(['temp_c']), '30 °C');
    expect(p.phases, hasLength(2));
    expect(p.phases.first.controls.single.param, 'temperature');
    expect(p.controlLoops.single.actuator, 'Ammonia feed');
    expect(p.faultSignatures, isNotEmpty);
  });

  test('summary parses list rows with a top-level benchmark_fit', () {
    final s = ProcessSummary.fromJson({
      'id': 'whey',
      'family': 'precision',
      'name': 'Whey protein',
      'product': 'Beta-lactoglobulin',
      'example': {'company': 'Perfect Day'},
      'organism': 'Trichoderma reesei',
      'reactor': 'stirred_tank',
      'mode': 'fed_batch',
      'benchmark_fit': 'medium',
    });
    expect(s.family, ProcessFamily.precision);
    expect(s.reactor, ReactorKind.stirredTank);
    expect(s.benchmarkFit, BenchmarkFit.medium);
  });

  testWidgets('process screen renders hero, schematic and phases', (tester) async {
    final detail = ProcessDetail.fromJson(_fixture());
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          processesProvider.overrideWith((ref) async => [detail]),
          processDetailProvider.overrideWith((ref, id) async => detail),
        ],
        child: MaterialApp(theme: kairosTheme(Brightness.dark), home: const ProcessScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Mycoprotein'), findsOneWidget);
    expect(find.text('Biomass fermentation'), findsOneWidget);
    expect(find.text('Strong match'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Continuous growth'), 300);
    expect(find.text('Inoculation and batch growth'), findsOneWidget);
    expect(find.text('Continuous growth'), findsOneWidget);
  });
}
