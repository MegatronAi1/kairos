import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_pager/app/app.dart';
import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/models/plant.dart';
import 'package:kairos_pager/core/process_providers.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/storage/pairing_store.dart';
import 'package:kairos_pager/core/ws/event_source.dart';

/// Event source driven by the test.
class FakeSource implements EventSource {
  final frames$ = StreamController<Frame>.broadcast();
  final status$ = StreamController<ConnectionStatus>.broadcast();

  @override
  Stream<Frame> get frames => frames$.stream;

  @override
  Stream<ConnectionStatus> get status => status$.stream;

  @override
  void start() {}

  @override
  Future<void> dispose() async {}

  void emit(Frame f) => frames$.add(f);
}

Json _fixture(String name) => jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Json;

ReactorSummary _summary(String id, int batch, {String plant = ''}) => ReactorSummary(
  id: id,
  plantId: plant,
  batchId: batch,
  strategy: batch >= 91 ? 'fault' : 'recipe',
  isFaultBatch: batch >= 91,
  running: true,
  state: HealthState.normal,
  acknowledged: false,
  tEndH: 230,
);

Future<FakeSource> _pump(
  WidgetTester tester, {
  List<PlantSummary> plants = const [],
  Pairing pairing = const Pairing(serverUrl: 'http://test:8000', token: ''),
}) async {
  final source = FakeSource();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialPairingProvider.overrideWithValue(pairing),
        eventSourceProvider.overrideWithValue(source),
        processesProvider.overrideWith((ref) async => const []),
        plantsProvider.overrideWith((ref) async => plants),
      ],
      child: const KairosApp(),
    ),
  );
  await tester.pump();
  return source;
}

void main() {
  testWidgets('plant shows skeletons, then reactors from the snapshot', (tester) async {
    final source = await _pump(tester);
    expect(find.text('Plants'), findsOneWidget);
    expect(find.text('R1'), findsNothing);

    source.emit(SnapshotFrame([_summary('R1', 22), _summary('R2', 91)]));
    await tester.pump();
    expect(find.text('R1'), findsWidgets);
    expect(find.text('R2'), findsWidgets);
    expect(find.text('Batch 91 · Fault batch'), findsOneWidget);
    expect(find.text('All 2 reactors running smoothly'), findsOneWidget);

    source.emit(EventFrame(KEvent.fromJson(_fixture('tick.json'))!));
    await tester.pump();
    expect(find.text('2,706 kg', findRichText: true), findsOneWidget);
    expect(find.text('88% of typical'), findsOneWidget);
  });

  testWidgets('alarm event opens the takeover with the action, acknowledge closes it', (tester) async {
    final source = await _pump(tester);
    source
      ..emit(SnapshotFrame([_summary('R2', 91)]))
      ..emit(EventFrame(KEvent.fromJson(_fixture('tick.json'))!))
      ..emit(EventFrame(KEvent.fromJson(_fixture('insight.json'))!))
      ..emit(EventFrame(KEvent.fromJson(_fixture('alarm.json'))!));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('ALARM'), findsOneWidget);
    expect(find.text('Oxygen limitation developing'), findsOneWidget);
    expect(find.text('Reduce sugar feed 10% for 3 h'), findsOneWidget);
    expect(find.textContaining('to point of no return'), findsOneWidget);

    await tester.tap(find.text('Acknowledge'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('ALARM'), findsNothing);
    expect(find.text('Plants'), findsOneWidget);
  });

  testWidgets('reactors are grouped by plant with the demo plant first', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const plants = [
      PlantSummary(
        id: 'bengaluru',
        name: 'Bengaluru Precision Dairy',
        city: 'Bengaluru',
        country: 'India',
        processId: 'whey',
        processName: 'Whey protein',
        processFamily: 'precision',
        state: HealthState.normal,
      ),
      PlantSummary(
        id: 'pune',
        name: 'Pune Mycoprotein Works',
        city: 'Pune',
        country: 'India',
        processId: 'mycoprotein',
        processName: 'Mycoprotein',
        processFamily: 'biomass',
        state: HealthState.normal,
      ),
    ];
    final source = await _pump(
      tester,
      plants: plants,
      pairing: const Pairing(
        serverUrl: 'http://test:8000',
        token: '',
        userName: 'Priya Shah',
        userRole: 'Operator',
        tenantName: 'Aurora Bioproteins',
      ),
    );
    source.emit(
      SnapshotFrame([
        _summary('BLR-R1', 65, plant: 'bengaluru'),
        _summary('PUN-R1', 26, plant: 'pune'),
        _summary('PUN-R2', 99, plant: 'pune'),
      ]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Aurora Bioproteins'), findsOneWidget);
    expect(find.text('Hi Priya'), findsOneWidget);
    expect(find.text('All 3 reactors running smoothly across 2 plants'), findsOneWidget);
    final pune = tester.getTopLeft(find.text('Pune Mycoprotein Works'));
    final blr = tester.getTopLeft(find.text('Bengaluru Precision Dairy'));
    expect(pune.dy, lessThan(blr.dy));
    expect(find.text('Pune · Mycoprotein'), findsOneWidget);
    expect(find.text('R2'), findsOneWidget); // short id inside its plant
  });
}
