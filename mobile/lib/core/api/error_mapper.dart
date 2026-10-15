import 'package:dio/dio.dart';

import 'api_failure.dart';

/// Maps a dio error carrying the v1 error envelope
/// `{message, code, errors, correlation_id}` to a typed [ApiFailure].
ApiFailure mapDioException(DioException e) {
  final response = e.response;

  if (response == null) {
    return NetworkFailure(message: e.message);
  }

  final status = response.statusCode ?? 0;
  final body = response.data;
  final envelope = body is Map ? body : const <String, dynamic>{};
  final code = envelope['code'] as String?;
  final message = envelope['message'] as String?;
  final correlationId = (envelope['correlation_id'] as String?) ?? response.headers.value('x-correlation-id');
  final fieldErrors = _fieldErrors(envelope['errors']);

  switch (code) {
    case 'INVALID_CREDENTIALS':
      return InvalidCredentials(message: message, correlationId: correlationId);
    case 'UNAUTHENTICATED':
    case 'SESSION_EXPIRED':
      return Unauthenticated(message: message, correlationId: correlationId);
    case 'USER_INACTIVE':
      return UserInactive(message: message, correlationId: correlationId);
    case 'STORE_REQUIRED':
      return StoreRequired(message: message, correlationId: correlationId);
    case 'FORBIDDEN':
      return Forbidden(message: message, correlationId: correlationId);
    case 'NOT_FOUND':
      return NotFound(message: message, correlationId: correlationId);
    case 'VALIDATION_FAILED':
      return ValidationFailed(fieldErrors: fieldErrors, message: message, correlationId: correlationId);
    case 'TOO_MANY_REQUESTS':
      return TooManyRequests(
        retryAfter: _retryAfter(response, fieldErrors),
        message: message,
        correlationId: correlationId,
      );
    case 'IDEMPOTENCY_KEY_REQUIRED':
    case 'IDEMPOTENCY_KEY_INVALID':
      return IdempotencyKeyMissingOrInvalid(code: code!, message: message, correlationId: correlationId);
    case 'IDEMPOTENCY_KEY_REUSED':
      return IdempotencyKeyReused(message: message, correlationId: correlationId);
    case 'SERVER_ERROR':
      return ServerError(statusCode: status, message: message, correlationId: correlationId);
  }

  if (status == 422 && code != null) {
    return BusinessRuleViolation(code: code, fieldErrors: fieldErrors, message: message, correlationId: correlationId);
  }
  if (status >= 500) {
    return ServerError(statusCode: status, message: message, correlationId: correlationId);
  }
  // Envelope missing (e.g. a proxy page): fall back on the status alone.
  if (status == 401) return Unauthenticated(message: message, correlationId: correlationId);
  if (status == 429) {
    return TooManyRequests(retryAfter: _retryAfter(response, fieldErrors), message: message);
  }

  return UnexpectedFailure(statusCode: status, code: code, message: message, correlationId: correlationId);
}

Map<String, List<String>> _fieldErrors(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final entry in raw.entries)
      entry.key.toString(): [
        if (entry.value is List)
          for (final m in entry.value as List) m.toString()
        else
          entry.value.toString(),
      ],
  };
}

Duration _retryAfter(Response<dynamic> response, Map<String, List<String>> fieldErrors) {
  final header = int.tryParse(response.headers.value('retry-after') ?? '');
  final body = int.tryParse(fieldErrors['retry_after']?.firstOrNull ?? '');
  final seconds = header ?? body ?? 60;
  return Duration(seconds: seconds < 1 ? 1 : seconds);
}
