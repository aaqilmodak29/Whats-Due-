import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whats_due/grades.dart';
import 'package:whats_due/models.dart';
import 'package:whats_due/store.dart';

/// Weighting turns a deadline list into a priority list, so the arithmetic here
/// is load-bearing: a wrong "what do I need on the final" is worse than none.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Assignment weighted({
    String id = 'a',
    String? subjectId = 's1',
    double? weight,
    double? earned,
    double? outOf,
  }) => Assignment(
    id: id,
    title: 'Item $id',
    subjectId: subjectId,
    weight: weight,
    earned: earned,
    outOf: outOf,
  );

  group('a single assignment', () {
    test('is not graded until both halves of the mark are present', () {
      expect(weighted(weight: 20, earned: 34).graded, isFalse);
      expect(weighted(weight: 20, outOf: 40).graded, isFalse);
      expect(weighted(weight: 20, earned: 34, outOf: 40).graded, isTrue);
    });

    test('treats zero out of forty as a real result', () {
      // Truthiness would read a zero mark as "not marked yet" and quietly
      // inflate the average by dropping the worst result.
      final a = weighted(weight: 20, earned: 0, outOf: 40);
      expect(a.graded, isTrue);
      expect(a.scored, 0);
      expect(a.contribution, 0);
    });

    test('refuses to divide by an out-of of zero', () {
      final a = weighted(weight: 20, earned: 0, outOf: 0);
      expect(a.graded, isFalse);
      expect(a.scored, isNull);
      expect(a.contribution, isNull);
    });

    test('converts raw marks into a share of the unit', () {
      final a = weighted(weight: 20, earned: 34, outOf: 40);
      expect(a.scored, closeTo(0.85, 1e-9));
      expect(a.contribution, closeTo(17, 1e-9));
    });

    test('contributes nothing without a weight', () {
      expect(weighted(earned: 34, outOf: 40).contribution, isNull);
    });
  });

  group('rolled up by subject', () {
    test('keeps subjects apart', () {
      // Weights are shares of one unit. Summing across units would add
      // percentages of different wholes.
      final grades = gradesBySubject([
        weighted(id: 'a', subjectId: 's1', weight: 50, earned: 40, outOf: 50),
        weighted(id: 'b', subjectId: 's2', weight: 30, earned: 15, outOf: 30),
      ]);
      expect(grades.length, 2);
      final s1 = grades.firstWhere((g) => g.subjectId == 's1');
      final s2 = grades.firstWhere((g) => g.subjectId == 's2');
      expect(s1.secured, closeTo(40, 1e-9));
      expect(s2.secured, closeTo(15, 1e-9));
    });

    test('ignores assignments with no weight', () {
      final grades = gradesBySubject([
        weighted(id: 'a', weight: 40, earned: 30, outOf: 40),
        weighted(id: 'b', earned: 10, outOf: 10),
      ]);
      expect(grades.single.trackedWeight, 40);
      expect(grades.single.gradedCount, 1);
    });

    test('rolls unfiled work up on its own rather than dropping it', () {
      final grades = gradesBySubject([
        weighted(id: 'a', subjectId: null, weight: 25, earned: 20, outOf: 25),
      ]);
      expect(grades.single.subjectId, isNull);
      expect(grades.single.secured, closeTo(20, 1e-9));
    });

    test('separates what is secured from the average so far', () {
      // Half the unit is graded at 80%. Secured is 40 of 100; the average is
      // 80% -- reporting 40% all semester would be wrong and demoralising.
      final g = gradesBySubject([
        weighted(id: 'a', weight: 50, earned: 40, outOf: 50),
        weighted(id: 'b', weight: 50),
      ]).single;

      expect(g.secured, closeTo(40, 1e-9));
      expect(g.gradedWeight, 50);
      expect(g.trackedWeight, 100);
      expect(g.remainingWeight, 50);
      expect(g.average, closeTo(0.8, 1e-9));
      expect(g.isPartiallyTracked, isFalse);
    });

    test('has no average before anything is graded', () {
      final g = gradesBySubject([weighted(weight: 100)]).single;
      expect(g.average, isNull);
      expect(g.gradedCount, 0);
    });

    test('flags a unit whose assessments do not add up to 100', () {
      final g = gradesBySubject([weighted(weight: 60)]).single;
      expect(g.isPartiallyTracked, isTrue);
    });
  });

  group('what is needed on the rest', () {
    test('computes the average required to hit a target', () {
      // 40 secured, 50% of the unit left, chasing 75 overall:
      // (75 - 40) / 50 = 70%.
      final g = gradesBySubject([
        weighted(id: 'a', weight: 50, earned: 40, outOf: 50),
        weighted(id: 'b', weight: 50),
      ]).single;
      expect(g.neededFor(75), closeTo(0.7, 1e-9));
    });

    test('reports above 1 when the target is already out of reach', () {
      final g = gradesBySubject([
        weighted(id: 'a', weight: 80, earned: 20, outOf: 80),
        weighted(id: 'b', weight: 20),
      ]).single;
      // Needing 200% of what is left is unreachable, and saying so is more
      // useful than clamping it to a hopeful 100%.
      expect(g.neededFor(60)! > 1, isTrue);
    });

    test('reports below zero when the target is already banked', () {
      final g = gradesBySubject([
        weighted(id: 'a', weight: 80, earned: 80, outOf: 80),
        weighted(id: 'b', weight: 20),
      ]).single;
      expect(g.neededFor(75)! < 0, isTrue);
    });

    test('is null once nothing is outstanding', () {
      final g = gradesBySubject([
        weighted(weight: 100, earned: 70, outOf: 100),
      ]).single;
      expect(g.remainingWeight, 0);
      expect(g.neededFor(75), isNull);
    });
  });

  group('task points', () {
    test('total only the tasks that carry them', () {
      final a = Assignment(
        id: 'a',
        title: 'Report',
        tasks: [
          Task(id: 't1', text: 'Part A', points: 5, done: true),
          Task(id: 't2', text: 'Part B', points: 15),
          Task(id: 't3', text: 'Proofread'),
        ],
      );
      expect(a.taskPoints, 20);
      expect(a.finishedPoints, 5);
    });

    test('are null when no task carries any', () {
      final a = Assignment(
        id: 'a',
        title: 'Report',
        tasks: [Task(id: 't1', text: 'Part A')],
      );
      expect(a.taskPoints, isNull);
      expect(a.finishedPoints, isNull);
    });
  });

  group('storage', () {
    test('an unmarked assignment serialises exactly as before', () {
      // Existing data has to round-trip untouched, or the first device on this
      // version rewrites the whole document and every other device sees the
      // entire list as edited.
      final json = Assignment(id: 'a', title: 'Essay').toJson();
      expect(json.containsKey('weight'), isFalse);
      expect(json.containsKey('earned'), isFalse);
      expect(json.containsKey('outOf'), isFalse);

      final t = Task(id: 't', text: 'Draft').toJson();
      expect(t.keys, ['id', 'text', 'done']);
    });

    test('marks round-trip', () {
      final a = Assignment(
        id: 'a',
        title: 'Essay',
        weight: 12.5,
        earned: 34,
        outOf: 40,
        tasks: [Task(id: 't', text: 'Part A', points: 5, minutes: 90)],
      );
      final back = Assignment.fromJson(jsonDecode(jsonEncode(a.toJson())));
      expect(back.weight, 12.5);
      expect(back.earned, 34);
      expect(back.outOf, 40);
      expect(back.tasks.single.points, 5);
      expect(back.tasks.single.minutes, 90);
    });

    test('numbers written as strings or ints still load', () {
      // Values arrive from hand-edited backups and from another device's copy,
      // so a mark can turn up as 20, 20.0 or "20".
      final a = Assignment.fromJson({
        'id': 'a',
        'title': 'Essay',
        'weight': '20',
        'earned': 34,
        'outOf': 40.0,
        'tasks': [
          {'id': 't', 'text': 'Part A', 'points': '5', 'minutes': '90'},
        ],
      });
      expect(a.weight, 20);
      expect(a.outOf, 40);
      expect(a.tasks.single.points, 5);
      expect(a.tasks.single.minutes, 90);
    });

    test('unreadable numbers become untracked rather than fatal', () {
      final a = Assignment.fromJson({
        'id': 'a',
        'title': 'Essay',
        'weight': 'heavy',
      });
      expect(a.weight, isNull);
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
      final a = s.items.single;
      expect(a.weight, isNull);
      expect(a.graded, isFalse);
      expect(a.tasks.single.points, isNull);
    });
  });

  group('store mutations', () {
    Future<AppStore> store() async {
      SharedPreferences.setMockInitialValues({});
      final s = AppStore();
      await s.init();
      return s;
    }

    test('setting one field leaves the others alone', () async {
      final s = await store();
      final a = s.addAssignment(title: 'Essay');
      s.setMarks(a, weight: 20.0);
      s.setMarks(a, earned: 34.0, outOf: 40.0);
      expect(a.weight, 20);
      expect(a.earned, 34);

      s.setMarks(a, earned: 30.0);
      expect(a.weight, 20, reason: 'weight was not passed, so it is unchanged');
      expect(a.outOf, 40);
    });

    test('a field can be cleared back to untracked', () async {
      // The sentinel exists for exactly this: null has to mean "clear", which
      // is indistinguishable from "omitted" without it.
      final s = await store();
      final a = s.addAssignment(title: 'Essay');
      s.setMarks(a, weight: 20.0, earned: 34.0, outOf: 40.0);
      s.setMarks(a, earned: null);
      expect(a.earned, isNull);
      expect(a.graded, isFalse);
      expect(a.weight, 20);
    });

    test('marks survive a reload', () async {
      final s = await store();
      final a = s.addAssignment(title: 'Essay');
      s.setMarks(a, weight: 20.0, earned: 34.0, outOf: 40.0);
      s.setTaskPoints(s.addTask(a, 'Part A')!, 5);

      final reloaded = AppStore();
      await reloaded.init();
      expect(reloaded.items.single.weight, 20);
      expect(reloaded.items.single.contribution, closeTo(17, 1e-9));
      expect(reloaded.items.single.tasks.single.points, 5);
    });
  });

  group('formatting', () {
    test('trims a pointless decimal but keeps a real one', () {
      expect(trimNumber(20), '20');
      expect(trimNumber(20.0), '20');
      expect(trimNumber(12.5), '12.5');
      expect(formatPercent(0.85), '85%');
    });
  });
}
