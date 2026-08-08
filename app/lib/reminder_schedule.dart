import 'models.dart';

/// When a reminder fires, relative to the deadline.
///
/// Deadlines are assumed to fall at 23:59 on the due date, which is what
/// coursework submission portals almost always use. That assumption is why the
/// last reminder is at 21:00 — three hours before — while every earlier one is
/// at 09:00, so it lands at the start of a working day rather than the end.
///
/// For a deadline of 15 October the six reminders are:
///
///     1 Oct 09:00   two weeks out
///     8 Oct 09:00   one week out
///    12 Oct 09:00   three days out
///    14 Oct 09:00   the day before
///    15 Oct 09:00   the morning of
///    15 Oct 21:00   three hours out
enum Milestone {
  twoWeeks(daysBefore: 14, hour: 9),
  oneWeek(daysBefore: 7, hour: 9),
  threeDays(daysBefore: 3, hour: 9),
  dayBefore(daysBefore: 1, hour: 9),
  morningOf(daysBefore: 0, hour: 9),
  finalHours(daysBefore: 0, hour: 21);

  const Milestone({required this.daysBefore, required this.hour});

  final int daysBefore;
  final int hour;

  /// Used as the headline when a reminder covers a single assignment.
  String get lead => switch (this) {
    Milestone.twoWeeks => 'Two weeks out',
    Milestone.oneWeek => 'One week out',
    Milestone.threeDays => 'Three days out',
    Milestone.dayBefore => 'Due tomorrow',
    Milestone.morningOf => 'Due today',
    Milestone.finalHours => 'Due in three hours',
  };

  /// Used inside a grouped reminder, where the assignment title leads.
  String get shortLead => switch (this) {
    Milestone.twoWeeks => 'due in 2 weeks',
    Milestone.oneWeek => 'due in 1 week',
    Milestone.threeDays => 'due in 3 days',
    Milestone.dayBefore => 'due tomorrow',
    Milestone.morningOf => 'due today',
    Milestone.finalHours => 'due in 3 hours',
  };

  /// Used when every assignment in a group shares this milestone.
  String get collectiveLead => switch (this) {
    Milestone.twoWeeks => 'due in 2 weeks',
    Milestone.oneWeek => 'due in 1 week',
    Milestone.threeDays => 'due in 3 days',
    Milestone.dayBefore => 'due tomorrow',
    Milestone.morningOf => 'due today',
    Milestone.finalHours => 'due tonight',
  };
}

/// The moment [milestone] fires for a deadline on [due].
///
/// Arithmetic goes through [DateTime], which normalises an out-of-range day, so
/// subtracting 14 days from the 3rd of a month rolls correctly into the previous
/// one without any special handling.
DateTime fireTimeFor(DateTime due, Milestone milestone) =>
    DateTime(due.year, due.month, due.day - milestone.daysBefore, milestone.hour);

/// One notification, covering every assignment that comes due at [when].
class ReminderGroup {
  ReminderGroup({required this.when, required this.entries});

  final DateTime when;
  final List<({Assignment assignment, Milestone milestone})> entries;

  bool get isSingle => entries.length == 1;

  String title(Subject? Function(Assignment) subjectOf) {
    if (isSingle) {
      final e = entries.single;
      final subject = subjectOf(e.assignment);
      final tag = subject == null ? '' : ' (${subject.name})';
      return '${e.milestone.lead}: ${e.assignment.title}$tag';
    }
    // When everything in the group hits the same milestone — the common case,
    // since they all fire at 09:00 — say so, rather than the vaguer wording.
    final milestones = entries.map((e) => e.milestone).toSet();
    if (milestones.length == 1) {
      return '${entries.length} assignments ${milestones.single.collectiveLead}';
    }
    return '${entries.length} deadlines need attention';
  }

  String body(Subject? Function(Assignment) subjectOf) {
    if (isSingle) {
      final e = entries.single;
      final pending = e.assignment.tasks.where((t) => !t.done).length;
      final due = 'Due ${longDate(e.assignment.due)}';
      return pending == 0
          ? '$due.'
          : '$due — $pending task${pending == 1 ? '' : 's'} outstanding.';
    }

    // Longest deadline first would bury the urgent ones, so order by how soon
    // each is actually due.
    final sorted = [...entries]
      ..sort((a, b) => a.milestone.daysBefore.compareTo(b.milestone.daysBefore));

    const maxLines = 6;
    final shown = sorted.take(maxLines);
    final lines = shown.map((e) {
      final subject = subjectOf(e.assignment);
      final tag = subject == null ? '' : '${subject.name}: ';
      return '$tag${e.assignment.title} — ${e.milestone.shortLead}';
    }).toList();

    final hidden = sorted.length - lines.length;
    if (hidden > 0) lines.add('and $hidden more');
    return lines.join('\n');
  }
}

/// Every reminder still ahead of [now], grouped so that assignments sharing a
/// moment produce one notification rather than several.
///
/// Grouping matters most in exactly the week it is least wanted: five
/// assignments due the same day would otherwise mean five toasts landing
/// together at 09:00.
///
/// Milestones already in the past are skipped rather than fired late, so adding
/// an assignment due in two days schedules three reminders, not six.
List<ReminderGroup> planReminders(
  List<Assignment> items, {
  required DateTime now,
}) {
  final slots = <DateTime, List<({Assignment assignment, Milestone milestone})>>{};

  for (final assignment in items) {
    if (assignment.done || assignment.due.isEmpty) continue;
    final due = parseIsoDate(assignment.due);
    if (due == null) continue;

    for (final milestone in Milestone.values) {
      final when = fireTimeFor(due, milestone);
      if (!when.isAfter(now)) continue;
      slots
          .putIfAbsent(when, () => [])
          .add((assignment: assignment, milestone: milestone));
    }
  }

  final groups = slots.entries
      .map((e) => ReminderGroup(when: e.key, entries: e.value))
      .toList()
    ..sort((a, b) => a.when.compareTo(b.when));
  return groups;
}
