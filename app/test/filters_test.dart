import 'package:flutter_test/flutter_test.dart';
import 'package:whats_due/filters.dart';
import 'package:whats_due/models.dart';

/// Search and the due-date windows.
///
/// The windows are cumulative, which is the whole reason this is worth testing:
/// the failure mode of bands is that widening the filter hides nearer work, and
/// nothing about the UI would show that had happened.
void main() {
  final fixedNow = DateTime(2026, 8, 6, 12);
  setUp(() => clock = () => fixedNow);
  tearDown(() => clock = DateTime.now);

  String inDays(int n) => formatIsoDate(
    DateTime(fixedNow.year, fixedNow.month, fixedNow.day).add(
      Duration(days: n),
    ),
  );

  Assignment at(int days, {String title = 'Item'}) => Assignment(
    id: 'a$days',
    title: title,
    due: days == 9999 ? '' : inDays(days),
  );

  group('due windows are cumulative', () {
    test('a wider window never hides what a narrower one showed', () {
      final items = [at(3), at(10), at(25), at(50), at(120)];

      List<String> within(DueWindow w) =>
          applyFilters(items, window: w).map((a) => a.id).toList();

      expect(within(DueWindow.week), ['a3']);
      expect(within(DueWindow.fortnight), ['a3', 'a10']);
      expect(within(DueWindow.month), ['a3', 'a10', 'a25']);
      expect(within(DueWindow.twoMonths), ['a3', 'a10', 'a25', 'a50']);
    });

    test('later is the tail past two months, not another window', () {
      final items = [at(3), at(50), at(61), at(120)];
      expect(
        applyFilters(items, window: DueWindow.later).map((a) => a.id),
        ['a61', 'a120'],
      );
    });

    test('the boundary day falls inside its window', () {
      expect(matchesWindow(at(7), DueWindow.week), isTrue);
      expect(matchesWindow(at(8), DueWindow.week), isFalse);
      expect(matchesWindow(at(60), DueWindow.twoMonths), isTrue);
      expect(matchesWindow(at(60), DueWindow.later), isFalse);
      expect(matchesWindow(at(61), DueWindow.later), isTrue);
    });
  });

  group('overdue work', () {
    test('passes every window, including the far ones', () {
      // A filter that hides something already late is how it gets forgotten.
      for (final w in DueWindow.values) {
        expect(matchesWindow(at(-3), w), isTrue, reason: '$w');
      }
    });

    test('is still there when a narrow window is chosen', () {
      final items = [at(-5), at(3), at(90)];
      expect(
        applyFilters(items, window: DueWindow.week).map((a) => a.id),
        ['a-5', 'a3'],
      );
    });
  });

  group('undated work', () {
    test('never matches a window', () {
      // "Due within a month" cannot be asked of something with no date, and
      // including it would make the count wrong.
      for (final w in DueWindow.values) {
        expect(matchesWindow(at(9999), w), isFalse, reason: '$w');
      }
    });

    test('is still returned when no window is set', () {
      final items = [at(9999), at(3)];
      expect(applyFilters(items).length, 2);
    });
  });

  group('search', () {
    final items = [
      at(1, title: 'Comparative essay'),
      at(2, title: 'Reaction mechanisms problem set'),
      at(3, title: 'Lab report: titration'),
    ];

    test('matches any part of the title, ignoring case', () {
      expect(applyFilters(items, query: 'ESSAY').single.title,
          'Comparative essay');
      expect(applyFilters(items, query: 'mech').single.title,
          'Reaction mechanisms problem set');
    });

    test('an empty or blank query filters nothing', () {
      expect(applyFilters(items, query: '').length, 3);
      expect(applyFilters(items, query: '   ').length, 3);
    });

    test('surrounding whitespace is ignored', () {
      expect(applyFilters(items, query: '  lab  ').length, 1);
    });

    test('no match returns nothing rather than everything', () {
      expect(applyFilters(items, query: 'zzz'), isEmpty);
    });

    test('does not reach into task text', () {
      // A card whose own name lacks the term would read as the search being
      // broken rather than thorough.
      final withTask = Assignment(
        id: 'x',
        title: 'Comparative essay',
        due: inDays(1),
        tasks: [Task(id: 't', text: 'titration workup')],
      );
      expect(applyFilters([withTask], query: 'titration'), isEmpty);
    });
  });

  group('the two filters combine', () {
    test('both must match', () {
      final items = [
        at(3, title: 'Essay one'),
        at(40, title: 'Essay two'),
        at(3, title: 'Quiz'),
      ];
      final out = applyFilters(items, query: 'essay', window: DueWindow.week);
      expect(out.map((a) => a.title), ['Essay one']);
    });
  });
}
