import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'reminders.dart';
import 'sync/sync_engine.dart';
import 'theme.dart';

/// Outcome of an import, so the UI can report something specific.
class ImportResult {
  const ImportResult.ok({required this.subjects, required this.items})
    : error = null;
  const ImportResult.failed(this.error) : subjects = 0, items = 0;

  final int subjects;
  final int items;
  final String? error;

  bool get succeeded => error == null;
}

/// The single source of truth.
///
/// This mirrors the web app's discipline of `mutate state → save → render` as
/// `mutate → _commit()`, where commit persists and then notifies. There is no
/// diffing and no per-widget state: the whole tree rebuilds from one listenable.
/// The lists are tens of items, so a full rebuild is imperceptible and it
/// removes an entire category of state-sync bugs. Don't introduce a reactive
/// layer to "fix" this.
class AppStore extends ChangeNotifier {
  /// Same key and same JSON shape as the web app, so a file exported from one
  /// imports into the other untouched.
  static const storageKey = 'coursework:v2';
  static const legacyKey = 'coursework:v1';
  static const _remindersKey = 'coursework:reminders';

  SharedPreferences? _prefs;

  /// Set once sync is wired up. Null keeps the app fully functional offline and
  /// local-only, which is what a build with no Firebase project configured does.
  SyncEngine? sync;

  List<Subject> subjects = [];
  List<Assignment> items = [];

  /// Set when a write throws. The web app shows a warning line and keeps
  /// working in memory for the session rather than crashing; so does this.
  bool storageBlocked = false;

  bool remindersEnabled = true;

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      remindersEnabled = _prefs!.getBool(_remindersKey) ?? true;

      final raw = _prefs!.getString(storageKey);
      if (raw != null) {
        _adopt(_decode(raw));
      } else {
        // Migration, following the same shape as the web app's v1 → v2 step:
        // new key, migrate forward, never destroy the old key.
        final legacy = _prefs!.getString(legacyKey);
        if (legacy != null) _adopt(_migrateV1(legacy));
      }
    } catch (e) {
      debugPrint('Store: load failed — $e');
      storageBlocked = true;
    }
    notifyListeners();
    unawaited(_syncReminders());
  }

  // ---------------------------------------------------------------- decoding

  ({List<Subject> subjects, List<Assignment> items}) _decode(String raw) {
    final j = jsonDecode(raw);
    if (j is! Map) throw const FormatException('Expected a JSON object');
    return (
      subjects: (j['subjects'] as List? ?? const [])
          .whereType<Map>()
          .map((s) => Subject.fromJson(s.cast<String, dynamic>()))
          .toList(),
      items: (j['items'] as List? ?? const [])
          .whereType<Map>()
          .map((a) => Assignment.fromJson(a.cast<String, dynamic>()))
          .toList(),
    );
  }

  /// v1 stored a bare array with a free-text `module` field. Group by
  /// case-insensitive module name, mint a subject per distinct name, rewrite
  /// the references.
  ({List<Subject> subjects, List<Assignment> items}) _migrateV1(String raw) {
    final arr = jsonDecode(raw);
    if (arr is! List) throw const FormatException('Expected a JSON array');
    final subjects = <Subject>[];
    final items = <Assignment>[];
    for (final entry in arr.whereType<Map>()) {
      final j = entry.cast<String, dynamic>();
      final name = (j['module'] as String? ?? '').trim();
      String? sid;
      if (name.isNotEmpty) {
        var found = subjects
            .where((s) => s.name.toUpperCase() == name.toUpperCase())
            .firstOrNull;
        if (found == null) {
          found = Subject(
            id: uid(),
            name: name,
            color: kPalette[subjects.length % kPalette.length],
          );
          subjects.add(found);
        }
        sid = found.id;
      }
      items.add(Assignment.fromJson(j)..subjectId = sid);
    }
    return (subjects: subjects, items: items);
  }

  void _adopt(({List<Subject> subjects, List<Assignment> items}) data) {
    subjects = data.subjects;
    items = data.items;
  }

  // ------------------------------------------------------------------ saving

  /// mutate → save → notify. Every mutation below routes through here.
  void _commit() {
    try {
      _prefs?.setString(storageKey, jsonEncode(toJson()));
      storageBlocked = _prefs == null;
    } catch (e) {
      debugPrint('Store: save failed — $e');
      storageBlocked = true;
    }
    notifyListeners();
    unawaited(_syncReminders());
    // Stamps the change and schedules a debounced push. Local storage is
    // already written by this point, so a failed or absent sync never costs the
    // user their edit.
    unawaited(sync?.onLocalChange() ?? Future<void>.value());
  }

  /// Replaces everything with a payload pulled from another device.
  ///
  /// Deliberately does not route through [_commit]: that would mark the state
  /// dirty and immediately push the copy straight back to where it came from.
  void adoptRemote(String payload) {
    try {
      _adopt(_decode(payload));
    } catch (e) {
      debugPrint('Store: could not adopt remote payload — $e');
      return;
    }
    try {
      _prefs?.setString(storageKey, payload);
    } catch (e) {
      debugPrint('Store: save failed — $e');
      storageBlocked = true;
    }
    notifyListeners();
    unawaited(_syncReminders());
  }

  /// Item count for an arbitrary payload, so a conflict can be described
  /// without adopting either side first.
  int countItemsIn(String payload) {
    try {
      return _decode(payload).items.length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _syncReminders() =>
      Reminders.sync(items, subjects, enabled: remindersEnabled);

  Map<String, dynamic> toJson() => {
    'subjects': subjects.map((s) => s.toJson()).toList(),
    'items': items.map((a) => a.toJson()).toList(),
  };

  String exportJson() =>
      const JsonEncoder.withIndent('  ').convert(toJson());

  /// The compact form, byte-identical to what is written to storage. This is
  /// what travels to Firestore, so the remote copy, the local copy and an
  /// exported backup are all the same format.
  String payloadJson() => jsonEncode(toJson());

  // --------------------------------------------------------------- selectors

  /// Unsubmitted items, by due date, undated last.
  List<Assignment> get active {
    final list = items.where((a) => !a.done).toList()
      ..sort((x, y) => sortKey(x).compareTo(sortKey(y)));
    return list;
  }

  List<Assignment> get submitted => items.where((a) => a.done).toList();

  Subject? subjectOf(Assignment a) =>
      subjects.where((s) => s.id == a.subjectId).firstOrNull;

  int countFor(String subjectId) =>
      items.where((a) => a.subjectId == subjectId).length;

  /// The next palette colour, by subject count — matching the web app.
  String get nextColor => kPalette[subjects.length % kPalette.length];

  // --------------------------------------------------------------- mutations

  Subject addSubject(String name, String color) {
    final s = Subject(id: uid(), name: name, color: color);
    subjects.add(s);
    _commit();
    return s;
  }

  void renameSubject(Subject s, String name) {
    if (name.trim().isEmpty) return;
    s.name = name.trim();
    _commit();
  }

  void cycleSubjectColor(Subject s) {
    final i = kPalette.indexOf(s.color);
    s.color = kPalette[(i + 1) % kPalette.length];
    _commit();
  }

  /// Deleting a subject unfiles its assignments rather than cascading a delete.
  /// Losing a subject should never lose work.
  void deleteSubject(Subject s) {
    for (final a in items) {
      if (a.subjectId == s.id) a.subjectId = null;
    }
    subjects.removeWhere((x) => x.id == s.id);
    _commit();
  }

  Assignment addAssignment({
    required String title,
    String? subjectId,
    String due = '',
  }) {
    final a = Assignment(
      id: uid(),
      title: title,
      subjectId: subjectId,
      due: due,
    );
    items.insert(0, a);
    _commit();
    return a;
  }

  /// Editing an assignment's title and due date after creation. The web app
  /// could not do this — it was the most obvious gap in it.
  void editAssignment(Assignment a, {String? title, String? due}) {
    if (title != null && title.trim().isNotEmpty) a.title = title.trim();
    if (due != null) a.due = due;
    _commit();
  }

  void setSubject(Assignment a, String? subjectId) {
    a.subjectId = subjectId;
    _commit();
  }

  void toggleSubmitted(Assignment a) {
    a.done = !a.done;
    _commit();
  }

  void deleteAssignment(Assignment a) {
    items.removeWhere((x) => x.id == a.id);
    _commit();
  }

  void addTask(Assignment a, String text) {
    if (text.trim().isEmpty) return;
    a.tasks.add(Task(id: uid(), text: text.trim()));
    _commit();
  }

  void toggleTask(Assignment a, Task t) {
    t.done = !t.done;
    _commit();
  }

  void deleteTask(Assignment a, Task t) {
    a.tasks.removeWhere((x) => x.id == t.id);
    _commit();
  }

  void clearAll() {
    subjects = [];
    items = [];
    _commit();
  }

  void setRemindersEnabled(bool value) {
    remindersEnabled = value;
    try {
      _prefs?.setBool(_remindersKey, value);
    } catch (e) {
      debugPrint('Store: could not persist reminder setting — $e');
    }
    _commit();
  }

  // ------------------------------------------------------------------ import

  /// Reads a JSON backup, in either the v2 object form or the v1 bare-array
  /// form. With [merge] false the current contents are replaced.
  ///
  /// Merging matches subjects by case-insensitive name so a subject imported
  /// twice does not become two chips, and skips assignments whose id is already
  /// present so importing the same file twice is a no-op.
  ImportResult importJson(String raw, {required bool merge}) {
    final text = raw.trim();
    if (text.isEmpty) return const ImportResult.failed('Nothing to import.');

    ({List<Subject> subjects, List<Assignment> items}) incoming;
    try {
      incoming = text.startsWith('[') ? _migrateV1(text) : _decode(text);
    } on FormatException catch (e) {
      return ImportResult.failed('That is not valid JSON — ${e.message}');
    } catch (e) {
      return ImportResult.failed('Could not read that backup — $e');
    }

    if (incoming.subjects.isEmpty && incoming.items.isEmpty) {
      return const ImportResult.failed(
        'That file parsed, but held no subjects or assignments.',
      );
    }

    if (!merge) {
      subjects = incoming.subjects;
      items = incoming.items;
      _commit();
      return ImportResult.ok(
        subjects: subjects.length,
        items: items.length,
      );
    }

    var addedSubjects = 0;
    var addedItems = 0;
    final remap = <String, String>{};

    for (final s in incoming.subjects) {
      final existing = subjects
          .where((x) => x.name.toUpperCase() == s.name.toUpperCase())
          .firstOrNull;
      if (existing != null) {
        remap[s.id] = existing.id;
      } else {
        final fresh = Subject(id: uid(), name: s.name, color: s.color);
        subjects.add(fresh);
        remap[s.id] = fresh.id;
        addedSubjects++;
      }
    }

    final known = items.map((a) => a.id).toSet();
    for (final a in incoming.items) {
      if (known.contains(a.id)) continue;
      a.subjectId = a.subjectId == null ? null : remap[a.subjectId];
      items.add(a);
      addedItems++;
    }

    _commit();
    return ImportResult.ok(subjects: addedSubjects, items: addedItems);
  }
}
