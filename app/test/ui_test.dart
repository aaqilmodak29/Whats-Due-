import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whats_due/main.dart';
import 'package:whats_due/models.dart';
import 'package:whats_due/store.dart';
import 'package:whats_due/theme.dart';

String _iso(int offsetDays) =>
    formatIsoDate(midnight().add(Duration(days: offsetDays)));

/// A realistic semester: overdue work, a crunch day carrying two deadlines, an
/// unfiled item with no date, and something already submitted.
String _seed() => jsonEncode({
  'subjects': [
    {'id': 's1', 'name': 'Organic Chemistry', 'color': '#0E7C7B'},
    {'id': 's2', 'name': 'Statistics', 'color': '#2F5FA8'},
    {'id': 's3', 'name': 'Medieval History', 'color': '#7B3F61'},
  ],
  'items': [
    {
      'id': 'a1',
      'title': 'Reaction mechanisms problem set',
      'subjectId': 's1',
      'due': _iso(-2),
      'done': false,
      'tasks': [
        {'id': 't1', 'text': 'Q1-Q5', 'done': true},
        {'id': 't2', 'text': 'Q6-Q10', 'done': false},
      ],
    },
    {
      'id': 'a2',
      'title': 'Comparative essay',
      'subjectId': 's3',
      'due': _iso(1),
      'done': false,
      'tasks': <Object>[],
    },
    {
      'id': 'a3',
      'title': 'Regression assignment',
      'subjectId': 's2',
      'due': _iso(4),
      'done': false,
      'tasks': <Object>[],
    },
    {
      'id': 'a4',
      'title': 'Lab report titration',
      'subjectId': 's1',
      'due': _iso(4),
      'done': false,
      'tasks': <Object>[],
    },
    {
      'id': 'a5',
      'title': 'Read chapters 4-6',
      'subjectId': null,
      'due': '',
      'done': false,
      'tasks': <Object>[],
    },
    {
      'id': 'a6',
      'title': 'Week 3 problem set',
      'subjectId': 's2',
      'due': _iso(-9),
      'done': true,
      'tasks': <Object>[],
    },
  ],
});

/// Boots the real app over seeded storage and runs [body].
///
/// Semantics are enabled throughout, so widgets can be found by the label a
/// screen reader would announce — which makes the accessibility wiring part of
/// what these tests hold. The handle is disposed inside the body rather than in
/// a tearDown, because Flutter verifies handles were released *before* tearDowns
/// run.
void appTest(
  String description,
  Future<void> Function(WidgetTester tester, AppStore store) body, {
  String? seed,
  Size size = const Size(430, 932),
}) {
  testWidgets(description, (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    final semantics = tester.ensureSemantics();
    try {
      SharedPreferences.setMockInitialValues(
        seed == null ? {} : {AppStore.storageKey: seed},
      );
      final store = AppStore();
      await store.init();
      await tester.pumpWidget(WhatsDueApp(store: store));
      await tester.pumpAndSettle();
      await body(tester, store);
    } finally {
      semantics.dispose();
    }
  });
}

/// Text fields behind a dialog would otherwise be matched first.
Finder dialogField() => find.descendant(
  of: find.byType(Dialog),
  matching: find.byType(TextField),
);

void main() {
  group('home', () {
    appTest('renders the header, stats and every open assignment', (
      tester,
      store,
    ) async {
      expect(find.text("What's due"), findsOne);
      expect(find.text('COURSEWORK'), findsOne);

      // One overdue; three of the five open items fall inside seven days; the
      // undated one is open but lands in neither bucket.
      expect(find.text('1 OVERDUE · 3 DUE WITHIN 7 DAYS · 5 OPEN'), findsOne);

      expect(find.text('OPEN (5)'), findsOne);
      expect(find.text('SUBMITTED (1)'), findsOne);

      expect(find.text('Reaction mechanisms problem set'), findsOne);
      expect(find.text('Comparative essay'), findsOne);
      expect(find.text('Read chapters 4-6'), findsOne);
      // Submitted work is behind the other tab.
      expect(find.text('Week 3 problem set'), findsNothing);
    }, seed: _seed());

    appTest('sorts soonest first and puts undated work last', (
      tester,
      store,
    ) async {
      const titles = {
        'Reaction mechanisms problem set',
        'Comparative essay',
        'Regression assignment',
        'Lab report titration',
        'Read chapters 4-6',
      };
      final rendered = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .where(titles.contains)
          .toList();

      expect(rendered.first, 'Reaction mechanisms problem set');
      expect(rendered.last, 'Read chapters 4-6');
    }, seed: _seed());

    appTest('countdowns read as words, not raw dates', (tester, store) async {
      expect(find.text('2 DAYS LATE'), findsOne);
      expect(find.text('TOMORROW'), findsOne);
      expect(find.text('NO DATE'), findsOne);
    }, seed: _seed());

    appTest('the empty state explains itself', (tester, store) async {
      expect(find.text('Nothing tracked yet'), findsOne);
      expect(find.text('OPEN (0)'), findsOne);
      // No subjects means no filter chips at all.
      expect(find.textContaining('ALL '), findsNothing);
    });

    appTest('subject chips filter the list but not the horizon', (
      tester,
      store,
    ) async {
      expect(find.text('ORGANIC CHEMISTRY 2'), findsOne);
      await tester.tap(find.text('ORGANIC CHEMISTRY 2'));
      await tester.pumpAndSettle();

      expect(find.text('Reaction mechanisms problem set'), findsOne);
      expect(find.text('Lab report titration'), findsOne);
      expect(find.text('Comparative essay'), findsNothing);

      await tester.tap(find.text('ALL 5'));
      await tester.pumpAndSettle();
      expect(find.text('Comparative essay'), findsOne);
    }, seed: _seed());

    appTest('the submitted tab shows finished work', (tester, store) async {
      await tester.tap(find.text('SUBMITTED (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Week 3 problem set'), findsOne);
      expect(find.text('SUBMITTED'), findsOne);
      expect(find.text('Comparative essay'), findsNothing);
    }, seed: _seed());
  });

  group('a card', () {
    appTest('expands to reveal tasks and actions', (tester, store) async {
      await tester.tap(find.text('Reaction mechanisms problem set'));
      await tester.pumpAndSettle();

      expect(find.text('Q1-Q5'), findsOne);
      expect(find.text('Q6-Q10'), findsOne);
      expect(find.text('MARK SUBMITTED'), findsOne);
      expect(find.text('EDIT'), findsOne);
      expect(find.text('REMIND ME'), findsOne);
    }, seed: _seed());

    appTest('a task can be added and ticked', (tester, store) async {
      await tester.tap(find.text('Comparative essay'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'Find third source');
      await tester.tap(find.text('ADD'));
      await tester.pumpAndSettle();

      final essay = store.items.firstWhere((a) => a.id == 'a2');
      expect(essay.tasks.single.text, 'Find third source');
      expect(find.text('0/1'), findsOne);

      await tester.tap(find.bySemanticsLabel('Mark task finished'));
      await tester.pumpAndSettle();

      expect(essay.tasks.single.done, isTrue);
      expect(find.text('1/1'), findsOne);
    }, seed: _seed());

    appTest('a task can be removed', (tester, store) async {
      await tester.tap(find.text('Reaction mechanisms problem set'));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Remove task Q6-Q10'));
      await tester.pumpAndSettle();

      final a = store.items.firstWhere((x) => x.id == 'a1');
      expect(a.tasks.map((t) => t.text), ['Q1-Q5']);
      expect(find.text('Q6-Q10'), findsNothing);
    }, seed: _seed());

    appTest('marking submitted moves it to the other tab', (
      tester,
      store,
    ) async {
      await tester.tap(find.text('Comparative essay'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MARK SUBMITTED'));
      await tester.pumpAndSettle();

      expect(store.items.firstWhere((a) => a.id == 'a2').done, isTrue);
      expect(find.text('OPEN (4)'), findsOne);
      expect(find.text('SUBMITTED (2)'), findsOne);
    }, seed: _seed());

    appTest('the subject can be reassigned from the card', (
      tester,
      store,
    ) async {
      await tester.tap(find.text('Comparative essay'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Statistics').last);
      await tester.pumpAndSettle();

      expect(store.items.firstWhere((a) => a.id == 'a2').subjectId, 's2');
    }, seed: _seed());

    appTest('deleting asks first, then removes it', (tester, store) async {
      await tester.tap(find.text('Comparative essay'));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Delete assignment'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this assignment?'), findsOne);

      // Backing out leaves it alone.
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      expect(store.items.any((a) => a.id == 'a2'), isTrue);

      await tester.tap(find.bySemanticsLabel('Delete assignment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DELETE'));
      await tester.pumpAndSettle();

      expect(store.items.any((a) => a.id == 'a2'), isFalse);
      expect(find.text('Comparative essay'), findsNothing);
    }, seed: _seed());
  });

  group('editing', () {
    appTest('title and due date can both be changed after creation', (
      tester,
      store,
    ) async {
      await tester.tap(find.text('Comparative essay'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EDIT'));
      await tester.pumpAndSettle();

      expect(find.text('EDIT ASSIGNMENT'), findsOne);

      await tester.enterText(dialogField(), 'Comparative essay - final');
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      expect(
        store.items.firstWhere((a) => a.id == 'a2').title,
        'Comparative essay - final',
      );
      expect(find.text('Comparative essay - final'), findsOne);
    }, seed: _seed());

    appTest('cancelling changes nothing', (tester, store) async {
      await tester.tap(find.text('Comparative essay'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EDIT'));
      await tester.pumpAndSettle();

      await tester.enterText(dialogField(), 'Discard me');
      await tester.pumpAndSettle();
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();

      expect(
        store.items.firstWhere((a) => a.id == 'a2').title,
        'Comparative essay',
      );
    }, seed: _seed());

    appTest('a due date can be cleared back to undated', (tester, store) async {
      await tester.tap(find.text('Comparative essay'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EDIT'));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Clear due date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      expect(store.items.firstWhere((a) => a.id == 'a2').due, '');
      expect(find.text('NO DATE'), findsExactly(2));
    }, seed: _seed());
  });

  group('adding', () {
    appTest('a new assignment with a brand new subject', (
      tester,
      store,
    ) async {
      await tester.tap(find.bySemanticsLabel('Add assignment'));
      await tester.pumpAndSettle();

      expect(find.text('NEW ASSIGNMENT'), findsOne);

      await tester.enterText(find.byType(TextField).first, 'Comparative essay');
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+ New subject…').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'Organic Chemistry');
      await tester.pumpAndSettle();

      await tester.tap(find.text('TRACK IT'));
      await tester.pumpAndSettle();

      expect(store.subjects.single.name, 'Organic Chemistry');
      expect(store.items.single.title, 'Comparative essay');
      expect(store.items.single.subjectId, store.subjects.single.id);
      // A new subject takes the next palette colour, which on an empty install
      // is the first.
      expect(store.subjects.single.color, kPalette.first);
    }, size: const Size(430, 1200));

    appTest('a blank title is refused rather than creating a nameless card', (
      tester,
      store,
    ) async {
      await tester.tap(find.bySemanticsLabel('Add assignment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TRACK IT'));
      await tester.pumpAndSettle();

      expect(store.items, isEmpty);
    }, size: const Size(430, 1200));

    appTest('an assignment can be filed as Unfiled', (tester, store) async {
      await tester.tap(find.bySemanticsLabel('Add assignment'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Read chapters 4-6');
      await tester.pumpAndSettle();
      await tester.tap(find.text('TRACK IT'));
      await tester.pumpAndSettle();

      expect(store.items.single.subjectId, isNull);
      expect(store.subjects, isEmpty);
      expect(find.text('NO DATE'), findsOne);
    }, size: const Size(430, 1200));
  });

  group('subjects', () {
    appTest('the manage panel lists subjects', (tester, store) async {
      await tester.tap(find.text('MANAGE SUBJECTS'));
      await tester.pumpAndSettle();

      expect(find.text('SUBJECTS'), findsOne);
      expect(find.text('Organic Chemistry'), findsOne);
      expect(find.text('Medieval History'), findsOne);
    }, seed: _seed(), size: const Size(430, 1600));

    appTest('recolouring cycles through the palette', (tester, store) async {
      await tester.tap(find.text('MANAGE SUBJECTS'));
      await tester.pumpAndSettle();

      final before = store.subjects.first.color;
      await tester.tap(
        find.bySemanticsLabel('Change colour for Organic Chemistry'),
      );
      await tester.pumpAndSettle();

      expect(store.subjects.first.color, isNot(before));
      expect(kPalette, contains(store.subjects.first.color));
    }, seed: _seed(), size: const Size(430, 1600));

    appTest('deleting a subject unfiles its work instead of losing it', (
      tester,
      store,
    ) async {
      await tester.tap(find.text('MANAGE SUBJECTS'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.bySemanticsLabel('Delete subject Organic Chemistry'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('DELETE SUBJECT'));
      await tester.pumpAndSettle();

      expect(store.subjects.any((s) => s.id == 's1'), isFalse);
      // Both of its assignments are still there, now unfiled.
      expect(store.items.firstWhere((a) => a.id == 'a1').subjectId, isNull);
      expect(store.items.firstWhere((a) => a.id == 'a4').subjectId, isNull);
      expect(find.text('Reaction mechanisms problem set'), findsOne);
    }, seed: _seed(), size: const Size(430, 1600));
  });

  group('backup screen', () {
    appTest('opens and offers import, export and reminders', (
      tester,
      store,
    ) async {
      await tester.tap(find.text('BACKUP & REMINDERS'));
      await tester.pumpAndSettle();

      expect(find.text('Backup'), findsOne);
      expect(find.text('EXPORT'), findsOne);
      expect(find.text('IMPORT'), findsOne);
      expect(find.text('REMINDERS'), findsOne);
      expect(find.text('SAVE .JSON FILE'), findsOne);
      expect(find.text('CLEAR ALL DATA'), findsOne);
    }, seed: _seed(), size: const Size(430, 1600));

    appTest('pasting a backup and merging brings the work in', (
      tester,
      store,
    ) async {
      await tester.tap(find.text('BACKUP & REMINDERS'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, _seed());
      await tester.pumpAndSettle();

      await tester.tap(find.text('MERGE'));
      await tester.pumpAndSettle();

      expect(store.items.length, 6);
      expect(store.subjects.length, 3);
    }, size: const Size(430, 1600));

    appTest('clearing everything asks first', (tester, store) async {
      await tester.tap(find.text('BACKUP & REMINDERS'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('CLEAR ALL DATA'));
      await tester.pumpAndSettle();
      expect(find.text('Erase everything?'), findsOne);

      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      expect(store.items, isNotEmpty);

      await tester.tap(find.text('CLEAR ALL DATA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ERASE'));
      await tester.pumpAndSettle();

      expect(store.items, isEmpty);
      expect(store.subjects, isEmpty);
    }, seed: _seed(), size: const Size(430, 1600));
  });

  group('layout', () {
    // Overflow throws inside a widget test, so building at each size *is* the
    // assertion. These are the extremes the app has to survive: a small phone
    // through to a maximised desktop window.
    for (final (label, size) in const [
      ('small phone', Size(360, 640)),
      ('tall phone', Size(430, 932)),
      ('tablet', Size(834, 1112)),
      ('desktop', Size(1512, 945)),
      ('wide desktop', Size(2560, 1440)),
    ]) {
      appTest('renders on a $label without overflowing', (
        tester,
        store,
      ) async {
        expect(tester.takeException(), isNull);

        // Expanding a card puts the densest thing on screen.
        await tester.tap(find.text('Reaction mechanisms problem set'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }, seed: _seed(), size: size);
    }

    appTest('the add panel survives a narrow phone', (tester, store) async {
      await tester.tap(find.bySemanticsLabel('Add assignment'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('NEW ASSIGNMENT'), findsOne);
    }, seed: _seed(), size: const Size(320, 900));
  });
}
