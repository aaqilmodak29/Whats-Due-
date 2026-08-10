import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whats_due/models.dart';
import 'package:whats_due/store.dart';

/// Subtasks add a second level under a task, and a derived done state.
///
/// The derivation is the part worth guarding: a parent that could disagree
/// with its own children would make the card's progress bar report finished
/// work that is not finished.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppStore> store([Map<String, Object>? prefs]) async {
    SharedPreferences.setMockInitialValues(prefs ?? {});
    final s = AppStore();
    await s.init();
    return s;
  }

  group('done is derived once there are steps', () {
    test('a task with no steps keeps its own flag', () {
      final t = Task(id: 't', text: 'Write the report');
      expect(t.done, isFalse);
      t.done = true;
      expect(t.done, isTrue);
    });

    test('a task with steps is done only when all of them are', () {
      final t = Task(
        id: 't',
        text: 'Part A',
        subtasks: [
          SubTask(id: 's1', text: 'Agree the topic'),
          SubTask(id: 's2', text: 'Lock the group'),
        ],
      );
      expect(t.done, isFalse);

      t.subtasks[0].done = true;
      expect(t.done, isFalse, reason: 'one of two is not done');

      t.subtasks[1].done = true;
      expect(t.done, isTrue);
    });

    test('unticking one step reopens the parent', () {
      final t = Task(
        id: 't',
        text: 'Part A',
        subtasks: [SubTask(id: 's1', text: 'Step', done: true)],
      );
      expect(t.done, isTrue);
      t.subtasks.single.done = false;
      expect(t.done, isFalse);
    });

    test('ticking the parent ticks every step', () {
      final t = Task(
        id: 't',
        text: 'Part A',
        subtasks: [
          SubTask(id: 's1', text: 'One'),
          SubTask(id: 's2', text: 'Two'),
        ],
      );
      t.done = true;
      expect(t.subtasks.every((s) => s.done), isTrue);

      t.done = false;
      expect(t.subtasks.any((s) => s.done), isFalse);
    });

    test('finishedSubtasks counts what the row displays', () {
      final t = Task(
        id: 't',
        text: 'Part A',
        subtasks: [
          SubTask(id: 's1', text: 'One', done: true),
          SubTask(id: 's2', text: 'Two'),
          SubTask(id: 's3', text: 'Three', done: true),
        ],
      );
      expect(t.finishedSubtasks, 2);
      expect(t.subtasks.length, 3);
    });
  });

  group('adding a step to a finished task', () {
    test('does not silently reopen it', () async {
      // done is derived once steps exist, so a fresh unticked step would drag
      // a completed task back open.
      final s = await store();
      final a = s.addAssignment(title: 'Essay');
      s.addTask(a, 'Part A');
      final t = a.tasks.single;
      s.toggleTask(a, t);
      expect(t.done, isTrue);

      s.addSubtask(t, 'Agree the topic');
      expect(t.done, isTrue, reason: 'the task was already finished');
      expect(t.subtasks.single.done, isTrue);
    });

    test('an unfinished task gains an unfinished step', () async {
      final s = await store();
      final a = s.addAssignment(title: 'Essay');
      s.addTask(a, 'Part A');
      final t = a.tasks.single;

      s.addSubtask(t, 'Agree the topic');
      expect(t.done, isFalse);
      expect(t.subtasks.single.done, isFalse);
    });
  });

  group('storage', () {
    test('a task with steps round-trips', () {
      final t = Task(
        id: 't',
        text: 'Part A',
        subtasks: [
          SubTask(id: 's1', text: 'Agree the topic', done: true),
          SubTask(id: 's2', text: 'Lock the group'),
        ],
      );
      final back = Task.fromJson(t.toJson());
      expect(back.text, 'Part A');
      expect(back.subtasks.map((s) => s.text), [
        'Agree the topic',
        'Lock the group',
      ]);
      expect(back.subtasks.first.done, isTrue);
      expect(back.done, isFalse);
    });

    test('a task with no steps serialises exactly as before', () {
      // Existing data must round-trip unchanged, or every device would see the
      // whole list as edited the moment this version ran.
      final json = Task(id: 't', text: 'Draft', done: true).toJson();
      expect(json.keys, ['id', 'text', 'done']);
      expect(json.containsKey('subtasks'), isFalse);
    });

    test('data written before subtasks existed still loads', () async {
      final s = await store({
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
                {'id': 't2', 'text': 'Proofread', 'done': false},
              ],
            },
          ],
        }),
      });

      final tasks = s.items.single.tasks;
      expect(tasks.map((t) => t.text), ['Draft', 'Proofread']);
      expect(tasks.first.done, isTrue);
      expect(tasks.every((t) => t.subtasks.isEmpty), isTrue);
    });

    test('malformed steps are skipped, not fatal', () {
      final t = Task.fromJson({
        'id': 't',
        'text': 'Part A',
        'subtasks': [
          'not an object',
          {'id': 's1', 'text': 'Real step'},
        ],
      });
      expect(t.subtasks.map((s) => s.text), ['Real step']);
    });
  });

  group('the card\'s progress counts tasks, not steps', () {
    test('a half-finished task does not count as finished', () async {
      final s = await store();
      final a = s.addAssignment(title: 'Mini project');
      s.addTask(a, 'Part A');
      s.addTask(a, 'Part B');
      final partA = a.tasks.first;

      s.addSubtask(partA, 'Agree the topic');
      s.addSubtask(partA, 'Lock the group');
      s.toggleSubtask(partA.subtasks.first);

      expect(a.tasks.length, 2);
      expect(a.finishedTasks, 0, reason: 'Part A still has a step outstanding');

      s.toggleSubtask(partA.subtasks.last);
      expect(a.finishedTasks, 1);
    });
  });

  group('store mutations', () {
    test('a blank step is refused', () async {
      final s = await store();
      final a = s.addAssignment(title: 'Essay');
      s.addTask(a, 'Part A');
      s.addSubtask(a.tasks.single, '   ');
      expect(a.tasks.single.subtasks, isEmpty);
    });

    test('deleting a step leaves the rest', () async {
      final s = await store();
      final a = s.addAssignment(title: 'Essay');
      s.addTask(a, 'Part A');
      final t = a.tasks.single;
      s.addSubtask(t, 'One');
      s.addSubtask(t, 'Two');

      s.deleteSubtask(t, t.subtasks.first);
      expect(t.subtasks.map((x) => x.text), ['Two']);
    });

    test('deleting the last step returns the task to its own flag', () async {
      final s = await store();
      final a = s.addAssignment(title: 'Essay');
      s.addTask(a, 'Part A');
      final t = a.tasks.single;
      s.addSubtask(t, 'One');

      s.deleteSubtask(t, t.subtasks.single);
      expect(t.hasSubtasks, isFalse);
      expect(t.done, isFalse);
      s.toggleTask(a, t);
      expect(t.done, isTrue);
    });

    test('steps survive a reload', () async {
      final s = await store();
      final a = s.addAssignment(title: 'Essay');
      s.addTask(a, 'Part A');
      s.addSubtask(a.tasks.single, 'Agree the topic');

      final reloaded = AppStore();
      await reloaded.init();
      expect(
        reloaded.items.single.tasks.single.subtasks.single.text,
        'Agree the topic',
      );
    });
  });
}
