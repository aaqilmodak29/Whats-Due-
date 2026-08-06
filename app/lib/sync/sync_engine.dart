import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth.dart';
import 'firebase_config.dart';
import 'remote_store.dart';

enum SyncStatus {
  /// No Firebase project wired up, so sync is not on offer at all.
  disabled,
  signedOut,
  idle,
  syncing,

  /// Both sides changed since the last sync. Waiting for the user to pick.
  conflict,
  error,
}

/// Both sides of an unresolved conflict, so the UI can describe each one
/// concretely rather than asking the user to guess.
class SyncConflict {
  const SyncConflict({
    required this.localUpdatedAt,
    required this.remoteUpdatedAt,
    required this.localItems,
    required this.remoteItems,
    required this.remoteDeviceId,
    required this.remotePayload,
  });

  final DateTime localUpdatedAt;
  final DateTime remoteUpdatedAt;
  final int localItems;
  final int remoteItems;
  final String remoteDeviceId;
  final String remotePayload;
}

/// Whole-document last-write-wins sync.
///
/// The unit of synchronisation is the entire `{subjects, items}` blob, not
/// individual assignments. For one user with tens of items that is a few
/// kilobytes, and it buys a large simplification: a deletion is simply an item
/// missing from a newer document, so there are no tombstones, no per-item
/// timestamps, and no merge algorithm to get subtly wrong.
///
/// The cost, stated honestly: if both devices are edited without a sync in
/// between, one side's edits lose. That case is *detected* rather than silently
/// resolved — [SyncStatus.conflict] hands the decision to the user.
///
/// How it decides, given the local dirty flag and a remote timestamp:
///
///   * remote unchanged since baseline, local dirty  -> push
///   * remote newer than baseline, local clean       -> pull
///   * remote newer than baseline, local dirty       -> conflict
///   * neither                                      -> nothing to do
class SyncEngine extends ChangeNotifier {
  SyncEngine({
    required SharedPreferences prefs,
    required this.readLocal,
    required this.writeLocal,
    required this.countItems,
  }) : _prefs = prefs,
       _auth = Auth(prefs) {
    _remote = RemoteStore(_auth);
    _status = !FirebaseConfig.isConfigured
        ? SyncStatus.disabled
        : _auth.isSignedIn
        ? SyncStatus.idle
        : SyncStatus.signedOut;
  }

  static const _dirtyKey = 'sync:dirty';
  static const _localUpdatedAtKey = 'sync:localUpdatedAt';
  static const _baselineKey = 'sync:baselineRemoteUpdatedAt';
  static const _deviceIdKey = 'sync:deviceId';
  static const _lastSyncKey = 'sync:lastSyncedAt';

  final SharedPreferences _prefs;
  final Auth _auth;
  late final RemoteStore _remote;

  /// Reads the current local state as the JSON string to upload.
  final String Function() readLocal;

  /// Replaces local state with a pulled payload.
  final void Function(String payload) writeLocal;

  /// Item count for a payload, used only to describe a conflict.
  final int Function(String payload) countItems;

  SyncStatus _status = SyncStatus.disabled;
  String? _message;
  SyncConflict? _conflict;
  Timer? _debounce;
  bool _running = false;

  SyncStatus get status => _status;
  String? get message => _message;
  SyncConflict? get conflict => _conflict;
  String? get email => _auth.email;
  bool get isSignedIn => _auth.isSignedIn;
  bool get isConfigured => FirebaseConfig.isConfigured;
  bool get hasPendingChanges => _prefs.getBool(_dirtyKey) ?? false;

  DateTime? get lastSyncedAt {
    final ms = _prefs.getInt(_lastSyncKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// A stable, human-recognisable name for this install, so a conflict can say
  /// which device the other edit came from.
  String get deviceId {
    var id = _prefs.getString(_deviceIdKey);
    if (id == null) {
      final platform = kIsWeb
          ? 'web'
          : defaultTargetPlatform.name.toLowerCase();
      id = '$platform-${Random().nextInt(0xFFFF).toRadixString(16)}';
      _prefs.setString(_deviceIdKey, id);
    }
    return id;
  }

  void _set(SyncStatus status, [String? message]) {
    _status = status;
    _message = message;
    notifyListeners();
  }

  // ------------------------------------------------------------------ account

  Future<bool> signIn(String email, String password, {required bool signUp}) async {
    _set(SyncStatus.syncing);
    try {
      if (signUp) {
        await _auth.signUp(email, password);
      } else {
        await _auth.signIn(email, password);
      }
    } on AuthError catch (e) {
      _set(SyncStatus.signedOut, e.message);
      return false;
    }
    // A device signing in for the first time has local work that the account
    // may not know about, so treat it as pending rather than assuming the
    // remote copy wins.
    if (readLocal().isNotEmpty) await _markDirty(notify: false);
    _set(SyncStatus.idle, 'Signed in as ${_auth.email}');
    await syncNow();
    return true;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _prefs.remove(_baselineKey);
    await _prefs.remove(_lastSyncKey);
    _conflict = null;
    _set(SyncStatus.signedOut, 'Signed out. Your work stays on this device.');
  }

  // -------------------------------------------------------------- change hook

  /// Called by the store after every mutation. Stamps the local change and
  /// schedules a push.
  ///
  /// Debounced, because a mutation happens on every keystroke-completed task add
  /// and every checkbox tick; pushing each one would be dozens of writes for one
  /// sitting.
  Future<void> onLocalChange() async {
    await _markDirty();
    if (_status == SyncStatus.disabled || !_auth.isSignedIn) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () => syncNow());
  }

  Future<void> _markDirty({bool notify = true}) async {
    await _prefs.setBool(_dirtyKey, true);
    await _prefs.setInt(
      _localUpdatedAtKey,
      DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    if (notify) notifyListeners();
  }

  // --------------------------------------------------------------------- sync

  /// Pull, compare, then push or surface a conflict.
  Future<void> syncNow() async {
    if (_status == SyncStatus.disabled || !_auth.isSignedIn) return;
    if (_running) return; // never let two syncs overlap
    _running = true;
    _debounce?.cancel();
    _set(SyncStatus.syncing);

    try {
      final remote = await _remote.pull();
      final baseline = _prefs.getInt(_baselineKey) ?? 0;
      final dirty = _prefs.getBool(_dirtyKey) ?? false;
      final localUpdatedAt =
          _prefs.getInt(_localUpdatedAtKey) ??
          DateTime.now().toUtc().millisecondsSinceEpoch;

      final remoteChanged = remote != null && remote.updatedAt != baseline;

      if (remoteChanged && dirty) {
        // Both sides moved since the last agreement. Whole-document LWW cannot
        // reconcile this without losing something, so ask.
        _conflict = SyncConflict(
          localUpdatedAt: DateTime.fromMillisecondsSinceEpoch(localUpdatedAt),
          remoteUpdatedAt: DateTime.fromMillisecondsSinceEpoch(
            remote.updatedAt,
          ),
          localItems: countItems(readLocal()),
          remoteItems: countItems(remote.payload),
          remoteDeviceId: remote.deviceId,
          remotePayload: remote.payload,
        );
        _set(SyncStatus.conflict);
        return;
      }

      if (remoteChanged) {
        writeLocal(remote.payload);
        await _prefs.setInt(_baselineKey, remote.updatedAt);
        await _prefs.setBool(_dirtyKey, false);
        await _stampSynced();
        _set(SyncStatus.idle, 'Pulled changes from ${remote.deviceId}');
        return;
      }

      if (dirty || remote == null) {
        await _pushLocal(localUpdatedAt);
        _set(SyncStatus.idle, 'Up to date');
        return;
      }

      await _stampSynced();
      _set(SyncStatus.idle, 'Up to date');
    } on AuthError catch (e) {
      _set(SyncStatus.error, e.message);
    } catch (e) {
      _set(SyncStatus.error, 'Sync failed — $e');
    } finally {
      _running = false;
    }
  }

  Future<void> _pushLocal(int updatedAt) async {
    final written = await _remote.push(
      payload: readLocal(),
      updatedAt: updatedAt,
      deviceId: deviceId,
    );
    await _prefs.setInt(_baselineKey, written);
    await _prefs.setBool(_dirtyKey, false);
    await _stampSynced();
  }

  Future<void> _stampSynced() => _prefs.setInt(
    _lastSyncKey,
    DateTime.now().millisecondsSinceEpoch,
  );

  // ----------------------------------------------------------------- conflict

  /// Keep this device's version and overwrite the remote copy.
  Future<void> resolveKeepLocal() async {
    _conflict = null;
    _set(SyncStatus.syncing);
    try {
      await _pushLocal(DateTime.now().toUtc().millisecondsSinceEpoch);
      _set(SyncStatus.idle, 'Kept this device and overwrote the other copy');
    } on AuthError catch (e) {
      _set(SyncStatus.error, e.message);
    }
  }

  /// Discard this device's pending changes and take the remote version.
  Future<void> resolveTakeRemote() async {
    final c = _conflict;
    if (c == null) return;
    _conflict = null;
    writeLocal(c.remotePayload);
    await _prefs.setInt(
      _baselineKey,
      c.remoteUpdatedAt.millisecondsSinceEpoch,
    );
    await _prefs.setBool(_dirtyKey, false);
    await _stampSynced();
    _set(SyncStatus.idle, 'Took the version from ${c.remoteDeviceId}');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
