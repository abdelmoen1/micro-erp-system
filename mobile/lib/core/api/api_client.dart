import 'package:dio/dio.dart';

import 'api_failure.dart';
import 'error_mapper.dart';

/// Thin dio wrapper for API v1 (US-1304): base URL, bearer token, timeouts,
/// and every error mapped to a typed [ApiFailure].
class ApiClient {
  ApiClient({
    required String baseUrl,
    required Future<String?> Function() readToken,
    this.onSessionFailure,
    HttpClientAdapter? adapter,
  }) : dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: const Duration(seconds: 10),
           sendTimeout: const Duration(seconds: 15),
           receiveTimeout: const Duration(seconds: 20),
           headers: {'Accept': 'application/json'},
           contentType: Headers.jsonContentType,
           responseType: ResponseType.json,
         ),
       ) {
    if (adapter != null) dio.httpClientAdapter = adapter;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['auth'] != false) {
            final token = await readToken();
            if (token != null) options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio dio;

  /// Called when an authenticated call returns 401 or USER_INACTIVE.
  final void Function(ApiFailure failure)? onSessionFailure;

  Future<Map<String, dynamic>> get(String path, {bool auth = true, Map<String, dynamic>? query}) => _send(
    () => dio.get<dynamic>(path, queryParameters: query, options: Options(extra: {'auth': auth})),
    auth,
  );

  Future<Map<String, dynamic>> post(String path, {Object? body, bool auth = true, String? idempotencyKey}) => _send(
    () => dio.post<dynamic>(
      path,
      data: body ?? const <String, dynamic>{},
      options: Options(extra: {'auth': auth}, headers: {'Idempotency-Key': ?idempotencyKey}),
    ),
    auth,
  );

  Future<Map<String, dynamic>> _send(Future<Response<dynamic>> Function() request, bool auth) async {
    try {
      final response = await request();
      final data = response.data;
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } on DioException catch (e) {
      final failure = mapDioException(e);
      // A dead session on an authenticated call is a global event (re-login / deactivated screen).
      if (auth && (failure is Unauthenticated || failure is UserInactive)) {
        onSessionFailure?.call(failure);
      }
      throw failure;
    }
  }
}
