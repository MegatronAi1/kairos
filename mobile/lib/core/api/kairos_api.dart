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

  Future<void> acknowledge(String reactorId, {String by = 'pager'}) async {
    if (pairing.demo) return;
    await _dio.post<void>('reactors/$reactorId/ack', data: {'by': by});
  }
}
