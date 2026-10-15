import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A canned HTTP response.
class FakeResponse {
  const FakeResponse(this.status, this.body, {this.headers = const {}});

  final int status;
  final Object? body;
  final Map<String, String> headers;
}

/// v1 error envelope exactly as the backend renders it (docs/api/error-codes.md).
FakeResponse envelope(
  int status,
  String code, {
  String message = 'رسالة',
  Map<String, Object> errors = const {},
  Map<String, String> headers = const {},
}) => FakeResponse(
  status,
  {'message': message, 'code': code, 'errors': errors, 'correlation_id': '01M4TX2BQ5JA9MSMRA877EFV4Y'},
  headers: {'x-correlation-id': '01M4TX2BQ5JA9MSMRA877EFV4Y', ...headers},
);

Map<String, dynamic> userJson({int id = 1, String role = 'owner'}) => {
  'id': id,
  'name': 'Demo $role',
  'email': '$role@demo.test',
  'role': role,
  'status': 'active',
  'store_id': 1,
  'deactivated_at': null,
  'store': {'id': 1, 'name': 'Demo Shop', 'timezone': 'Asia/Gaza'},
};

FakeResponse loginOk({int id = 1, String role = 'owner'}) => FakeResponse(200, {
  'message': 'تم تسجيل دخولك بنجاح',
  'user': userJson(id: id, role: role),
  'token': '1|test-token',
  'meta': {'currency': 'ILS'},
});

FakeResponse meOk({int id = 1, String role = 'owner'}) => FakeResponse(200, {
  'user': userJson(id: id, role: role),
  'meta': {'currency': 'ILS'},
});

/// Routes `METHOD /path` to a response (or a queue of responses), records every
/// request, and simulates a dropped connection for [FakeApi.offline] routes.
class FakeApi implements HttpClientAdapter {
  final Map<String, List<FakeResponse>> _routes = {};
  final Set<String> _offline = {};
  final List<RequestOptions> requests = [];

  void on(String route, FakeResponse response) => _routes[route] = [response];

  void onSequence(String route, List<FakeResponse> responses) => _routes[route] = [...responses];

  void offline(String route) => _offline.add(route);

  List<RequestOptions> requestsTo(String route) => requests.where((r) => '${r.method} ${r.path}' == route).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final route = '${options.method} ${options.path}';

    if (_offline.contains(route)) {
      throw DioException.connectionError(requestOptions: options, reason: 'offline (fake)');
    }

    final queue = _routes[route];
    if (queue == null || queue.isEmpty) {
      throw StateError('FakeApi: no response for $route');
    }
    final response = queue.length > 1 ? queue.removeAt(0) : queue.first;

    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        for (final h in response.headers.entries) h.key: [h.value],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
