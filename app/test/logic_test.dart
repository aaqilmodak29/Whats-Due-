import 'package:flutter_test/flutter_test.dart';
import 'package:whats_due/ics.dart';
import 'package:whats_due/models.dart';
import 'package:whats_due/theme.dart';

void main() {
  group('dates', () {
    test('a due date never shifts a day, whatever the local UTC offset', () {
      // The whole reason `due` is a string. Parsing "2026-08-19" as a date
      // yields UTC midnight, which reads as the 18th anywhere behind UTC.
      final parsed = parseIsoDate('2026-08-19')!;
      expect(parsed.year, 2026);
      expect(parsed.month, 8);
      expect(parsed.day, 19);
      expect(parsed.isUtc, isFalse);
      expect(formatIsoDate(parsed), '2026-08-19');
    });

    test('daysUntil is zero for today and negative when overdue', () {
      final today = formatIsoDate(midnight());
      final yesterday = formatIsoDate(
        midnight().subtract(const Duration(days: 1)),
      );
      final nextWeek = formatIsoDate(midnight().add(const Duration(days: 7)));

      expect(daysUntil(today), 0);
      expect(daysUntil(yesterday), -1);
      expect(daysUntil(nextWeek), 7);
      expect(daysUntil(''), isNull);
      expect(daysUntil('not-a-date'), isNull);
    });

    test('daysUntil rounds, so a DST boundary cannot cost a day', () {
      // Melbourne switches at 2am on the first Sunday in October: that day is
      // 23 hours long, and truncating the difference would report 0 days.
      for (var offset = 1; offset <= 400; offset++) {
        final target = midnight().add(Duration(days: offset));
        expect(
          daysUntil(formatIsoDate(target)),
          offset,
          reason: 'offset $offset resolved wrongly',
        );
      }
    });

    test('countdown wording matches the web app', () {
      expect(countdown(null), 'NO DATE');
      expect(countdown(-3), '3 DAYS LATE');
      expect(countdown(-1), '1 DAY LATE');
      expect(countdown(0), 'DUE TODAY');
      expect(countdown(1), 'TOMORROW');
      expect(countdown(5), '5 DAYS');
    });

    test('urgency thresholds live in exactly one place', () {
      expect(urgency(null), C.muted);
      expect(urgency(-1), C.red);
      expect(urgency(2), C.red);
      expect(urgency(3), C.ink);
      expect(urgency(6), C.ink);
      expect(urgency(7), C.muted);
    });

    test('undated assignments sort last', () {
      final items = [
        Assignment(id: 'a', title: 'undated'),
        Assignment(id: 'b', title: 'later', due: '2026-12-01'),
        Assignment(id: 'c', title: 'sooner', due: '2026-08-19'),
      ]..sort((x, y) => sortKey(x).compareTo(sortKey(y)));

      expect(items.map((a) => a.title), ['sooner', 'later', 'undated']);
    });
  });

  group('colours', () {
    test('hex strings round-trip, so exported JSON stays web-compatible', () {
      for (final hex in kPalette) {
        expect(colorToHex(hexToColor(hex)), hex);
      }
    });

    test('an unparseable colour degrades instead of throwing', () {
      expect(hexToColor('not-a-colour'), C.muted);
    });
  });

  group('ics', () {
    test('escapes commas, semicolons, backslashes and newlines', () {
      expect(icsEscape('a,b'), r'a\,b');
      expect(icsEscape('a;b'), r'a\;b');
      expect(icsEscape(r'a\b'), r'a\\b');
      expect(icsEscape('a\nb'), r'a\nb');
    });

    test('DTSTART is floating local time — no TZID and no trailing Z', () {
      final ics = buildIcs(
        Assignment(id: 'x1', title: 'Essay', due: '2026-08-19'),
        null,
      );
      expect(ics, contains('DTSTART:20260819T090000'));
      expect(ics, isNot(contains('TZID')));
      expect(ics, isNot(contains('DTSTART:20260819T090000Z')));
    });

    test('carries the three alarms', () {
      final ics = buildIcs(
        Assignment(id: 'x2', title: 'Essay', due: '2026-08-19'),
        null,
      );
      expect(ics, contains('TRIGGER:-P7D'));
      expect(ics, contains('TRIGGER:-P2D'));
      expect(ics, contains('TRIGGER:-PT15H'));
    });

    test('lists outstanding tasks and names the subject', () {
      final a = Assignment(
        id: 'x3',
        title: 'Comparative essay',
        due: '2026-08-19',
        subjectId: 's1',
        tasks: [
          Task(id: 't1', text: 'Draft outline'),
          Task(id: 't2', text: 'Proofread', done: true),
        ],
      );
      final ics = buildIcs(
        a,
        Subject(id: 's1', name: 'Organic Chemistry', color: kPalette.first),
      );
      expect(ics, contains('Organic Chemistry'));
      expect(ics, contains('Draft outline'));
      expect(ics, isNot(contains('Proofread')));
    });

    test('filenames stay safe and bounded', () {
      expect(
        icsFileName(Assignment(id: 'x4', title: 'Essay #2: Ethics & Law')),
        'essay-2-ethics-law',
      );
      expect(icsFileName(Assignment(id: 'x5', title: '!!!')), 'assignment');
      expect(
        icsFileName(Assignment(id: 'x6', title: 'a' * 80)).length,
        lessThanOrEqualTo(40),
      );
    });
  });

  group('serialisation', () {
    test('an assignment round-trips through JSON', () {
      final a = Assignment(
        id: 'a1',
        title: 'Essay',
        subjectId: 's1',
        due: '2026-08-19',
        done: true,
        tasks: [Task(id: 't1', text: 'Outline', done: true)],
      );
      final back = Assignment.fromJson(a.toJson());
      expect(back.id, a.id);
      expect(back.title, a.title);
      expect(back.subjectId, a.subjectId);
      expect(back.due, a.due);
      expect(back.done, isTrue);
      expect(back.tasks.single.text, 'Outline');
      expect(back.tasks.single.done, isTrue);
    });

    test('missing and malformed fields fall back rather than throwing', () {
      final a = Assignment.fromJson({'title': 'Bare'});
      expect(a.title, 'Bare');
      expect(a.id, isNotEmpty);
      expect(a.due, '');
      expect(a.done, isFalse);
      expect(a.tasks, isEmpty);
      expect(a.subjectId, isNull);
    });

    test('ids are unique across a realistic number of draws', () {
      final seen = {for (var i = 0; i < 5000; i++) uid()};
      expect(seen.length, 5000);
    });
  });
}
