import 'package:dio/dio.dart';
import 'package:kairos_pager/core/models/models.dart';
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

  Future<bool> ping() async {
    if (pairing.demo) return true;
    final res = await _dio.get<Map<String, dynamic>>('healthz');
    return res.data?['status'] == 'ok';
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

  Future<void> acknowledge(String reactorId, {String by = 'pager'}) async {
    if (pairing.demo) return;
    await _dio.post<void>('reactors/$reactorId/ack', data: {'by': by});
  }
}
