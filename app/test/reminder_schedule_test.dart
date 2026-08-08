import 'package:flutter_test/flutter_test.dart';
import 'package:whats_due/models.dart';
import 'package:whats_due/reminder_schedule.dart';
import 'package:whats_due/theme.dart';

Assignment due(String iso, {String title = 'Essay', String? subjectId}) =>
    Assignment(id: iso + title, title: title, due: iso, subjectId: subjectId);

/// Formats as `YYYY-MM-DD HH:MM`, so an expected schedule reads at a glance.
String at(DateTime d) =>
    '${formatIsoDate(d)} '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

void main() {
  group('the six milestones', () {
    test('match the worked example: a deadline on 15 October', () {
      // Deadlines are assumed to be 23:59, so the last reminder lands at 21:00
      // and every earlier one at 09:00.
      final plan = planReminders(
        [due('2026-10-15')],
        now: DateTime(2026, 9, 1),
      );

      expect(plan.map((g) => at(g.when)), [
        '2026-10-01 09:00', // two weeks out
        '2026-10-08 09:00', // one week out
        '2026-10-12 09:00', // three days out
        '2026-10-14 09:00', // the day before
        '2026-10-15 09:00', // the morning of
        '2026-10-15 21:00', // roughly three hours out
      ]);
    });

    test('every milestone is either 09:00 or the 21:00 final call', () {
      final plan = planReminders(
        [due('2026-10-15')],
        now: DateTime(2026, 9, 1),
      );
      for (final g in plan) {
        expect(g.when.minute, 0);
        expect(
          g.when.hour,
          anyOf(9, 21),
          reason: 'reminders should land mid-morning or at the 9pm final call',
        );
      }
    });

    test('crossing a month boundary rolls back correctly', () {
      final plan = planReminders(
        [due('2026-01-05')],
        now: DateTime(2025, 12, 1),
      );
      expect(plan.first.when, DateTime(2025, 12, 22, 9));
    });

    test('crossing a leap day is handled by DateTime, not by hand', () {
      final plan = planReminders(
        [due('2028-03-10')],
        now: DateTime(2028, 1, 1),
      );
      // 2028 is a leap year: 10 March minus 14 days is 25 February.
      expect(plan.first.when, DateTime(2028, 2, 25, 9));
    });
  });

  group('what gets skipped', () {
    test('milestones already past are dropped, not fired late', () {
      // Added four days out: the two-week, one-week reminders are gone.
      final plan = planReminders(
        [due('2026-10-15')],
        now: DateTime(2026, 10, 11, 8),
      );
      expect(plan.map((g) => at(g.when)), [
        '2026-10-12 09:00',
        '2026-10-14 09:00',
        '2026-10-15 09:00',
        '2026-10-15 21:00',
      ]);
    });

    test('the morning reminder is skipped once the morning has passed', () {
      final plan = planReminders(
        [due('2026-10-15')],
        now: DateTime(2026, 10, 15, 10),
      );
      expect(plan.map((g) => at(g.when)), ['2026-10-15 21:00']);
    });

    test('an overdue assignment schedules nothing', () {
      expect(
        planReminders([due('2026-10-15')], now: DateTime(2026, 10, 16)),
        isEmpty,
      );
    });

    test('submitted and undated assignments schedule nothing', () {
      final submitted = due('2026-10-15')..done = true;
      final undated = Assignment(id: 'u', title: 'Read chapters');
      expect(
        planReminders([submitted, undated], now: DateTime(2026, 9, 1)),
        isEmpty,
      );
    });
  });

  group('grouping', () {
    Subject? noSubjects(Assignment a) => null;

    test('assignments due the same day share one notification', () {
      final plan = planReminders(
        [
          due('2026-10-15', title: 'Essay'),
          due('2026-10-15', title: 'Lab report'),
          due('2026-10-15', title: 'Problem set'),
        ],
        now: DateTime(2026, 10, 14, 8),
      );

      // Three assignments with three remaining milestones each: three
      // notifications rather than nine.
      expect(plan.length, 3);
      expect(plan.map((g) => at(g.when)), [
        '2026-10-14 09:00',
        '2026-10-15 09:00',
        '2026-10-15 21:00',
      ]);
      expect(plan.every((g) => g.entries.length == 3), isTrue);
      expect(plan.first.title(noSubjects), '3 assignments due tomorrow');
    });

    test('a lone assignment keeps a direct, specific headline', () {
      final plan = planReminders(
        [due('2026-10-15', title: 'Comparative essay')],
        now: DateTime(2026, 10, 14, 8),
      );
      expect(
        plan.first.title(noSubjects),
        'Due tomorrow: Comparative essay',
      );
    });

    test('the subject is named when there is one', () {
      final chemistry = Subject(
        id: 's1',
        name: 'Organic Chemistry',
        color: kPalette.first,
      );
      final plan = planReminders(
        [due('2026-10-15', title: 'Lab report', subjectId: 's1')],
        now: DateTime(2026, 10, 14, 8),
      );
      expect(
        plan.first.title((a) => chemistry),
        'Due tomorrow: Lab report (Organic Chemistry)',
      );
    });

    test('a mixed group says so and lists each with its own urgency', () {
      // 14 Oct 09:00 is the day-before reminder for the 15th and, at the same
      // moment, the three-days-out reminder for the 17th.
      final plan = planReminders(
        [
          due('2026-10-15', title: 'Essay'),
          due('2026-10-17', title: 'Lab report'),
        ],
        now: DateTime(2026, 10, 14, 8),
      );
      final group = plan.firstWhere((g) => at(g.when) == '2026-10-14 09:00');

      expect(group.entries.length, 2);
      expect(group.title(noSubjects), '2 deadlines need attention');
      // Soonest first, so the urgent one is not buried.
      expect(
        group.body(noSubjects),
        'Essay — due tomorrow\nLab report — due in 3 days',
      );
    });

    test('a long group is truncated rather than becoming a wall of text', () {
      final many = [
        for (var i = 0; i < 10; i++) due('2026-10-15', title: 'Task $i'),
      ];
      final plan = planReminders(many, now: DateTime(2026, 10, 14, 8));
      final body = plan.first.body(noSubjects);

      expect(body.split('\n').length, 7); // 6 listed + the "and N more" line
      expect(body, contains('and 4 more'));
    });

    test('outstanding task count rides along on a single reminder', () {
      final a = due('2026-10-15', title: 'Essay')
        ..tasks.addAll([
          Task(id: 't1', text: 'Outline', done: true),
          Task(id: 't2', text: 'Draft', done: false),
          Task(id: 't3', text: 'Proofread', done: false),
        ]);
      final plan = planReminders([a], now: DateTime(2026, 10, 14, 8));
      expect(plan.first.body(noSubjects), contains('2 tasks outstanding'));
    });
  });

  test('a realistic semester stays well inside the OS alarm limits', () {
    // Android caps pending alarms at a few hundred. Grouping is what keeps the
    // count proportional to distinct moments rather than assignments.
    final items = [
      for (var i = 0; i < 30; i++)
        due(formatIsoDate(DateTime(2026, 10, 1).add(Duration(days: i))),
            title: 'Assignment $i'),
    ];
    final plan = planReminders(items, now: DateTime(2026, 9, 1));

    expect(plan.length, lessThan(120));
    // Ordered, so scheduling walks forward in time.
    for (var i = 1; i < plan.length; i++) {
      expect(plan[i].when.isAfter(plan[i - 1].when), isTrue);
    }
  });
}
