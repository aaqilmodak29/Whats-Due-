import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bands.dart';
import 'models.dart';
import 'reminders.dart';
import 'updater.dart';
import 'widget_bridge.dart';
import 'theme.dart';

/// Sentinel for "this argument was not supplied", so a genuine null can mean
/// "clear it". See [AppStore.setMarks].
const Object _unchanged = Object();

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
  static const _darkKey = 'coursework:dark';
  static const _onboardedKey = 'coursework:onboarded';

  SharedPreferences? _prefs;

  /// Checks GitHub for a newer build. Null on platforms that cannot
  /// self-install, where the UI simply never offers an update.
  final Updater updater = Updater();

  List<Subject> subjects = [];
  List<Assignment> items = [];

  /// Letter grade bands, empty when the user works in percentages.
  ///
  /// Part of the coursework document rather than a device setting, so a backup
  /// carries them: restoring onto a new phone without them would leave every
  /// grade showing as a bare percentage and every subject goal pointing at a
  /// band that no longer exists.
  List<GradeBand> bands = [];

  bool get usesLetterGrades => bands.isNotEmpty;

  /// Whether the first-run question has been answered, either way. Device
  /// state, not coursework — a restored backup should not re-ask.
  bool onboarded = false;

  /// Set when a write throws. The web app shows a warning line and keeps
  /// working in memory for the session rather than crashing; so does this.
  bool storageBlocked = false;

  bool remindersEnabled = true;

  /// Whether the dark palette is in force.
  ///
  /// Deliberately a plain choice rather than following the system: the app is
  /// read in libraries and lecture theatres where the right answer often is not
  /// the phone's, and one switch is easier to reason about than three states.
  bool darkMode = false;

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      remindersEnabled = _prefs!.getBool(_remindersKey) ?? true;
      darkMode = _prefs!.getBool(_darkKey) ?? false;
      onboarded = _prefs!.getBool(_onboardedKey) ?? false;
      // Applied before the first frame, so the app never opens light and then
      // flips.
      C.palette = darkMode ? Palette.night : Palette.light;

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
    unawaited(WidgetBridge.push(items, subjects));
  }

  // ---------------------------------------------------------------- decoding

  ({List<Subject> subjects, List<Assignment> items, List<GradeBand> bands})
  _decode(String raw) {
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
      // Absent from everything written before letter grading existed, which
      // has to keep loading as "percentages only".
      bands: normaliseBands(
        (j['bands'] as List? ?? const []).whereType<Map>().map(
          (b) => GradeBand.fromJson(b.cast<String, dynamic>()),
        ),
      ),
    );
  }

  /// v1 stored a bare array with a free-text `module` field. Group by
  /// case-insensitive module name, mint a subject per distinct name, rewrite
  /// the references.
  ({List<Subject> subjects, List<Assignment> items, List<GradeBand> bands})
  _migrateV1(String raw) {
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
    return (subjects: subjects, items: items, bands: const <GradeBand>[]);
  }

  void _adopt(
    ({List<Subject> subjects, List<Assignment> items, List<GradeBand> bands})
    data,
  ) {
    subjects = data.subjects;
    items = data.items;
    bands = data.bands;
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
    unawaited(WidgetBridge.push(items, subjects));
  }

  Future<void> _syncReminders() =>
      Reminders.sync(items, subjects, enabled: remindersEnabled);

  Map<String, dynamic> toJson() => {
    'subjects': subjects.map((s) => s.toJson()).toList(),
    'items': items.map((a) => a.toJson()).toList(),
    // Omitted when unused, so a percentages-only document serialises exactly
    // as it did before bands existed.
    if (bands.isNotEmpty) 'bands': bands.map((b) => b.toJson()).toList(),
  };

  String exportJson() => const JsonEncoder.withIndent('  ').convert(toJson());

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
    double? outOf,
  }) {
    final a = Assignment(
      id: uid(),
      title: title,
      subjectId: subjectId,
      due: due,
      outOf: outOf,
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

  /// Sets what the assignment is marked out of, and what was scored.
  ///
  /// Both arguments are double-wrapped options so that "leave this alone" and
  /// "clear this back to untracked" stay distinguishable — passing null for
  /// either directly would collapse them.
  void setMarks(
    Assignment a, {
    Object? earned = _unchanged,
    Object? outOf = _unchanged,
  }) {
    // Coerced rather than cast: the arguments are untyped to make the sentinel
    // work, so an int literal would otherwise fail the cast at runtime.
    if (!identical(earned, _unchanged)) a.earned = (earned as num?)?.toDouble();
    if (!identical(outOf, _unchanged)) a.outOf = (outOf as num?)?.toDouble();
    _commit();
  }

  void setTaskPoints(Task t, double? points) {
    t.points = points;
    _commit();
  }

  void setTaskMinutes(Task t, int? minutes) {
    t.minutes = minutes;
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

  /// Returns the new task, or null when [text] was blank, so a caller that
  /// needs to set marks or an estimate on it does not have to go fishing in the
  /// list for the one it just added.
  Task? addTask(Assignment a, String text) {
    if (text.trim().isEmpty) return null;
    final t = Task(id: uid(), text: text.trim());
    a.tasks.add(t);
    _commit();
    return t;
  }

  void toggleTask(Assignment a, Task t) {
    t.done = !t.done;
    _commit();
  }

  void addSubtask(Task t, String text) {
    if (text.trim().isEmpty) return;
    // A finished task keeps its tick when it gains its first step. `done` is
    // derived from the steps once any exist, so a fresh unticked step would
    // otherwise silently reopen completed work.
    final wasDone = t.done;
    t.subtasks.add(SubTask(id: uid(), text: text.trim(), done: wasDone));
    _commit();
  }

  void toggleSubtask(SubTask s) {
    s.done = !s.done;
    _commit();
  }

  void deleteSubtask(Task t, SubTask s) {
    t.subtasks.removeWhere((x) => x.id == s.id);
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

  /// Replaces the band set. Empty turns letter grading off.
  void setBands(List<GradeBand> value) {
    bands = normaliseBands(value);
    _commit();
  }

  /// The target for a whole subject, as a percentage. Null clears it.
  void setSubjectGoal(Subject s, double? percent) {
    s.goalPercent = percent;
    _commit();
  }

  /// The score being aimed for on one assignment. Null clears it.
  void setGoal(Assignment a, double? goal) {
    a.goal = goal;
    _commit();
  }

  void markOnboarded() {
    onboarded = true;
    try {
      _prefs?.setBool(_onboardedKey, true);
    } catch (e) {
      debugPrint('Store: could not record onboarding — $e');
    }
    notifyListeners();
  }

  void setDarkMode(bool value) {
    darkMode = value;
    C.palette = value ? Palette.night : Palette.light;
    try {
      _prefs?.setBool(_darkKey, value);
    } catch (e) {
      debugPrint('Store: could not persist the theme — $e');
    }
    // Notifies without touching the coursework, so this never counts as an
    // edit to sync or re-arms a reminder.
    notifyListeners();
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

    ({List<Subject> subjects, List<Assignment> items, List<GradeBand> bands})
    incoming;
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
      bands = incoming.bands;
      _commit();
      return ImportResult.ok(subjects: subjects.length, items: items.length);
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
        final fresh = Subject(
          id: uid(),
          name: s.name,
          color: s.color,
          goalPercent: s.goalPercent,
        );
        subjects.add(fresh);
        remap[s.id] = fresh.id;
        addedSubjects++;
      }
    }

    // Bands are a single shared setting, not a per-item thing to merge. Taking
    // the incoming set would silently redefine what every existing grade means,
    // so a merge only adopts them when there are none to overwrite.
    if (bands.isEmpty && incoming.bands.isNotEmpty) bands = incoming.bands;

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
