import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth.dart';
import 'firebase_config.dart';

/// One snapshot of the whole app state, as held remotely.
class RemoteState {
  const RemoteState({
    required this.updatedAt,
    required this.payload,
    required this.deviceId,
  });

  /// Milliseconds since epoch, UTC. The sole input to last-write-wins.
  final int updatedAt;

  /// The `{subjects, items}` JSON, byte-identical to what is stored locally.
  final String payload;

  /// Which device wrote it, so a conflict can say where the other edit came
  /// from instead of just "somewhere else".
  final String deviceId;
}

/// Reads and writes the single Firestore document that holds everything.
///
/// The whole state travels as one JSON string in one field. Firestore could
/// model subjects and items as native nested structures, but a string keeps the
/// remote copy byte-identical to the local one — the same JSON the export button
/// produces — so there is exactly one serialisation format in the project and
/// nothing can drift between them.
class RemoteStore {
  RemoteStore(this._auth);

  final Auth _auth;

  Future<Map<String, String>> _headers() async => {
    'Authorization': 'Bearer ${await _auth.idToken()}',
    'Content-Type': 'application/json',
  };

  /// The remote snapshot, or null when this account has never synced.
  Future<RemoteState?> pull() async {
    final uid = _auth.uid;
    if (uid == null) throw AuthError('Not signed in.');

    late http.Response res;
    try {
      res = await http
          .get(FirebaseConfig.document(uid), headers: await _headers())
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw AuthError('Timed out reaching Firestore.');
    }

    // A user who has never pushed has no document yet. That is a normal
    // first-run state, not an error.
    if (res.statusCode == 404) return null;
    if (res.statusCode == 403) {
      throw AuthError(
        'Firestore refused the read. Check the security rules are published.',
      );
    }
    if (res.statusCode >= 400) {
      throw AuthError('Firestore returned HTTP ${res.statusCode}.');
    }

    final fields =
        (jsonDecode(res.body) as Map)['fields'] as Map<String, dynamic>?;
    if (fields == null) return null;

    return RemoteState(
      updatedAt:
          int.tryParse('${fields['updatedAt']?['integerValue']}') ?? 0,
      payload: fields['payload']?['stringValue'] as String? ?? '',
      deviceId: fields['deviceId']?['stringValue'] as String? ?? 'unknown',
    );
  }

  /// Overwrites the remote document. Returns the timestamp actually written, so
  /// the caller can record it as the new sync baseline.
  Future<int> push({
    required String payload,
    required int updatedAt,
    required String deviceId,
  }) async {
    final uid = _auth.uid;
    if (uid == null) throw AuthError('Not signed in.');

    final body = jsonEncode({
      'fields': {
        'updatedAt': {'integerValue': '$updatedAt'},
        'payload': {'stringValue': payload},
        'deviceId': {'stringValue': deviceId},
      },
    });

    late http.Response res;
    try {
      res = await http
          .patch(
            FirebaseConfig.document(uid),
            headers: await _headers(),
            body: body,
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw AuthError('Timed out reaching Firestore.');
    }

    if (res.statusCode == 403) {
      throw AuthError(
        'Firestore refused the write. Check the security rules are published.',
      );
    }
    if (res.statusCode >= 400) {
      throw AuthError('Firestore returned HTTP ${res.statusCode}.');
    }
    return updatedAt;
  }
}
