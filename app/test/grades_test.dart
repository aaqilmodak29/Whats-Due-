import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whats_due/grades.dart';
import 'package:whats_due/models.dart';
import 'package:whats_due/store.dart';

/// Marks turn a deadline list into a record of how it went, so the arithmetic
/// here is load-bearing.
///
/// Weighting was removed pending a decision on how to handle it, so these
/// totals are unweighted: raw marks added up. The old `weight` field is still
/// read and written, but nothing below uses it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Assignment marked({
    String id = 'a',
    String? subjectId = 's1',
    double? earned,
    double? outOf,
  }) => Assignment(
    id: id,
    title: 'Item $id',
    subjectId: subjectId,
    earned: earned,
    outOf: outOf,
  );

  group('a single assignment', () {
    test('is not graded until both halves of the mark are present', () {
      expect(marked(earned: 34).graded, isFalse);
      expect(marked(outOf: 40).graded, isFalse);
      expect(marked(earned: 34, outOf: 40).graded, isTrue);
    });

    test('treats zero out of forty as a real result', () {
      // Truthiness would read a zero mark as "not marked yet" and quietly
      // inflate the average by dropping the worst result.
      final a = marked(earned: 0, outOf: 40);
      expect(a.graded, isTrue);
      expect(a.scored, 0);
    });

    test('refuses to divide by an out-of of zero', () {
      final a = marked(earned: 0, outOf: 0);
      expect(a.graded, isFalse);
      expect(a.scored, isNull);
    });

    test('reads raw marks as a fraction', () {
      expect(marked(earned: 34, outOf: 40).scored, closeTo(0.85, 1e-9));
    });
  });

  group('rolled up by subject', () {
    test('adds the marks, not the percentages', () {
      // 34/40 and 8/10 is 42 out of 50 — 84%. Averaging the two percentages
      // instead would give 85%, silently treating a ten-mark quiz as the equal
      // of a forty-mark report.
      final g = gradesBySubject([
        marked(id: 'a', earned: 34, outOf: 40),
        marked(id: 'b', earned: 8, outOf: 10),
      ]).single;

      expect(g.earned, 42);
      expect(g.outOf, 50);
      expect(g.average, closeTo(0.84, 1e-9));
      expect(g.gradedCount, 2);
    });

    test('keeps subjects apart', () {
      final grades = gradesBySubject([
        marked(id: 'a', subjectId: 's1', earned: 40, outOf: 50),
        marked(id: 'b', subjectId: 's2', earned: 15, outOf: 30),
      ]);
      expect(grades.length, 2);
      expect(
        grades.firstWhere((g) => g.subjectId == 's1').average,
        closeTo(0.8, 1e-9),
      );
      expect(
        grades.firstWhere((g) => g.subjectId == 's2').average,
        closeTo(0.5, 1e-9),
      );
    });

    test('ignores assignments with no result yet', () {
      // A marks total on its own is not a result: it is what the assignment
      // will be marked out of, entered when it was added.
      final grades = gradesBySubject([
        marked(id: 'a', earned: 30, outOf: 40),
        marked(id: 'b', outOf: 100),
        marked(id: 'c'),
      ]);
      expect(grades.single.gradedCount, 1);
      expect(grades.single.outOf, 40);
    });

    test('rolls unfiled work up on its own rather than dropping it', () {
      final g = gradesBySubject([
        marked(id: 'a', subjectId: null, earned: 20, outOf: 25),
      ]).single;
      expect(g.subjectId, isNull);
      expect(g.average, closeTo(0.8, 1e-9));
    });

    test('a subject with nothing marked does not appear at all', () {
      expect(gradesBySubject([marked(outOf: 40)]), isEmpty);
    });
  });

  group('storage', () {
    test('an unmarked assignment serialises exactly as before', () {
      final json = Assignment(id: 'a', title: 'Essay').toJson();
      expect(json.containsKey('earned'), isFalse);
      expect(json.containsKey('outOf'), isFalse);
      expect(json.containsKey('weight'), isFalse);
    });

    test('marks round-trip', () {
      final a = Assignment(
        id: 'a',
        title: 'Essay',
        earned: 34,
        outOf: 40,
        tasks: [Task(id: 't', text: 'Part A', points: 5, minutes: 90)],
      );
      final back = Assignment.fromJson(jsonDecode(jsonEncode(a.toJson())));
      expect(back.earned, 34);
      expect(back.outOf, 40);
      expect(back.tasks.single.points, 5);
    });

    test('a weight recorded before it was removed is not destroyed', () {
      // The field is no longer shown or used, but dropping it would have every
      // device discard those values on its next write.
      final a = Assignment.fromJson({
        'id': 'a',
        'title': 'Essay',
        'weight': 20,
        'earned': 34,
        'outOf': 40,
      });
      expect(a.weight, 20);
      expect(a.toJson()['weight'], 20);
    });

    test('numbers written as strings or ints still load', () {
      final a = Assignment.fromJson({
        'id': 'a',
        'title': 'Essay',
        'earned': 34,
        'outOf': '40',
      });
      expect(a.outOf, 40);
      expect(a.scored, closeTo(0.85, 1e-9));
    });

    test('data written before marks existed still loads', () async {
      SharedPreferences.setMockInitialValues({
        AppStore.storageKey: jsonEncode({
          'subjects': <Object>[],
          'items': [
            {
              'id': 'a1',
              'title': 'Essay',
              'due': '2026-10-23',
              'done': false,
              'tasks': [
                {'id': 't1', 'text': 'Draft', 'done': true},
              ],
            },
          ],
        }),
      });
      final s = AppStore();
      await s.init();
      expect(s.items.single.graded, isFalse);
      expect(s.items.single.outOf, isNull);
    });
  });

  group('store mutations', () {
    Future<AppStore> store() async {
      SharedPreferences.setMockInitialValues({});
      final s = AppStore();
      await s.init();
      return s;
    }

    test('marks can be set when the assignment is added', () async {
      // The spec says what it is out of, so it is known at the point of
      // adding; the score is not.
      final s = await store();
      final a = s.addAssignment(title: 'Essay', outOf: 40);
      expect(a.outOf, 40);
      expect(a.earned, isNull);
      expect(a.graded, isFalse);
    });

    test('setting one field leaves the other alone', () async {
      final s = await store();
      final a = s.addAssignment(title: 'Essay', outOf: 40);
      s.setMarks(a, earned: 34.0);
      expect(a.earned, 34);
      expect(a.outOf, 40, reason: 'outOf was not passed, so it is unchanged');
    });

    test('a field can be cleared back to untracked', () async {
      final s = await store();
      final a = s.addAssignment(title: 'Essay', outOf: 40);
      s.setMarks(a, earned: 34.0);
      s.setMarks(a, earned: null);
      expect(a.earned, isNull);
      expect(a.graded, isFalse);
      expect(a.outOf, 40);
    });

    test('marks survive a reload', () async {
      final s = await store();
      final a = s.addAssignment(title: 'Essay', outOf: 40);
      s.setMarks(a, earned: 34.0);
      s.setTaskPoints(s.addTask(a, 'Part A')!, 5);

      final reloaded = AppStore();
      await reloaded.init();
      expect(reloaded.items.single.scored, closeTo(0.85, 1e-9));
      expect(reloaded.items.single.tasks.single.points, 5);
    });
  });

  group('formatting', () {
    test('trims a pointless decimal but keeps a real one', () {
      expect(trimNumber(20), '20');
      expect(trimNumber(12.5), '12.5');
      expect(formatPercent(0.85), '85%');
    });
  });
}
