import 'models.dart';

/// One thing to do now, and the assignment it belongs to.
class PlannedTask {
  const PlannedTask({
    required this.assignment,
    required this.task,
    this.subtask,
  });

  final Assignment assignment;
  final Task task;

  /// The next unfinished step, when the task has been broken down. The task is
  /// still the unit of effort; this just names the concrete next action.
  final SubTask? subtask;

  /// Effort carried by the whole task, null when unestimated.
  int? get minutes => task.minutes;

  String get label => subtask?.text ?? task.text;
}

/// What today looks like.
class DayPlan {
  const DayPlan({
    required this.tasks,
    required this.estimatedMinutes,
    required this.unestimated,
    required this.undated,
  });

  final List<PlannedTask> tasks;

  /// Sum of the estimates that exist. Understates the real load whenever
  /// [unestimated] is above zero, which is why the two are reported separately
  /// rather than folded into one optimistic number.
  final int estimatedMinutes;

  /// Planned tasks carrying no estimate.
  final int unestimated;

  /// Unfinished assignments with no due date. They cannot be paced, so they are
  /// counted and named rather than silently dropped.
  final int undated;

  bool get isEmpty => tasks.isEmpty;
}

/// How much of an assignment is left, and how hard it is pressing.
class _Pressure {
  _Pressure(this.assignment, this.pending);

  final Assignment assignment;
  final List<Task> pending;

  /// Today counts as a day you can work, so a deadline today still leaves one.
  /// Overdue work collapses to the same single day, which puts it at the top
  /// where it belongs.
  int get daysLeft {
    final n = daysUntil(assignment.due);
    if (n == null) return 1;
    return n < 0 ? 1 : n + 1;
  }

  /// Unestimated tasks are paced at [kDefaultEstimate] rather than zero.
  ///
  /// Zero would make them free: they would never advance the budget, so one
  /// assignment could empty its whole list into today. The nominal figure is
  /// used only for pacing — every reported total counts real estimates only,
  /// and the guesses are surfaced as a count instead.
  int get remainingMinutes =>
      pending.fold<int>(0, (sum, t) => sum + (t.minutes ?? kDefaultEstimate));

  /// Minutes per remaining day. The ranking key: an assignment due in ten days
  /// with twenty hours left outranks one due in three days with one hour left.
  double get dailyLoad => remainingMinutes / daysLeft;
}

/// Builds today's plan across every unsubmitted assignment.
///
/// Each assignment gets a share of today equal to its remaining effort spread
/// over the days it has left, and contributes its next tasks until that share
/// is met. Assignments are taken in order of that daily share, so the work that
/// is furthest behind is listed first.
///
/// With no estimates anywhere the shares are all zero and the "at least one"
/// rule takes over, degrading to a next-action-per-assignment list ordered by
/// deadline. That matters: the app has to be useful before any effort has been
/// entered, or nobody ever enters any.
DayPlan todayPlan(List<Assignment> items) {
  final pressures = <_Pressure>[];
  var undated = 0;

  for (final a in items) {
    if (a.done) continue;
    final pending = a.tasks.where((t) => !t.done).toList();
    if (pending.isEmpty) continue;
    if (a.due.isEmpty) {
      undated++;
      continue;
    }
    pressures.add(_Pressure(a, pending));
  }

  pressures.sort((x, y) {
    final byLoad = y.dailyLoad.compareTo(x.dailyLoad);
    if (byLoad != 0) return byLoad;
    return sortKey(x.assignment).compareTo(sortKey(y.assignment));
  });

  final planned = <PlannedTask>[];
  var estimated = 0;
  var unestimated = 0;

  for (final p in pressures) {
    final budget = p.dailyLoad;
    var spent = 0;
    var taken = 0;
    for (final t in p.pending) {
      // Always take the first, so an assignment is never invisible just because
      // its share of today rounds down to nothing.
      if (taken > 0 && spent >= budget) break;
      planned.add(
        PlannedTask(
          assignment: p.assignment,
          task: t,
          subtask: t.subtasks.where((s) => !s.done).firstOrNull,
        ),
      );
      taken++;
      final m = t.minutes;
      if (m == null) {
        unestimated++;
      } else {
        estimated += m;
      }
      spent += m ?? kDefaultEstimate;
    }
  }

  return DayPlan(
    tasks: planned,
    estimatedMinutes: estimated,
    unestimated: unestimated,
    undated: undated,
  );
}

/// `1h 30m`, `45m`, `2h`. Used wherever an estimate is shown.
String formatMinutes(int minutes) {
  if (minutes <= 0) return '0m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

/// The estimate options offered in the UI. Deliberately coarse: a student
/// guessing to the minute is inventing precision, and the ranking only needs
/// the rough shape of the work.
const kEstimateChoices = <int>[15, 30, 60, 120, 180, 300];

/// What an unestimated task is assumed to cost when pacing the day. Never
/// shown, and never added to a reported total.
const kDefaultEstimate = 30;
