import 'dart:convert';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_failure.dart';
import '../../../core/storage/key_value_store.dart';
import '../domain/app_user.dart';

/// Talks to the v1 auth endpoints and owns the token in secure storage (US-0205).
class AuthRepository {
  AuthRepository(this._api, this._store);

  static const tokenKey = 'auth.token';
  static const userKey = 'auth.user';

  final ApiClient _api;
  final KeyValueStore _store;

  Future<String?> readToken() => _store.read(tokenKey);

  /// The user cached at the last successful login or restore (for offline launch).
  Future<AppUser?> cachedUser() async {
    final raw = await _store.read(userKey);
    if (raw == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  Future<AppUser> login(String email, String password) async {
    final body = await _api.post('/login', auth: false, body: {'email': email, 'password': password});
    final token = body['token'] as String?;
    if (token == null) {
      throw const UnexpectedFailure(statusCode: 200, message: 'login response without token');
    }
    final user = AppUser.fromJson(body['user'] as Map<String, dynamic>);
    await _store.write(tokenKey, token);
    await _store.write(userKey, jsonEncode(user.toJson()));
    return user;
  }

  /// Validates the stored token with `GET /me`.
  Future<AppUser> me() async {
    final body = await _api.get('/me');
    final user = AppUser.fromJson(body['user'] as Map<String, dynamic>);
    await _store.write(userKey, jsonEncode(user.toJson()));
    return user;
  }

  /// Revokes the token on the server when possible, then always clears local state.
  Future<void> logout() async {
    try {
      if (await readToken() != null) await _api.post('/logout');
    } on ApiFailure {
      // Offline or already revoked: the local token is removed anyway.
    } finally {
      await clearLocalSession();
    }
  }

  Future<void> clearLocalSession() async {
    await _store.delete(tokenKey);
    await _store.delete(userKey);
  }
}
