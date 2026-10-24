import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_pager/app/app.dart';
import 'package:kairos_pager/core/api/kairos_api.dart';
import 'package:kairos_pager/core/models/chat.dart';
import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/models/plant.dart';
import 'package:kairos_pager/core/process_providers.dart';
import 'package:kairos_pager/core/providers.dart';
import 'package:kairos_pager/core/storage/pairing_store.dart';
import 'package:kairos_pager/core/theme/tokens.dart';
import 'package:kairos_pager/core/ws/event_source.dart';
import 'package:kairos_pager/features/chat/chat_screen.dart';
import 'package:kairos_pager/widgets/ui.dart';

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

/// API whose chat replays scripted events.
class FakeChatApi extends KairosApi {
  FakeChatApi() : super(const Pairing(serverUrl: 'https://example.test', token: 't'));

  final asked = <List<ChatMessage>>[];

  @override
  Stream<ChatEvent> chat(
    List<ChatMessage> messages, {
    String? reactorId,
    String? processId,
    CancelToken? cancel,
  }) async* {
    asked.add(messages);
    yield const ChatTool('get_reactor_status');
    yield const ChatText('PUN-R2 is **short of oxygen**. ');
    yield const ChatText('Raise aeration.');
    yield const ChatEvidence(['fault_detector']);
    yield const ChatDone();
  }
}

Json _fixture(String name) => jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Json;

ReactorSummary _summary(String id, int batch, {String plant = '', HealthState state = HealthState.normal}) =>
    ReactorSummary(
      id: id,
      plantId: plant,
      batchId: batch,
      strategy: batch >= 91 ? 'fault' : 'recipe',
      isFaultBatch: batch >= 91,
      running: true,
      state: state,
      acknowledged: false,
      tEndH: 230,
    );

const _plants = [
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
  PlantSummary(
    id: 'paris',
    name: 'Paris Collagen Foundry',
    city: 'Paris',
    country: 'France',
    processId: 'collagen',
    processName: 'Animal-free collagen',
    processFamily: 'precision',
    state: HealthState.normal,
  ),
];

Future<FakeSource> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  final source = FakeSource();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialPairingProvider.overrideWithValue(
          const Pairing(
            serverUrl: 'http://test:8000',
            token: '',
            userName: 'Priya Shah',
            userRole: 'Operator',
            tenantName: 'Aurora Bioproteins',
          ),
        ),
        eventSourceProvider.overrideWithValue(source),
        processesProvider.overrideWith((ref) async => const []),
        plantsProvider.overrideWith((ref) async => _plants),
      ],
      child: const KairosApp(),
    ),
  );
  await tester.pump();
  return source;
}

void _fleet(FakeSource source) => source.emit(
  SnapshotFrame([
    _summary('PUN-R1', 26, plant: 'pune'),
    _summary('PUN-R2', 99, plant: 'pune', state: HealthState.alarm),
    _summary('PAR-R1', 22, plant: 'paris', state: HealthState.watch),
  ]),
);

void main() {
  testWidgets('home shows the fleet at a glance, the floating nav switches tabs', (tester) async {
    final source = await _pump(tester);
    _fleet(source);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Aurora Bioproteins'), findsOneWidget);
    expect(find.textContaining('Priya'), findsOneWidget);
    expect(find.text('2'), findsWidgets); // two reactors need attention
    expect(find.text('Needs attention'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Reactors').last);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );
    expect(find.text('Search reactor, plant or process'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Profile').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Priya Shah'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('reactor list filters by state', (tester) async {
    final source = await _pump(tester);
    _fleet(source);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Reactors').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('PUN-R1'), findsOneWidget);
    expect(find.text('PUN-R2'), findsOneWidget);
    expect(find.text('PAR-R1'), findsOneWidget);

    await tester.tap(find.text('Alarm 1'));
    await tester.pump();
    expect(find.text('PUN-R2'), findsOneWidget);
    expect(find.text('PUN-R1'), findsNothing);
    expect(find.text('PAR-R1'), findsNothing);
    expect(find.text('1 of 3 shown'), findsOneWidget);
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
    expect(find.text('Expected: +6 to +11% final yield (model estimate)'), findsOneWidget);

    await tester.tap(find.text('Acknowledge alarm'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('ALARM'), findsNothing);
    expect(find.text('Aurora Bioproteins'), findsOneWidget);
  });

  testWidgets('Ask Kairos streams the answer with tool activity and evidence', (tester) async {
    final api = FakeChatApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(api), reactorsProvider.overrideWith(_NoReactors.new)],
        child: const MaterialApp(home: ChatScreen(reactorId: 'PUN-R2')),
      ),
    );
    expect(find.text('Context: PUN-R2'), findsOneWidget);
    await tester.tap(find.text('Why is PUN-R2 drifting and what should I do?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Why is PUN-R2 drifting and what should I do?'), findsOneWidget); // user bubble
    expect(find.textContaining('short of oxygen', findRichText: true), findsOneWidget);
    expect(find.textContaining('Raise aeration', findRichText: true), findsOneWidget);
    expect(find.text('fault detector'), findsWidgets);
    expect(api.asked.single.last.content, 'Why is PUN-R2 drifting and what should I do?');
  });

  testWidgets('Ask Kairos button is green in light mode and white in dark mode', (tester) async {
    Future<Material> pumpIn(Brightness b) async {
      KColors.palette = b == Brightness.light ? KPalette.light : KPalette.dark;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: b),
          home: Scaffold(body: AskKairosButton(onPressed: () {})),
        ),
      );
      await tester.pumpAndSettle();
      return tester.widget<Material>(
        find.descendant(of: find.byType(AskKairosButton), matching: find.byType(Material)).first,
      );
    }

    final light = await pumpIn(Brightness.light);
    expect(light.color, KPalette.light.accentX500);
    final dark = await pumpIn(Brightness.dark);
    expect(dark.color, Colors.white);
  });
}

class _NoReactors extends ReactorsNotifier {
  @override
  Map<String, ReactorView> build() => const {};
}
