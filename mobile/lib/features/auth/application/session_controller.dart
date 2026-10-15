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

/// 403 USER_INACTIVE or STORE_REQUIRED: shown on the login screen until another account signs in.
final class AccountBlocked extends SessionState {
  const AccountBlocked({required this.storeMissing});

  final bool storeMissing;
}

/// Owns the session lifecycle (US-0205): restore on launch, login, logout,
/// and global reactions to 401 / USER_INACTIVE from any API call.
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    Future.microtask(_restore);
    return const SessionRestoring();
  }

  Future<void> _restore() async {
    final repo = ref.read(authRepositoryProvider);
    if (await repo.readToken() == null) {
      state = const SignedOut();
      return;
    }
    try {
      state = SignedIn(await repo.me());
    } on Unauthenticated {
      await repo.clearLocalSession();
      state = const SignedOut(reason: SignedOutReason.sessionExpired);
    } on UserInactive {
      await repo.clearLocalSession();
      state = const AccountBlocked(storeMissing: false);
    } on StoreRequired {
      state = const AccountBlocked(storeMissing: true);
    } on ApiFailure {
      // Server unreachable: start offline with the cached user if there is one.
      final cached = await repo.cachedUser();
      state = cached != null ? SignedIn(cached) : const SignedOut();
    }
  }

  /// Signs in. Field and credential failures are rethrown for the login screen;
  /// account-level failures also move the whole app to the blocked state.
  Future<void> login(String email, String password) async {
    final repo = ref.read(authRepositoryProvider);
    try {
      state = SignedIn(await repo.login(email.trim(), password));
    } on UserInactive {
      state = const AccountBlocked(storeMissing: false);
      rethrow;
    } on StoreRequired {
      await repo.clearLocalSession();
      state = const AccountBlocked(storeMissing: true);
      rethrow;
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const SignedOut();
  }

  /// Called by the API client when an authenticated call returns 401 or USER_INACTIVE.
  Future<void> onSessionFailure(ApiFailure failure) async {
    final current = state;
    await ref.read(authRepositoryProvider).clearLocalSession();
    if (failure is UserInactive) {
      state = const AccountBlocked(storeMissing: false);
    } else if (current is SignedIn) {
      state = SignedOut(reason: SignedOutReason.sessionExpired, previousUserId: current.user.id);
    } else if (current is! SignedOut) {
      state = const SignedOut(reason: SignedOutReason.sessionExpired);
    }
  }
}
