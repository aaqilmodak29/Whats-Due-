import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_config.dart';

/// Thrown for anything the user can act on — bad password, no network, project
/// misconfigured. The message is written to be shown verbatim in the UI.
class AuthError implements Exception {
  AuthError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Firebase Authentication over its REST API, with email and password.
///
/// Email/password rather than Google Sign-In because the account has to work on
/// Windows too, and `google_sign_in` has no Windows implementation. One account
/// signed into on each device is what makes the three copies the same document.
///
/// Only the refresh token is persisted, never the password. It lives in
/// `SharedPreferences`, which is not encrypted at rest — an acceptable trade for
/// a single-user coursework tracker, and the reason the alternative (a native
/// secure-storage plugin) was skipped is the same one that ruled out the
/// FlutterFire plugins: no new native dependencies.
class Auth {
  Auth(this._prefs);

  static const _refreshTokenKey = 'sync:refreshToken';
  static const _emailKey = 'sync:email';
  static const _uidKey = 'sync:uid';

  final SharedPreferences _prefs;

  String? _idToken;
  DateTime? _idTokenExpiry;

  String? get email => _prefs.getString(_emailKey);
  String? get uid => _prefs.getString(_uidKey);
  bool get isSignedIn => _prefs.getString(_refreshTokenKey) != null;

  Future<Map<String, dynamic>> _post(Uri url, Map<String, Object?> body) async {
    late http.Response res;
    try {
      res = await http
          .post(
            url,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw AuthError('Timed out reaching Firebase. Check your connection.');
    } catch (e) {
      throw AuthError('Could not reach Firebase — $e');
    }

    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      var raw = '';
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map) raw = '${error['message'] ?? ''}';
      }
      throw AuthError(_humanise(raw, res.statusCode));
    }
    return (decoded as Map).cast<String, dynamic>();
  }

  /// Firebase's error codes are shouty constants; turn the ones that actually
  /// happen into something readable and leave the rest recognisable.
  String _humanise(String code, int status) => switch (code) {
    'EMAIL_EXISTS' =>
      'That email already has an account. Sign in instead of signing up.',
    'EMAIL_NOT_FOUND' => 'No account for that email. Sign up first.',
    'INVALID_PASSWORD' || 'INVALID_LOGIN_CREDENTIALS' =>
      'Wrong email or password.',
    'INVALID_EMAIL' => 'That does not look like an email address.',
    'WEAK_PASSWORD : Password should be at least 6 characters' =>
      'Password needs to be at least 6 characters.',
    'USER_DISABLED' => 'That account has been disabled.',
    'TOO_MANY_ATTEMPTS_TRY_LATER' =>
      'Too many attempts. Wait a few minutes and try again.',
    'OPERATION_NOT_ALLOWED' =>
      'Email/password sign-in is not enabled on the Firebase project yet.',
    'TOKEN_EXPIRED' || 'USER_NOT_FOUND' =>
      'Session expired. Sign in again.',
    _ => code.isEmpty
        ? 'Firebase returned HTTP $status.'
        : 'Firebase said: $code',
  };

  Future<void> signUp(String email, String password) async {
    final data = await _post(FirebaseConfig.signUp(), {
      'email': email.trim(),
      'password': password,
      'returnSecureToken': true,
    });
    await _store(data);
  }

  Future<void> signIn(String email, String password) async {
    final data = await _post(FirebaseConfig.signIn(), {
      'email': email.trim(),
      'password': password,
      'returnSecureToken': true,
    });
    await _store(data);
  }

  Future<void> _store(Map<String, dynamic> data) async {
    _idToken = data['idToken'] as String?;
    final expiresIn = int.tryParse('${data['expiresIn']}') ?? 3600;
    _idTokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
    await _prefs.setString(_refreshTokenKey, data['refreshToken'] as String);
    await _prefs.setString(_emailKey, data['email'] as String? ?? '');
    await _prefs.setString(_uidKey, data['localId'] as String);
  }

  Future<void> signOut() async {
    _idToken = null;
    _idTokenExpiry = null;
    await _prefs.remove(_refreshTokenKey);
    await _prefs.remove(_emailKey);
    await _prefs.remove(_uidKey);
  }

  /// A usable ID token, refreshing it if it has expired or is about to.
  ///
  /// Firebase ID tokens last an hour, so this refreshes with a minute of margin
  /// rather than waiting for a 401 and retrying.
  Future<String> idToken() async {
    final refreshToken = _prefs.getString(_refreshTokenKey);
    if (refreshToken == null) throw AuthError('Not signed in.');

    final current = _idToken;
    final expiry = _idTokenExpiry;
    if (current != null &&
        expiry != null &&
        DateTime.now().isBefore(expiry.subtract(const Duration(minutes: 1)))) {
      return current;
    }

    final data = await _post(FirebaseConfig.refresh(), {
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
    });

    _idToken = data['id_token'] as String?;
    final expiresIn = int.tryParse('${data['expires_in']}') ?? 3600;
    _idTokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
    // Firebase can hand back a rotated refresh token; keep the newest.
    final rotated = data['refresh_token'] as String?;
    if (rotated != null && rotated != refreshToken) {
      await _prefs.setString(_refreshTokenKey, rotated);
    }
    final token = _idToken;
    if (token == null) throw AuthError('Firebase returned no token.');
    debugPrint('Auth: refreshed ID token');
    return token;
  }
}
