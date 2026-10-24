import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/providers.dart';
import '../domain/app_user.dart';

/// Why the user is on the login screen (drives the message shown there).
enum SignedOutReason { none, sessionExpired }

sealed class SessionState {
  const SessionState();
}

/// Launch: a stored token is being checked with GET /me.
final class SessionRestoring extends SessionState {
  const SessionRestoring();
}

final class SignedOut extends SessionState {
  const SignedOut({this.reason = SignedOutReason.none, this.previousUserId});

  final SignedOutReason reason;

  /// Set when the session expired mid-use, so the same user can return to where they were.
  final int? previousUserId;
}

final class SignedIn extends SessionState {
  const SignedIn(this.user);

  final AppUser user;
}

/// The store's trial or paid subscription has ended. The session is kept (the token still works
/// for /me, /subscription and /logout); every business call is refused by the server until the
/// platform admin activates the subscription. Only the renewal screen is shown.
final class SubscriptionLapsed extends SessionState {
  const SubscriptionLapsed(this.user, {this.supportWhatsapp});

  final AppUser user;

  /// From the 403 details when known; the renewal screen also reads it from GET /subscription.
  final String? supportWhatsapp;
}

/// 403 USER_INACTIVE, STORE_REQUIRED or STORE_SUSPENDED: shown on the login screen until another
/// account signs in.
final class AccountBlocked extends SessionState {
  const AccountBlocked({required this.storeMissing, this.storeSuspended = false});

  final bool storeMissing;

  /// The platform admin suspended the store (not the user's own account).
  final bool storeSuspended;
}

/// Owns the session lifecycle (US-0205): restore on launch, login, registration, logout, and global
/// reactions to 401 / USER_INACTIVE / STORE_SUSPENDED / SUBSCRIPTION_EXPIRED from any API call.
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    Future.microtask(_restore);
    return const SessionRestoring();
  }

  /// SignedIn, or the renewal screen when the server says the store has no access.
  SessionState _signedIn(AppUser user) => user.hasAccess ? SignedIn(user) : SubscriptionLapsed(user);

  Future<void> _restore() async {
    final repo = ref.read(authRepositoryProvider);
    if (await repo.readToken() == null) {
      state = const SignedOut();
      return;
    }
    try {
      state = _signedIn(await repo.me());
    } on Unauthenticated {
      await repo.clearLocalSession();
      state = const SignedOut(reason: SignedOutReason.sessionExpired);
    } on UserInactive {
      await repo.clearLocalSession();
      state = const AccountBlocked(storeMissing: false);
    } on StoreRequired {
      state = const AccountBlocked(storeMissing: true);
    } on StoreSuspended {
      await repo.clearLocalSession();
      state = const AccountBlocked(storeMissing: false, storeSuspended: true);
    } on ApiFailure {
      // Server unreachable: start offline with the cached user if there is one.
      final cached = await repo.cachedUser();
      state = cached != null ? _signedIn(cached) : const SignedOut();
    }
  }

  /// Signs in. Field and credential failures are rethrown for the login screen;
  /// account-level failures also move the whole app to the blocked state.
  Future<void> login(String email, String password) async {
    final repo = ref.read(authRepositoryProvider);
    try {
      state = _signedIn(await repo.login(email.trim(), password));
    } on UserInactive {
      state = const AccountBlocked(storeMissing: false);
      rethrow;
    } on StoreRequired {
      await repo.clearLocalSession();
      state = const AccountBlocked(storeMissing: true);
      rethrow;
    } on StoreSuspended {
      await repo.clearLocalSession();
      state = const AccountBlocked(storeMissing: false, storeSuspended: true);
      rethrow;
    }
  }

  /// Creates the store and its owner (the server starts the free trial), then signs in.
  /// Validation, throttling and network failures are rethrown for the registration screen.
  Future<void> register(Map<String, String> fields) async {
    state = _signedIn(await ref.read(authRepositoryProvider).register(fields));
  }

  /// "Check again" on the renewal screen: back to the app once the subscription is active.
  /// Returns the server's current view of the subscription.
  Future<SubscriptionSummary> recheckSubscription() async {
    final repo = ref.read(authRepositoryProvider);
    final summary = await repo.subscription();
    if (summary.hasAccess) state = SignedIn(await repo.me());
    return summary;
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const SignedOut();
  }

  /// Called by the API client when an authenticated call returns 401, USER_INACTIVE,
  /// STORE_SUSPENDED or SUBSCRIPTION_EXPIRED.
  Future<void> onSessionFailure(ApiFailure failure) async {
    final current = state;
    if (failure is SubscriptionExpired) {
      // The session stays: only the renewal screen until the subscription is activated.
      final user = switch (current) {
        SignedIn(:final user) => user,
        SubscriptionLapsed(:final user) => user,
        _ => null,
      };
      if (user != null) state = SubscriptionLapsed(user, supportWhatsapp: failure.supportWhatsapp);
      return;
    }
    await ref.read(authRepositoryProvider).clearLocalSession();
    if (failure is UserInactive) {
      state = const AccountBlocked(storeMissing: false);
    } else if (failure is StoreSuspended) {
      state = const AccountBlocked(storeMissing: false, storeSuspended: true);
    } else if (current is SignedIn) {
      state = SignedOut(reason: SignedOutReason.sessionExpired, previousUserId: current.user.id);
    } else if (current is! SignedOut) {
      state = const SignedOut(reason: SignedOutReason.sessionExpired);
    }
  }
}
