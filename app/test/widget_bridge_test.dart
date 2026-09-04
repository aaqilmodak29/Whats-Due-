import 'package:flutter_test/flutter_test.dart';
import 'package:whats_due/models.dart';
import 'package:whats_due/theme.dart';
import 'package:whats_due/widget_bridge.dart';

/// The payload handed to the Android widget.
///
/// The Kotlin side is deliberately dumb — it renders strings, paints one colour
/// and hides empty rows — so everything worth testing about the widget is
/// testable here, on the Dart side, without a device.
void main() {
  final fixedNow = DateTime(2026, 8, 6, 12);
  setUp(() => clock = () => fixedNow);
  tearDown(() => clock = DateTime.now);

  String inDays(int n) => formatIsoDate(
    DateTime(fixedNow.year, fixedNow.month, fixedNow.day).add(
      Duration(days: n),
    ),
  );

  final subjects = [
    Subject(id: 's1', name: 'Organic Chemistry', color: kPalette.first),
  ];

  Assignment work(
    String id,
    int dueInDays, {
    bool done = false,
    String? subjectId = 's1',
    List<Task>? tasks,
    String? title,
  }) => Assignment(
    id: id,
    title: title ?? 'Item $id',
    subjectId: subjectId,
    due: dueInDays == 9999 ? '' : inDays(dueInDays),
    done: done,
    tasks: tasks,
  );

  group('what the week contains', () {
    test('takes only the next seven days', () {
      final soon = WidgetBridge.dueSoon([
        work('a', 3),
        work('b', 7),
        work('c', 8),
        work('d', 30),
      ]);
      expect(soon.map((a) => a.id), ['a', 'b']);
    });

    test('keeps overdue work rather than dropping it on the day it goes late', () {
      // Not "due in the next week" strictly, but it is the most urgent thing
      // there is, and vanishing from the widget the moment it goes late would
      // be the opposite of useful.
      final soon = WidgetBridge.dueSoon([work('late', -4), work('soon', 2)]);
      expect(soon.map((a) => a.id), ['late', 'soon']);
    });

    test('leaves out submitted and undated work', () {
      final soon = WidgetBridge.dueSoon([
        work('done', 2, done: true),
        work('undated', 9999),
        work('real', 2),
      ]);
      expect(soon.map((a) => a.id), ['real']);
    });

    test('sorts soonest first', () {
      final soon = WidgetBridge.dueSoon([work('c', 6), work('a', 1), work('b', 3)]);
      expect(soon.map((a) => a.id), ['a', 'b', 'c']);
    });
  });

  group('the payload', () {
    test('carries what the Assignments card shows, in the same terms', () {
      final payload = WidgetBridge.buildPayload([
        work(
          'a',
          2,
          title: 'Reaction mechanisms',
          tasks: [
            Task(id: 't1', text: 'Q1', done: true),
            Task(id: 't2', text: 'Q2'),
          ],
        ),
      ], subjects);

      expect(payload['wd_t0_subject'], 'ORGANIC CHEMISTRY');
      expect(payload['wd_t0_title'], 'Reaction mechanisms');
      expect(payload['wd_t0_count'], '2 DAYS');
      expect(payload['wd_t0_progress'], '1/2');
    });

    test('says so when an assignment has no tasks', () {
      final payload = WidgetBridge.buildPayload([work('a', 2)], subjects);
      expect(payload['wd_t0_progress'], 'NO TASKS');
    });

    test('falls back to Unfiled rather than an empty subject', () {
      final payload = WidgetBridge.buildPayload([
        work('a', 2, subjectId: null),
      ], subjects);
      expect(payload['wd_t0_subject'], 'UNFILED');
    });

    test('carries the urgency colour the card would paint', () {
      final payload = WidgetBridge.buildPayload([
        work('late', -1),
        work('soon', 1),
        work('later', 10),
      ], subjects);

      // Overdue and imminent are red; the third is outside the week entirely.
      expect(payload['wd_t0_spine'], '${C.red.toARGB32()}');
      expect(payload['wd_t1_spine'], '${C.red.toARGB32()}');
      expect(payload['wd_t2_title'], '');
    });

    test('fills every row slot, so stale text cannot survive a refresh', () {
      final payload = WidgetBridge.buildPayload([work('a', 2)], subjects);
      for (var i = 0; i < WidgetBridge.rows; i++) {
        for (final k in ['subject', 'title', 'count', 'progress', 'spine']) {
          expect(payload.containsKey('wd_t${i}_$k'), isTrue, reason: 'wd_t${i}_$k');
        }
      }
      expect(payload['wd_t1_title'], '');
      expect(payload['wd_t1_spine'], '0');
    });

    test('says how much did not fit', () {
      final payload = WidgetBridge.buildPayload([
        for (var i = 0; i < 6; i++) work('a$i', i),
      ], subjects);
      expect(payload['wd_count'], '6');
      expect(payload['wd_more'], '${6 - WidgetBridge.rows}');
      expect(payload['wd_empty'], '');
    });

    test('an empty week says exactly that', () {
      final payload = WidgetBridge.buildPayload([work('far', 30)], subjects);
      expect(
        payload['wd_empty'],
        'No assignments due in the next 7 days',
      );
      expect(payload['wd_count'], '0');
      expect(payload['wd_more'], '0');
      expect(payload['wd_t0_title'], '');
    });

    test('an empty list still produces a complete payload', () {
      final payload = WidgetBridge.buildPayload([], subjects);
      expect(payload['wd_empty'], isNotEmpty);
      expect(payload['wd_t0_title'], '');
    });
  });
}
