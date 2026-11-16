import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whats_due/main.dart';
import 'package:whats_due/models.dart';
import 'package:whats_due/store.dart';

/// Tasks within an assignment, and steps within a task, can be put in the
/// order the student wants. Order is list order, so it has to survive a save,
/// a reload and a backup without the JSON changing shape.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String seed() => jsonEncode({
    'subjects': <Object>[],
    'items': [
      {
        'id': 'a1',
        'title': 'Comparative essay',
        'subjectId': null,
        'due': '',
        'done': false,
        'tasks': [
          {'id': 't1', 'text': 'Outline', 'done': false},
          {'id': 't2', 'text': 'Sources', 'done': true},
          {
            'id': 't3',
            'text': 'Body',
            'done': false,
            'subtasks': [
              {'id': 's1', 'text': 'Intro', 'done': false},
              {'id': 's2', 'text': 'Argument', 'done': false},
              {'id': 's3', 'text': 'Conclusion', 'done': true},
            ],
          },
        ],
      },
    ],
  });

  Future<AppStore> load([String? raw]) async {
    SharedPreferences.setMockInitialValues({
      AppStore.storageKey: raw ?? seed(),
      'coursework:onboarded': true,
    });
    final s = AppStore();
    await s.init();
    return s;
  }

  Assignment essay(AppStore s) => s.items.single;
  List<String> tasks(AppStore s) => essay(s).tasks.map((t) => t.text).toList();
  List<String> steps(AppStore s) =>
      essay(s).tasks.firstWhere((t) => t.id == 't3').subtasks
          .map((x) => x.text)
          .toList();

  Future<String> saved() async =>
      (await SharedPreferences.getInstance()).getString(AppStore.storageKey)!;

  group('the store', () {
    test('moves a task down and up', () async {
      final s = await load();
      s.moveTask(essay(s), 0, 2);
      expect(tasks(s), ['Sources', 'Body', 'Outline']);
      s.moveTask(essay(s), 2, 0);
      expect(tasks(s), ['Outline', 'Sources', 'Body']);
    });

    test('moves a step within its task, and only there', () async {
      final s = await load();
      final body = essay(s).tasks.last;
      s.moveSubtask(body, 2, 0);
      expect(steps(s), ['Conclusion', 'Intro', 'Argument']);
      expect(tasks(s), ['Outline', 'Sources', 'Body']);
    });

    test('keeps each item whole: done state and steps travel with it',
        () async {
      final s = await load();
      s.moveTask(essay(s), 2, 0);
      final moved = essay(s).tasks.first;
      expect(moved.id, 't3');
      expect(moved.subtasks.map((x) => x.id), ['s1', 's2', 's3']);
      expect(essay(s).tasks[2].done, isTrue, reason: 'Sources was ticked');
    });

    test('ignores a move to the same place or out of range', () async {
      final s = await load();
      var saves = 0;
      s.addListener(() => saves++);
      s.moveTask(essay(s), 1, 1);
      s.moveTask(essay(s), -1, 0);
      s.moveTask(essay(s), 0, 3);
      s.moveSubtask(essay(s).tasks.last, 5, 0);
      expect(tasks(s), ['Outline', 'Sources', 'Body']);
      expect(saves, 0, reason: 'nothing moved, so nothing is saved');
    });

    test('the new order is saved, survives a reload and keeps the JSON shape',
        () async {
      final s = await load();
      s.moveTask(essay(s), 0, 2);
      s.moveSubtask(essay(s).tasks[1], 0, 1);

      final raw = await saved();
      final reloaded = await load(raw);
      expect(tasks(reloaded), ['Sources', 'Body', 'Outline']);
      expect(steps(reloaded), ['Argument', 'Intro', 'Conclusion']);

      // Same keys as before the move: order is the only thing that changed.
      final before = jsonDecode(seed()) as Map<String, dynamic>;
      final after = jsonDecode(raw) as Map<String, dynamic>;
      Set<String> taskKeys(Map<String, dynamic> doc) => {
        for (final t in (doc['items'] as List).single['tasks'] as List)
          ...(t as Map).keys.cast<String>(),
      };
      expect(taskKeys(after), taskKeys(before));
    });
  });

  group('the card', () {
    Future<AppStore> boot(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 1400);
      addTearDown(tester.view.reset);
      final s = await load();
      await tester.pumpWidget(WhatsDueApp(store: s));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Comparative essay'));
      await tester.pumpAndSettle();
      return s;
    }

    /// Drags the handle labelled [label] by [dy], in small steps so the list
    /// sees a real drag rather than a jump.
    Future<void> drag(WidgetTester tester, String label, double dy) async {
      final handle = find.bySemanticsLabel(label);
      expect(handle, findsOne);
      final g = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 50));
      for (var i = 0; i < 10; i++) {
        await g.moveBy(Offset(0, dy / 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pumpAndSettle();
    }

    testWidgets('every task carries a labelled drag handle', (tester) async {
      await boot(tester);
      for (final t in ['Outline', 'Sources', 'Body']) {
        expect(find.bySemanticsLabel('Drag to reorder $t'), findsOne);
      }
    });

    testWidgets('dragging a task by its handle reorders and saves it',
        (tester) async {
      final s = await boot(tester);
      final rowHeight =
          tester.getCenter(find.text('Sources')).dy -
          tester.getCenter(find.text('Outline')).dy;

      await drag(tester, 'Drag to reorder Outline', rowHeight * 2.2);

      expect(tasks(s), ['Sources', 'Body', 'Outline']);
      final reloaded = await load(await saved());
      expect(tasks(reloaded), ['Sources', 'Body', 'Outline']);
    });

    testWidgets('dragging a step reorders it within its task', (tester) async {
      final s = await boot(tester);
      await tester.tap(
        find.bySemanticsLabel('Body, 1 of 3 steps done, tap to expand'),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Drag to reorder step Intro'), findsOne);

      final rowHeight =
          tester.getCenter(find.text('Argument')).dy -
          tester.getCenter(find.text('Intro')).dy;
      await drag(tester, 'Drag to reorder step Conclusion', -rowHeight * 2.2);

      expect(steps(s), ['Conclusion', 'Intro', 'Argument']);
      expect(tasks(s), ['Outline', 'Sources', 'Body']);
    });

    testWidgets('a lone task has nothing to reorder, so no handle',
        (tester) async {
      final s = await load(
        jsonEncode({
          'subjects': <Object>[],
          'items': [
            {
              'id': 'a1',
              'title': 'Comparative essay',
              'subjectId': null,
              'due': '',
              'done': false,
              'tasks': [
                {'id': 't1', 'text': 'Outline', 'done': false},
              ],
            },
          ],
        }),
      );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 1400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(WhatsDueApp(store: s));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Comparative essay'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('^Drag to reorder')), findsNothing);
    });
  });
}
