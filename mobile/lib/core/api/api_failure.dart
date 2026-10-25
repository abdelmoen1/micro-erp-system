/// Typed failures for every code in the frozen v1 contract
/// (docs/api/error-codes.md). The UI switches on the type, never on message text.
sealed class ApiFailure implements Exception {
  const ApiFailure({this.message, this.correlationId});

  /// Server message (Arabic for application codes). May be null for network failures.
  final String? message;
  final String? correlationId;

  /// Short support reference: the last 6 characters of the correlation id.
  String? get reference {
    final id = correlationId;
    if (id == null || id.isEmpty) return null;
    return id.length <= 6 ? id : id.substring(id.length - 6);
  }

  @override
  String toString() => '$runtimeType(${message ?? ''})';
}

/// 401 INVALID_CREDENTIALS on POST /login.
final class InvalidCredentials extends ApiFailure {
  const InvalidCredentials({super.message, super.correlationId});
}

/// 401 UNAUTHENTICATED: missing, revoked or expired token.
final class Unauthenticated extends ApiFailure {
  const Unauthenticated({super.message, super.correlationId});
}

/// 403 USER_INACTIVE: the account was deactivated (token already revoked).
final class UserInactive extends ApiFailure {
  const UserInactive({super.message, super.correlationId});
}

/// 403 STORE_REQUIRED: the user is not linked to a store.
final class StoreRequired extends ApiFailure {
  const StoreRequired({super.message, super.correlationId});
}

/// 403 STORE_SUSPENDED: the platform admin suspended the store (sign-in and every store call).
final class StoreSuspended extends ApiFailure {
  const StoreSuspended({super.message, super.correlationId});
}

/// 403 SUBSCRIPTION_EXPIRED: the trial or paid subscription has ended. The session stays valid;
/// only business calls are refused until the platform admin activates the subscription.
final class SubscriptionExpired extends ApiFailure {
  const SubscriptionExpired({this.supportWhatsapp, super.message, super.correlationId});

  /// Digits of the support WhatsApp number from the server (null when not configured).
  final String? supportWhatsapp;
}

/// 403 FORBIDDEN: the role may not perform this action.
final class Forbidden extends ApiFailure {
  const Forbidden({super.message, super.correlationId});
}

/// 404 NOT_FOUND (also returned for records of another store).
final class NotFound extends ApiFailure {
  const NotFound({super.message, super.correlationId});
}

/// 422 VALIDATION_FAILED with per-field messages.
final class ValidationFailed extends ApiFailure {
  const ValidationFailed({required this.fieldErrors, super.message, super.correlationId});

  final Map<String, List<String>> fieldErrors;
}

/// 429 TOO_MANY_REQUESTS; [retryAfter] comes from the Retry-After header.
final class TooManyRequests extends ApiFailure {
  const TooManyRequests({required this.retryAfter, super.message, super.correlationId});

  final Duration retryAfter;
}

/// 428 IDEMPOTENCY_KEY_REQUIRED / 422 IDEMPOTENCY_KEY_INVALID: a client bug.
final class IdempotencyKeyMissingOrInvalid extends ApiFailure {
  const IdempotencyKeyMissingOrInvalid({required this.code, super.message, super.correlationId});

  final String code;
}

/// 409 IDEMPOTENCY_KEY_REUSED: same key sent with a different body.
final class IdempotencyKeyReused extends ApiFailure {
  const IdempotencyKeyReused({super.message, super.correlationId});
}

/// 422 with a business code (DEBT_ALREADY_PAID, PAYMENT_EXCEEDS_REMAINING, CREDIT_LIMIT_EXCEEDED, ...).
final class BusinessRuleViolation extends ApiFailure {
  const BusinessRuleViolation({
    required this.code,
    this.fieldErrors = const {},
    this.details = const {},
    super.message,
    super.correlationId,
  });

  final String code;
  final Map<String, List<String>> fieldErrors;

  /// The envelope's optional `details` (credit-limit codes: credit_limit, outstanding, new_debt,
  /// balance_after, can_override). Empty for codes without it.
  final Map<String, Object?> details;
}

/// 5xx SERVER_ERROR: show a generic message with [reference].
final class ServerError extends ApiFailure {
  const ServerError({required this.statusCode, super.message, super.correlationId});

  final int statusCode;
}

/// No response: offline, DNS failure, refused connection or timeout.
final class NetworkFailure extends ApiFailure {
  const NetworkFailure({super.message, this.maybeDelivered = false});

  /// A timeout after sending: the server may have applied the write. Retry with the same key.
  final bool maybeDelivered;
}

/// Any other status or code (`BAD_REQUEST`, `METHOD_NOT_ALLOWED`, `HTTP_<status>`, ...).
final class UnexpectedFailure extends ApiFailure {
  const UnexpectedFailure({required this.statusCode, this.code, super.message, super.correlationId});

  final int? statusCode;
  final String? code;
}
