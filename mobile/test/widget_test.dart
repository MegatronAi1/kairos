import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_pager/app/app.dart';
import 'package:kairos_pager/core/models/models.dart';
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

ReactorSummary _summary(String id, int batch) => ReactorSummary(
  id: id,
  batchId: batch,
  strategy: batch >= 91 ? 'fault' : 'recipe',
  isFaultBatch: batch >= 91,
  running: true,
  state: HealthState.normal,
  acknowledged: false,
  tEndH: 230,
);

Future<FakeSource> _pump(WidgetTester tester) async {
  final source = FakeSource();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialPairingProvider.overrideWithValue(const Pairing(serverUrl: 'http://test:8000', token: '')),
        eventSourceProvider.overrideWithValue(source),
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
    expect(find.text('Plant'), findsOneWidget);
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
    expect(find.text('Plant'), findsOneWidget);
  });
}
