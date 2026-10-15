import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/core/api/api_client.dart';
import 'package:smartshop/core/api/api_failure.dart';
import 'package:smartshop/core/api/idempotency_key_store.dart';
import 'package:smartshop/core/storage/key_value_store.dart';

import '../support/fake_api.dart';

void main() {
  late FakeApi api;
  late ApiClient client;
  late List<ApiFailure> sessionFailures;

  setUp(() {
    api = FakeApi();
    sessionFailures = [];
    client = ApiClient(
      baseUrl: 'http://api.test/api/v1',
      readToken: () async => 'tok',
      onSessionFailure: sessionFailures.add,
      adapter: api,
    );
  });

  Future<ApiFailure> failureFor(FakeResponse response, {bool auth = true}) async {
    api.on('GET /x', response);
    try {
      await client.get('/x', auth: auth);
    } on ApiFailure catch (f) {
      return f;
    }
    fail('expected an ApiFailure');
  }

  group('TC-1304-01 every envelope code maps to a typed failure', () {
    final cases = <String, (FakeResponse, Type)>{
      'INVALID_CREDENTIALS': (envelope(401, 'INVALID_CREDENTIALS'), InvalidCredentials),
      'UNAUTHENTICATED': (envelope(401, 'UNAUTHENTICATED'), Unauthenticated),
      'SESSION_EXPIRED': (envelope(419, 'SESSION_EXPIRED'), Unauthenticated),
      'USER_INACTIVE': (envelope(403, 'USER_INACTIVE'), UserInactive),
      'STORE_REQUIRED': (envelope(403, 'STORE_REQUIRED'), StoreRequired),
      'FORBIDDEN': (envelope(403, 'FORBIDDEN'), Forbidden),
      'NOT_FOUND': (envelope(404, 'NOT_FOUND'), NotFound),
      'VALIDATION_FAILED': (envelope(422, 'VALIDATION_FAILED'), ValidationFailed),
      'TOO_MANY_REQUESTS': (envelope(429, 'TOO_MANY_REQUESTS', headers: {'retry-after': '42'}), TooManyRequests),
      'IDEMPOTENCY_KEY_REQUIRED': (envelope(428, 'IDEMPOTENCY_KEY_REQUIRED'), IdempotencyKeyMissingOrInvalid),
      'IDEMPOTENCY_KEY_INVALID': (envelope(422, 'IDEMPOTENCY_KEY_INVALID'), IdempotencyKeyMissingOrInvalid),
      'IDEMPOTENCY_KEY_REUSED': (envelope(409, 'IDEMPOTENCY_KEY_REUSED'), IdempotencyKeyReused),
      'DEBT_ALREADY_PAID': (envelope(422, 'DEBT_ALREADY_PAID'), BusinessRuleViolation),
      'PAYMENT_EXCEEDS_REMAINING': (envelope(422, 'PAYMENT_EXCEEDS_REMAINING'), BusinessRuleViolation),
      'NOTHING_TO_PAY': (envelope(422, 'NOTHING_TO_PAY'), BusinessRuleViolation),
      'PAYMENT_ALREADY_REVERSED': (envelope(422, 'PAYMENT_ALREADY_REVERSED'), BusinessRuleViolation),
      'BUSINESS_RULE_VIOLATION': (envelope(422, 'BUSINESS_RULE_VIOLATION'), BusinessRuleViolation),
      'SERVER_ERROR': (envelope(500, 'SERVER_ERROR'), ServerError),
      'BAD_REQUEST': (envelope(400, 'BAD_REQUEST'), UnexpectedFailure),
      'METHOD_NOT_ALLOWED': (envelope(405, 'METHOD_NOT_ALLOWED'), UnexpectedFailure),
      'CONFLICT': (envelope(409, 'CONFLICT'), UnexpectedFailure),
      'PRECONDITION_REQUIRED': (envelope(428, 'PRECONDITION_REQUIRED'), UnexpectedFailure),
      'HTTP_418': (envelope(418, 'HTTP_418'), UnexpectedFailure),
    };

    for (final MapEntry(key: code, value: (response, type)) in cases.entries) {
      test(code, () async {
        final failure = await failureFor(response);
        expect(failure.runtimeType, type);
        expect(failure.correlationId, '01M4TX2BQ5JA9MSMRA877EFV4Y');
      });
    }
  });

  test('422 field errors and business codes are preserved', () async {
    final validation = await failureFor(
      envelope(
        422,
        'VALIDATION_FAILED',
        errors: {
          'email': ['The email field is required.'],
        },
      ),
    ) as ValidationFailed;
    expect(validation.fieldErrors['email'], ['The email field is required.']);

    final business = await failureFor(
      envelope(
        422,
        'PAYMENT_EXCEEDS_REMAINING',
        errors: {
          'amount': ['too much'],
        },
      ),
    ) as BusinessRuleViolation;
    expect(business.code, 'PAYMENT_EXCEEDS_REMAINING');
    expect(business.fieldErrors['amount'], ['too much']);
  });

  test('429 reads Retry-After from the header, then from errors.retry_after', () async {
    final fromHeader = await failureFor(envelope(429, 'TOO_MANY_REQUESTS', headers: {'retry-after': '42'}));
    expect((fromHeader as TooManyRequests).retryAfter, const Duration(seconds: 42));

    final fromBody = await failureFor(
      envelope(
        429,
        'TOO_MANY_REQUESTS',
        errors: {
          'retry_after': [17],
        },
      ),
    );
    expect((fromBody as TooManyRequests).retryAfter, const Duration(seconds: 17));
  });

  test('no response is a NetworkFailure', () async {
    api.offline('GET /x');
    await expectLater(client.get('/x'), throwsA(isA<NetworkFailure>()));
  });

  test('5xx without an envelope is still a ServerError', () async {
    final failure = await failureFor(const FakeResponse(502, '<html>bad gateway</html>'));
    expect(failure, isA<ServerError>());
  });

  test('short support reference is the last 6 characters of the correlation id', () async {
    final failure = await failureFor(envelope(500, 'SERVER_ERROR'));
    expect(failure.reference, '7EFV4Y');
  });

  test('bearer token is sent on authenticated calls only', () async {
    api.on('GET /x', const FakeResponse(200, {'ok': true}));
    await client.get('/x');
    await client.get('/x', auth: false);
    expect(api.requests[0].headers['Authorization'], 'Bearer tok');
    expect(api.requests[1].headers.containsKey('Authorization'), isFalse);
  });

  test('401 / USER_INACTIVE on authenticated calls raise a session event; on login they do not', () async {
    await failureFor(envelope(401, 'UNAUTHENTICATED'));
    await failureFor(envelope(403, 'USER_INACTIVE'));
    await failureFor(envelope(401, 'INVALID_CREDENTIALS'), auth: false);
    await failureFor(envelope(403, 'FORBIDDEN'));
    expect(sessionFailures.map((f) => f.runtimeType), [Unauthenticated, UserInactive]);
  });

  test('Idempotency-Key header is sent when given', () async {
    api.on('POST /payments', const FakeResponse(201, {'data': {}}));
    await client.post('/payments', body: {'amount': '5.00'}, idempotencyKey: 'k-1');
    expect(api.requests.single.headers['Idempotency-Key'], 'k-1');
  });

  group('TC-1304-02 idempotency keys survive an app restart', () {
    test('the same key is returned after the store is recreated', () async {
      final disk = MemoryKeyValueStore();
      final key = await IdempotencyKeyStore(disk).keyFor('sale-42');

      // "Restart": a new store instance over the same persisted values.
      final afterRestart = IdempotencyKeyStore(MemoryKeyValueStore(disk.values));
      expect(await afterRestart.keyFor('sale-42'), key);
      expect(await afterRestart.pendingOperations(), ['sale-42']);
    });

    test('keys are UUID v4, distinct per operation, and removed on completion', () async {
      final store = IdempotencyKeyStore(MemoryKeyValueStore());
      final a = await store.keyFor('a');
      final b = await store.keyFor('b');
      final uuidV4 = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      expect(a, matches(uuidV4));
      expect(b, isNot(a));

      await store.complete('a');
      expect(await store.pendingOperations(), ['b']);
      expect(await store.keyFor('a'), isNot(a));
    });
  });
}
