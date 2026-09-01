import 'package:flutter_test/flutter_test.dart';
import 'package:whats_due/models.dart';
import 'package:whats_due/planner.dart';

/// The planner is the one piece of the app that gives an opinion rather than
/// reporting a fact, so its ranking has to be defensible: the work that is
/// furthest behind, first, and never an empty screen while work exists.
void main() {
  // Pinned so "3 days from now" means the same thing on every run.
  final fixedNow = DateTime(2026, 8, 6, 12);
  setUp(() => clock = () => fixedNow);
  tearDown(() => clock = DateTime.now);

  String inDays(int n) => formatIsoDate(
    DateTime(fixedNow.year, fixedNow.month, fixedNow.day).add(
      Duration(days: n),
    ),
  );

  Assignment work(
    String id,
    int dueInDays,
    List<Task> tasks, {
    bool done = false,
  }) => Assignment(
    id: id,
    title: 'Item $id',
    due: dueInDays == 9999 ? '' : inDays(dueInDays),
    done: done,
    tasks: tasks,
  );

  Task task(String id, {int? minutes, bool done = false}) =>
      Task(id: id, text: 'Task $id', minutes: minutes, done: done);

  group('what gets planned at all', () {
    test('submitted assignments are left out', () {
      final plan = todayPlan([
        work('a', 2, [task('t1')], done: true),
      ]);
      expect(plan.isEmpty, isTrue);
    });

    test('assignments with every task ticked are left out', () {
      final plan = todayPlan([
        work('a', 2, [task('t1', done: true)]),
      ]);
      expect(plan.isEmpty, isTrue);
    });

    test('finished tasks are never planned', () {
      final plan = todayPlan([
        work('a', 1, [task('t1', done: true), task('t2')]),
      ]);
      expect(plan.tasks.single.task.id, 't2');
    });

    test('undated work is counted, not scheduled', () {
      // It cannot be paced without a deadline, but dropping it silently would
      // hide real work.
      final plan = todayPlan([
        work('a', 9999, [task('t1')]),
        work('b', 3, [task('t2')]),
      ]);
      expect(plan.undated, 1);
      expect(plan.tasks.map((p) => p.task.id), ['t2']);
    });
  });

  group('ordering', () {
    test('puts the heaviest daily load first, not the nearest deadline', () {
      // 'far' needs 20h over 10 days = 2h/day. 'near' needs 1h over 3 days =
      // 20m/day. The nearer deadline is the lighter job, and saying so is the
      // whole point of estimating.
      final plan = todayPlan([
        work('near', 2, [task('n1', minutes: 60)]),
        work('far', 9, [
          for (var i = 0; i < 10; i++) task('f$i', minutes: 120),
        ]),
      ]);
      expect(plan.tasks.first.assignment.id, 'far');
    });

    test('overdue work collapses to one day left, so it rises', () {
      final plan = todayPlan([
        work('later', 5, [task('l1', minutes: 120)]),
        work('overdue', -3, [task('o1', minutes: 60)]),
      ]);
      expect(plan.tasks.first.assignment.id, 'overdue');
    });

    test('ties break on the earlier deadline', () {
      // Today counts as a working day, so "in 3 days" leaves 4. 40 over 4 and
      // 70 over 7 are both 10 minutes a day; the sooner one goes first.
      final plan = todayPlan([
        work('b', 6, [task('b1', minutes: 70)]),
        work('a', 3, [task('a1', minutes: 40)]),
      ]);
      expect(plan.tasks.first.assignment.id, 'a');
    });
  });

  group('how much of each assignment lands in a day', () {
    test('takes only today\'s share of a long job', () {
      // 6 hours spread over 6 days is one hour a day: one task, not six.
      final plan = todayPlan([
        work('a', 5, [
          for (var i = 0; i < 6; i++) task('t$i', minutes: 60),
        ]),
      ]);
      expect(plan.tasks.length, 1);
      expect(plan.estimatedMinutes, 60);
    });

    test('takes everything when it is all due today', () {
      final plan = todayPlan([
        work('a', 0, [
          task('t1', minutes: 60),
          task('t2', minutes: 60),
          task('t3', minutes: 60),
        ]),
      ]);
      expect(plan.tasks.length, 3);
      expect(plan.estimatedMinutes, 180);
    });

    test('always takes at least one task per assignment', () {
      // A tiny job a long way off still deserves a visible next action.
      final plan = todayPlan([
        work('a', 30, [task('t1', minutes: 15), task('t2', minutes: 15)]),
      ]);
      expect(plan.tasks.length, 1);
    });
  });

  group('unestimated work', () {
    test('still produces a plan when nothing has been estimated', () {
      // The app has to be useful before any effort is entered, or nobody ever
      // enters any.
      final plan = todayPlan([
        work('a', 2, [task('a1'), task('a2')]),
        work('b', 6, [task('b1')]),
      ]);
      expect(plan.isEmpty, isFalse);
      expect(plan.tasks.map((p) => p.assignment.id), ['a', 'b']);
      expect(plan.unestimated, 2);
      expect(plan.estimatedMinutes, 0, reason: 'no real estimates to add up');
    });

    test('an unestimated task cannot empty its assignment into today', () {
      // Pacing them at zero would make them free, so one assignment would take
      // the whole day.
      final plan = todayPlan([
        work('a', 9, [for (var i = 0; i < 12; i++) task('t$i')]),
      ]);
      expect(plan.tasks.length, lessThan(4));
    });

    test('reports guesses separately from the estimated total', () {
      final plan = todayPlan([
        work('a', 0, [task('t1', minutes: 90), task('t2')]),
      ]);
      expect(plan.estimatedMinutes, 90, reason: 'the guess is not added in');
      expect(plan.unestimated, 1);
      expect(plan.tasks.length, 2);
    });
  });

  group('the next action', () {
    test('names the next unfinished step when a task has been broken down', () {
      final t = Task(
        id: 't1',
        text: 'Part A',
        minutes: 60,
        subtasks: [
          SubTask(id: 's1', text: 'Agree the topic', done: true),
          SubTask(id: 's2', text: 'Draft the abstract'),
        ],
      );
      final plan = todayPlan([work('a', 1, [t])]);
      final planned = plan.tasks.single;
      expect(planned.subtask?.text, 'Draft the abstract');
      expect(planned.label, 'Draft the abstract');
      expect(planned.minutes, 60, reason: 'effort stays at task granularity');
    });

    test('falls back to the task itself when there are no steps', () {
      final plan = todayPlan([
        work('a', 1, [task('t1')]),
      ]);
      expect(plan.tasks.single.subtask, isNull);
      expect(plan.tasks.single.label, 'Task t1');
    });
  });

  group('formatting', () {
    test('reads as hours and minutes', () {
      expect(formatMinutes(45), '45m');
      expect(formatMinutes(60), '1h');
      expect(formatMinutes(90), '1h 30m');
      expect(formatMinutes(0), '0m');
      expect(formatMinutes(-5), '0m');
    });
  });
}
