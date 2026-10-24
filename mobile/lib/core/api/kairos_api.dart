import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:kairos_pager/core/models/chat.dart';
import 'package:kairos_pager/core/models/models.dart';
import 'package:kairos_pager/core/models/plant.dart';
import 'package:kairos_pager/core/models/process.dart';
import 'package:kairos_pager/core/storage/pairing_store.dart';

/// REST client for `/api/v1`. In demo mode calls succeed locally without a server.
class KairosApi {
  KairosApi(this.pairing)
    : _dio = Dio(
        BaseOptions(
          baseUrl: pairing.demo ? 'http://localhost/' : pairing.httpBase.resolve('api/v1/').toString(),
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 8),
          headers: {if (pairing.token.isNotEmpty) 'Authorization': 'Bearer ${pairing.token}'},
        ),
      );

  final Pairing pairing;
  final Dio _dio;

  /// Send operator feedback to the Kairos team (stored server-side).
  Future<void> sendFeedback(FeedbackPayload f) async {
    if (pairing.demo) return;
    await _dio.post<void>('feedback', data: f.toJson());
  }

  Future<bool> ping() async {
    if (pairing.demo) return true;
    final res = await _dio.get<Map<String, dynamic>>('healthz');
    return res.data?['status'] == 'ok';
  }

  /// Demo accounts the server offers on its sign-in screen.
  Future<List<DemoAccount>> demoAccounts() async {
    final res = await _dio.get<List<dynamic>>('auth/demo-accounts');
    return (res.data ?? const []).map((e) => DemoAccount.fromJson(e as Json)).toList();
  }

  /// Signs in; throws [DioException] (401) when the email or password is wrong.
  Future<LoginResult> login(String email, String password) async {
    final res = await _dio.post<Map<String, dynamic>>(
      'auth/login',
      data: {'email': email, 'password': password},
    );
    return LoginResult.fromJson(res.data!);
  }

  /// Plants of the signed-in company with live roll-ups. Demo mode: one local plant.
  Future<List<PlantSummary>> plants() async {
    if (pairing.demo) {
      return const [
        PlantSummary(
          id: 'pune',
          name: 'Demo plant',
          city: 'Offline demo',
          country: '',
          processId: 'mycoprotein',
          processName: 'Mycoprotein',
          processFamily: 'biomass',
          state: HealthState.normal,
          reactorIds: ['PUN-R1', 'PUN-R2', 'PUN-R3', 'PUN-R4'],
        ),
      ];
    }
    final res = await _dio.get<List<dynamic>>('plants');
    return (res.data ?? const []).map((e) => PlantSummary.fromJson(e as Json)).toList();
  }

  /// Alarm history of one reactor (state transitions since its batch started).
  Future<List<AlarmEvent>> events(String reactorId) async {
    if (pairing.demo) return const [];
    final res = await _dio.get<List<dynamic>>('reactors/$reactorId/events');
    return (res.data ?? const []).map((e) => AlarmEvent.fromJson(e as Json)).toList();
  }

  Future<List<ReactorSummary>> reactors() async {
    if (pairing.demo) return const [];
    final res = await _dio.get<List<dynamic>>('reactors');
    return (res.data ?? const []).map((e) => ReactorSummary.fromJson(e as Json)).toList();
  }

  /// Energy (or rescue) setpoints for the reactor's current moment.
  Future<EnergyRecommendation> recommendation(String reactorId, {bool rescue = false}) async {
    if (pairing.demo) {
      // Demo data: a plausible illustrative recommendation, flagged as demo.
      return const EnergyRecommendation(
        action: 'Lower aeration 60 to 45 m³/min, lower agitation 100 to 90 rpm',
        current: SetpointOption(rpm: 100, aeration: 60, powerKw: 133.5, doPct: 78),
        recommended: SetpointOption(rpm: 90, aeration: 45, powerKw: 99.2, doPct: 62),
        powerSavingKw: 34.3,
        energyDeltaPct: -25.7,
        kwhSavedRestOfBatch: 5600,
        co2SavedKg: 4071,
        inrSaved: 44800,
        targetDoPct: 35,
        demo: true,
      );
    }
    final res = await _dio.get<Map<String, dynamic>>(
      'reactors/$reactorId/recommendation',
      queryParameters: {'mode': rescue ? 'rescue' : 'energy'},
    );
    return EnergyRecommendation.fromJson(res.data!);
  }

  /// Alternative-protein process library. Empty in demo mode (no server to load it from).
  Future<List<ProcessSummary>> processes() async {
    if (pairing.demo) return const [];
    final res = await _dio.get<Map<String, dynamic>>('processes');
    final list = (res.data?['processes'] as List?) ?? const [];
    return list.map((e) => ProcessSummary.fromJson(e as Json)).toList();
  }

  Future<ProcessDetail> process(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('processes/$id');
    return ProcessDetail.fromJson(res.data!);
  }

  /// Ask Kairos: streams the agent's answer (Server-Sent Events from `POST agent/chat`).
  Stream<ChatEvent> chat(
    List<ChatMessage> messages, {
    String? reactorId,
    String? processId,
    CancelToken? cancel,
  }) async* {
    if (pairing.demo) {
      yield* _demoChat(reactorId);
      return;
    }
    final res = await _dio.post<ResponseBody>(
      'agent/chat',
      data: {
        'messages': [for (final m in messages) m.toJson()],
        'reactor_id': reactorId,
        'process_id': processId,
      },
      cancelToken: cancel,
      options: Options(
        responseType: ResponseType.stream,
        receiveTimeout: const Duration(seconds: 120),
        headers: {'Accept': 'text/event-stream'},
      ),
    );
    final pending = StringBuffer();
    final lines = res.data!.stream.cast<List<int>>().transform(utf8.decoder);
    await for (final chunk in lines) {
      pending.write(chunk.replaceAll('\r\n', '\n'));
      while (true) {
        final text = pending.toString();
        final cut = text.indexOf('\n\n');
        if (cut < 0) break;
        final frame = text.substring(0, cut);
        pending
          ..clear()
          ..write(text.substring(cut + 2));
        final data = frame
            .split('\n')
            .where((l) => l.startsWith('data:'))
            .map((l) => l.substring(5).trim())
            .join();
        if (data.isEmpty) continue;
        final ev = ChatEvent.fromJson(jsonDecode(data) as Json);
        if (ev != null) yield ev;
        if (ev is ChatDone) return;
      }
    }
  }

  Stream<ChatEvent> _demoChat(String? reactorId) async* {
    yield const ChatTool('get_reactor_status');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final who = reactorId ?? 'The demo plant';
    final answer =
        '$who is replaying offline demo data, so this is a sample answer. '
        'Connect to a Kairos server to ask the copilot about live reactors.';
    final words = answer.split(' ');
    for (final w in words) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      yield ChatText('$w ');
    }
    yield const ChatEvidence(['demo data']);
    yield const ChatDone();
  }

  /// Demo: replay a real fault batch on [reactorId]. Returns the expected
  /// seconds until the detector raises the alarm.
  Future<double> triggerFault(String reactorId, String kind) async {
    final res = await _dio.post<Map<String, dynamic>>(
      'demo/trigger-fault',
      data: {'reactor_id': reactorId, 'kind': kind},
    );
    return (res.data?['expected_alarm_in_s'] as num?)?.toDouble() ?? 5;
  }

  Future<void> acknowledge(String reactorId, {String by = 'pager'}) async {
    if (pairing.demo) return;
    await _dio.post<void>('reactors/$reactorId/ack', data: {'by': by});
  }
}

class FeedbackPayload {
  const FeedbackPayload({
    required this.category,
    required this.rating,
    required this.message,
    required this.page,
    this.reactorId,
  });

  final String category;
  final int rating;
  final String message;
  final String page;
  final String? reactorId;

  Map<String, dynamic> toJson() => {
    'category': category,
    'rating': rating,
    'message': message,
    'source': 'pager',
    'reactor_id': reactorId,
    'page': page,
  };
}
