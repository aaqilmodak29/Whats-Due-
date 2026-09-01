import 'dart:math';

import 'package:flutter/material.dart';

import 'theme.dart';

final _rng = Random();

/// Short random id, the same shape and alphabet as the web app's
/// `Math.random().toString(36).slice(2,10)`.
String uid() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return String.fromCharCodes(
    Iterable.generate(8, (_) => chars.codeUnitAt(_rng.nextInt(chars.length))),
  );
}

/// A step within a task. One level only — a subtask cannot be broken down
/// further.
///
/// The depth is capped deliberately. Work nests exactly this far in practice:
/// "Part A — title, abstract, group details" splits into the three things you
/// actually do, and no further. Arbitrary depth would buy a tree widget,
/// indentation that runs out of room on a phone, and no more expressiveness.
class SubTask {
  SubTask({required this.id, required this.text, this.done = false});

  factory SubTask.fromJson(Map<String, dynamic> j) => SubTask(
    id: j['id'] as String? ?? uid(),
    text: j['text'] as String? ?? '',
    done: j['done'] == true,
  );

  final String id;
  String text;
  bool done;

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'done': done};
}

class Task {
  Task({
    required this.id,
    required this.text,
    bool done = false,
    List<SubTask>? subtasks,
    this.points,
    this.minutes,
  }) : _done = done,
       subtasks = subtasks ?? <SubTask>[];

  factory Task.fromJson(Map<String, dynamic> j) => Task(
    id: j['id'] as String? ?? uid(),
    text: j['text'] as String? ?? '',
    done: j['done'] == true,
    // Absent from everything written before subtasks existed, which has to keep
    // loading unchanged.
    subtasks: (j['subtasks'] as List? ?? const [])
        .whereType<Map>()
        .map((s) => SubTask.fromJson(s.cast<String, dynamic>()))
        .toList(),
    points: _num(j['points']),
    minutes: _num(j['minutes'])?.round(),
  );

  final String id;
  String text;
  List<SubTask> subtasks;

  /// Rubric marks for this part, from the spec — the `(5)` in
  /// "Part A — title, abstract, group details (5)". Null when untracked.
  ///
  /// Deliberately kept out of the card's progress bar, which counts tasks. The
  /// bar answers "how much of this assignment is left"; letting marks weight it
  /// would mean two different fractions rendered identically.
  double? points;

  /// Rough effort estimate in minutes. Null when unestimated, which the planner
  /// reports separately rather than silently treating as zero work.
  int? minutes;

  bool _done;

  bool get hasSubtasks => subtasks.isNotEmpty;

  /// Derived from the steps once there are any.
  ///
  /// A parent able to disagree with its own children — ticked while two steps
  /// are outstanding — would make the progress bar lie, so the question is
  /// never asked twice.
  bool get done => hasSubtasks ? subtasks.every((s) => s.done) : _done;

  /// Setting a parent sets every step under it. With no subtasks it is just
  /// the flag.
  set done(bool value) {
    _done = value;
    for (final s in subtasks) {
      s.done = value;
    }
  }

  int get finishedSubtasks => subtasks.where((s) => s.done).length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'done': done,
    // Omitted when empty or unset, so a plain task serialises exactly as before
    // and existing data round-trips unchanged.
    if (subtasks.isNotEmpty)
      'subtasks': subtasks.map((s) => s.toJson()).toList(),
    if (points != null) 'points': points,
    if (minutes != null) 'minutes': minutes,
  };
}

/// Lenient number reader.
///
/// Values reaching here have been through JSON, a hand-edited backup file and
/// another device's copy of the app, so a mark can arrive as `20`, `20.0` or
/// `"20"`. Anything unreadable becomes null — untracked — rather than throwing
/// and taking the whole load with it.
double? _num(Object? v) => switch (v) {
  num n => n.toDouble(),
  String s => double.tryParse(s.trim()),
  _ => null,
};

class Subject {
  Subject({required this.id, required this.name, required this.color});

  factory Subject.fromJson(Map<String, dynamic> j) => Subject(
    id: j['id'] as String? ?? uid(),
    name: j['name'] as String? ?? 'Untitled',
    color: j['color'] as String? ?? kPalette.first,
  );

  final String id;
  String name;

  /// `#RRGGBB`, matching the web app's stored form.
  String color;

  Color get swatch => hexToColor(color);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color};
}

class Assignment {
  Assignment({
    required this.id,
    required this.title,
    this.subjectId,
    this.due = '',
    this.done = false,
    List<Task>? tasks,
    this.weight,
    this.earned,
    this.outOf,
  }) : tasks = tasks ?? <Task>[];

  factory Assignment.fromJson(Map<String, dynamic> j) => Assignment(
    id: j['id'] as String? ?? uid(),
    title: j['title'] as String? ?? '',
    subjectId: j['subjectId'] as String?,
    due: j['due'] as String? ?? '',
    done: j['done'] == true,
    tasks: (j['tasks'] as List? ?? const [])
        .whereType<Map>()
        .map((t) => Task.fromJson(t.cast<String, dynamic>()))
        .toList(),
    weight: _num(j['weight']),
    earned: _num(j['earned']),
    outOf: _num(j['outOf']),
  );

  final String id;
  String title;

  /// A reference, never an embedded copy, so renaming or recolouring a subject
  /// updates every card at once.
  String? subjectId;

  /// `YYYY-MM-DD`, or empty when unset.
  ///
  /// Deliberately a plain string, never a [DateTime]. Parsing `"2026-08-19"`
  /// as a date yields UTC midnight, which shifts the day backwards for anyone
  /// behind UTC — visible year-round in Melbourne (UTC+10/11). Every
  /// comparison below is either a string sort or explicit component parsing.
  /// Do not "simplify" this into date parsing.
  String due;

  /// `true` means submitted.
  bool done;

  List<Task> tasks;

  /// Share of the unit's final grade, as a percentage. Null when untracked.
  ///
  /// A percentage of the *unit*, not of this assignment — 20 means "this is
  /// worth 20% of the subject". [earned] and [outOf] are the raw marks it was
  /// returned with, which is how results actually come back (34 out of 40), and
  /// the two scales are reconciled once in [scored].
  double? weight;

  double? earned;
  double? outOf;

  int get finishedTasks => tasks.where((t) => t.done).length;

  /// Total rubric marks across the tasks, when any carry them.
  double? get taskPoints {
    final marked = tasks.where((t) => t.points != null);
    if (marked.isEmpty) return null;
    return marked.fold<double>(0, (sum, t) => sum + t.points!);
  }

  double? get finishedPoints {
    final marked = tasks.where((t) => t.points != null);
    if (marked.isEmpty) return null;
    return marked
        .where((t) => t.done)
        .fold<double>(0, (sum, t) => sum + t.points!);
  }

  /// Whether a result has been recorded. A zero mark is a real result, so this
  /// tests for presence rather than truthiness.
  bool get graded => earned != null && outOf != null && outOf! > 0;

  /// Fraction of the available marks achieved, 0..1. Null until graded.
  double? get scored => graded ? earned! / outOf! : null;

  /// Percentage points of the final unit grade this assignment has actually
  /// secured. Null unless both weighted and graded.
  double? get contribution =>
      (weight == null || !graded) ? null : weight! * scored!;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subjectId': subjectId,
    'due': due,
    'done': done,
    'tasks': tasks.map((t) => t.toJson()).toList(),
    if (weight != null) 'weight': weight,
    if (earned != null) 'earned': earned,
    if (outOf != null) 'outOf': outOf,
  };
}

/// Undated items sort last, via the same sentinel the web app uses.
const _undatedSentinel = '9999-99-99';

String sortKey(Assignment a) => a.due.isEmpty ? _undatedSentinel : a.due;

/// The clock everything date-related reads from.
///
/// A seam purely for tests. Golden snapshots render real dates ("SUN 9 AUG
/// 2026"), so with a live clock they compare against yesterday's pixels and
/// fail every day — turning the one check on the design into noise. Tests pin
/// this; nothing in the app ever reassigns it.
DateTime Function() clock = DateTime.now;

/// Local start-of-today.
DateTime midnight() {
  final n = clock();
  return DateTime(n.year, n.month, n.day);
}

/// Local midnight on [iso], or null when [iso] is not a `YYYY-MM-DD` date.
DateTime? parseIsoDate(String iso) {
  final p = iso.split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  final d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  return DateTime(y, m, d);
}

String formatIsoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Whole days from today until [iso]. Negative when overdue, null when undated.
///
/// Rounds rather than truncating, because a day either side of a daylight-saving
/// boundary is 23 or 25 hours long and truncation would report the wrong day.
int? daysUntil(String iso) {
  final d = parseIsoDate(iso);
  if (d == null) return null;
  return (d.difference(midnight()).inMilliseconds / 86400000).round();
}

String countdown(int? n) {
  if (n == null) return 'NO DATE';
  if (n < -1) return '${-n} DAYS LATE';
  if (n == -1) return '1 DAY LATE';
  if (n == 0) return 'DUE TODAY';
  if (n == 1) return 'TOMORROW';
  return '$n DAYS';
}

/// Days-until to colour. **The only place urgency thresholds live.**
Color urgency(int? n) {
  if (n == null) return C.muted;
  if (n <= 2) return C.red;
  if (n <= 6) return C.ink;
  return C.muted;
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Human-readable date, day-month-year. Hand-formatted rather than via `intl`
/// so the dependency list stays short and the output stays predictable.
String longDate(String iso) {
  final d = parseIsoDate(iso);
  if (d == null) return 'No deadline set';
  return '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]} ${d.year}';
}
