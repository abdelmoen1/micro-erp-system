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
  Map<String, Object?>? details,
}) => FakeResponse(
  status,
  {
    'message': message,
    'code': code,
    'errors': errors,
    'details': ?details,
    'correlation_id': '01M4TX2BQ5JA9MSMRA877EFV4Y',
  },
  headers: {'x-correlation-id': '01M4TX2BQ5JA9MSMRA877EFV4Y', ...headers},
);

/// [hasAccess] false: the store's trial or subscription has ended (`store.has_access`).
Map<String, dynamic> userJson({int id = 1, String role = 'owner', bool hasAccess = true}) => {
  'id': id,
  'name': 'Demo $role',
  'email': '$role@demo.test',
  'role': role,
  'status': 'active',
  'store_id': 1,
  'deactivated_at': null,
  'store': {
    'id': 1,
    'name': 'Demo Shop',
    'timezone': 'Asia/Gaza',
    'has_access': hasAccess,
    'subscription_state': hasAccess ? 'trial' : 'inactive',
    'trial_ends_at': '2026-10-20T08:00:00.000000Z',
  },
};

FakeResponse loginOk({int id = 1, String role = 'owner', bool hasAccess = true}) => FakeResponse(200, {
  'message': 'تم تسجيل دخولك بنجاح',
  'user': userJson(id: id, role: role, hasAccess: hasAccess),
  'token': '1|test-token',
  'meta': {'currency': 'ILS'},
});

FakeResponse meOk({int id = 1, String role = 'owner', bool hasAccess = true}) => FakeResponse(200, {
  'user': userJson(id: id, role: role, hasAccess: hasAccess),
  'meta': {'currency': 'ILS'},
});

/// `GET /subscription` as SubscriptionAccess::summary renders it.
FakeResponse subscriptionOk({String state = 'inactive', bool hasAccess = false, String? supportWhatsapp = '970599000000'}) =>
    FakeResponse(200, {
      'data': {
        'state': state,
        'has_access': hasAccess,
        'trial_ends_at': '2026-10-20T08:00:00+00:00',
        'subscription_expires_at': null,
        'trial_days_left': 0,
        'support_whatsapp': supportWhatsapp,
      },
    });

/// `GET /dashboard?period=today` as DashboardService renders it (fields the app reads).
FakeResponse dashboardOk({List<Map<String, dynamic>> recentInvoices = const []}) => FakeResponse(200, {
  'data': {
    'period': {'key': 'today', 'timezone': 'Asia/Gaza'},
    'summary': {
      'total_sales': '1250.50',
      'cash_sales': '850.50',
      'credit_sales': '400.00',
      'total_collected_payments': '120.00',
      'total_remaining_debt': '3200.00',
      'customers_count': 9,
      'invoices_count': recentInvoices.length,
    },
    'customers': {'total': 9, 'with_outstanding_debts': 4},
    'sales': {'total': '1250.50', 'cash': '850.50', 'credit': '400.00'},
    'payments': {'total_collected': '120.00', 'count': 2, 'today': '120.00', 'this_month': '900.00'},
    'debts': {'total_debt': '5000.00', 'total_remaining': '3200.00'},
    'recent_invoices': recentInvoices,
  },
});

/// Routes `METHOD /path` to a response (or a queue of responses), records every
/// request, and simulates a dropped connection for [FakeApi.offline] routes.
class FakeApi implements HttpClientAdapter {
  final Map<String, List<FakeResponse>> _routes = {};
  final Set<String> _offline = {};
  final Set<String> _timeouts = {};
  final List<RequestOptions> requests = [];

  void on(String route, FakeResponse response) => _routes[route] = [response];

  void onSequence(String route, List<FakeResponse> responses) => _routes[route] = [...responses];

  void offline(String route) => _offline.add(route);

  /// The request is sent but no answer comes (a receive timeout): it may have reached the server.
  void timeout(String route) => _timeouts.add(route);

  /// The connection comes back for [route].
  void restore(String route) {
    _offline.remove(route);
    _timeouts.remove(route);
  }

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

    if (_timeouts.contains(route)) {
      throw DioException.receiveTimeout(timeout: const Duration(seconds: 30), requestOptions: options);
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
