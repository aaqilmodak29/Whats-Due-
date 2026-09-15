import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whats_due/main.dart';
import 'package:whats_due/bands.dart';
import 'package:whats_due/models.dart';
import 'package:whats_due/store.dart';
import 'package:whats_due/theme.dart';
import 'package:whats_due/ui/assignment_card.dart';
import 'package:whats_due/ui/horizon.dart';

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
  String? tab,
  bool dark = false,
  bool onboarded = true,
  List<GradeBand>? bands,
}) {
  testWidgets(description, (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    final semantics = tester.ensureSemantics();
    try {
      SharedPreferences.setMockInitialValues({
        AppStore.storageKey: ?seed,
        if (dark) 'coursework:dark': true,
        // The first-run question stands in front of everything, so tests opt
        // out of it unless they are the ones testing it.
        if (onboarded) 'coursework:onboarded': true,
      });
      final store = AppStore();
      await store.init();
      if (bands != null) store.setBands(bands);
      await tester.pumpWidget(WhatsDueApp(store: store));
      await tester.pumpAndSettle();
      // The app opens on Assignments; anything testing another destination has
      // to name it rather than assuming that page is on screen.
      if (tab != null) await goTo(tester, tab);
      await body(tester, store);
    } finally {
      semantics.dispose();
    }
  });
}

/// Taps a bottom-nav destination by the label a screen reader would announce.
///
/// Matches the current-page label too, so a test can name the destination it
/// needs without caring which one the app happens to open on.
Future<void> goTo(WidgetTester tester, String label) async {
  await tester.tap(
    find.bySemanticsLabel(RegExp('^(Go to $label|$label, current page)\$')),
  );
  await tester.pumpAndSettle();
}

/// The shell's pager, not the horizon strip's.
///
/// There are two now, nested: swiping the strip pages the fortnight, swiping
/// anywhere else changes destination. The shell's is the outer one, so it comes
/// first in a depth-first walk.
Finder _shellPager() => find.byType(PageView).first;

/// Text fields behind a dialog would otherwise be matched first.
/// The edit sheet's title box — the first field in the dialog.
///
/// Scoped to `.first` rather than the only TextField in the dialog: the sheet
/// also carries the weight and marks boxes, so an unqualified match is
/// ambiguous.
Finder dialogField() => find
    .descendant(of: find.byType(Dialog), matching: find.byType(TextField))
    .first;

void main() {
  group('assignments', () {
    appTest('leads with the wordmark and the triage line', (
      tester,
      store,
    ) async {
      expect(find.text("What's due"), findsOne);
      expect(find.text('COURSEWORK'), findsOne);

      // One overdue; three of the five open items fall inside seven days; the
      // undated one is open but lands in neither bucket.
      expect(find.text('1 OVERDUE · 3 DUE WITHIN 7 DAYS · 5 OPEN'), findsOne);
    }, seed: _seed());

    appTest(
      'lists every open assignment behind its own tab',
      (tester, store) async {
        expect(find.text('OPEN (5)'), findsOne);
        expect(find.text('SUBMITTED (1)'), findsOne);

        expect(find.text('Reaction mechanisms problem set'), findsOne);
        expect(find.text('Comparative essay'), findsOne);
        expect(find.text('Read chapters 4-6'), findsOne);
        // Submitted work is behind the other tab.
        expect(find.text('Week 3 problem set'), findsNothing);
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'sorts soonest first and puts undated work last',
      (tester, store) async {
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
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'countdowns read as words, not raw dates',
      (tester, store) async {
        expect(find.text('2 DAYS LATE'), findsOne);
        expect(find.text('TOMORROW'), findsOne);
        expect(find.text('NO DATE'), findsOne);
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest('the empty state explains itself', (tester, store) async {
      expect(find.text('Nothing tracked yet'), findsOne);
      expect(find.text('OPEN (0)'), findsOne);
      // No subjects means no filter chips at all.
      expect(find.textContaining('ALL '), findsNothing);
    }, tab: 'Assignments');

    appTest(
      'subject chips filter the list',
      (tester, store) async {
        expect(find.text('ORGANIC CHEMISTRY 2'), findsOne);
        await tester.tap(find.text('ORGANIC CHEMISTRY 2'));
        await tester.pumpAndSettle();

        expect(find.text('Reaction mechanisms problem set'), findsOne);
        expect(find.text('Lab report titration'), findsOne);
        expect(find.text('Comparative essay'), findsNothing);

        await tester.tap(find.text('ALL 5'));
        await tester.pumpAndSettle();
        expect(find.text('Comparative essay'), findsOne);
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'the submitted tab shows finished work',
      (tester, store) async {
        await tester.tap(find.text('SUBMITTED (1)'));
        await tester.pumpAndSettle();

        expect(find.text('Week 3 problem set'), findsOne);
        expect(find.text('SUBMITTED'), findsOne);
        expect(find.text('Comparative essay'), findsNothing);
      },
      seed: _seed(),
      tab: 'Assignments',
    );
  });

  group('the horizon strip', () {
    // In the seed, +1 has one deadline and +4 has two.
    String isoIn(int days) =>
        formatIsoDate(midnight().add(Duration(days: days)));

    appTest('opens on the fortnight containing today, starting Monday', (
      tester,
      store,
    ) async {
      const months = [
        'JAN',
        'FEB',
        'MAR',
        'APR',
        'MAY',
        'JUN',
        'JUL',
        'AUG',
        'SEP',
        'OCT',
        'NOV',
        'DEC',
      ];
      // The page starts on this week's Monday, not on today — which is the
      // whole point: the Monday just gone stays visible.
      final start = mondayOf(midnight());
      final end = start.add(const Duration(days: 13));
      expect(start.weekday, DateTime.monday);
      // The month is named once when both ends share it.
      final expected = start.month == end.month
          ? '${start.day} → ${end.day} ${months[end.month - 1]}'
          : '${start.day} ${months[start.month - 1]} → '
                '${end.day} ${months[end.month - 1]}';

      expect(find.text(expected), findsOne);
      expect(find.text('THIS FORTNIGHT'), findsOne);
      // The way back is only offered once you have moved off it.
      expect(find.text('BACK TO TODAY'), findsNothing);
    }, seed: _seed());

    appTest('slides a whole fortnight at a time, and back to today', (
      tester,
      store,
    ) async {
      final strip = find.descendant(
        of: find.byType(HorizonStrip),
        matching: find.byType(PageView),
      );
      final start = mondayOf(midnight());

      await tester.fling(strip, const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      // Two weeks on, still a Monday.
      final next = start.add(const Duration(days: 14));
      expect(find.text('THIS FORTNIGHT'), findsNothing);
      expect(find.text('BACK TO TODAY'), findsOne);

      // And two back from there lands on the fortnight before this one.
      await tester.fling(strip, const Offset(400, 0), 1000);
      await tester.pumpAndSettle();
      await tester.fling(strip, const Offset(400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('BACK TO TODAY'), findsOne);

      await tester.tap(find.bySemanticsLabel('Back to this fortnight'));
      await tester.pumpAndSettle();
      expect(find.text('THIS FORTNIGHT'), findsOne);
      expect(next.weekday, DateTime.monday);
    }, seed: _seed());

    appTest('labels every column with its weekday', (tester, store) async {
      // Fourteen columns means every letter of a week, twice.
      final letters = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .where((s) => s.length == 1 && 'MTWFS'.contains(s))
          .length;
      expect(letters, greaterThanOrEqualTo(14));
    }, seed: _seed());

    appTest('a divider marks each Monday, and never the first column', (
      tester,
      store,
    ) async {
      final start = mondayOf(midnight());
      // A Monday-aligned fortnight holds exactly two Mondays, and the first is
      // the leading column — so exactly one divider, always. Before the strip
      // was aligned this count moved with the weekday.
      final dividers = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('week-start-'),
      );
      expect(dividers, findsOne);
      expect(
        find.byKey(
          ValueKey(
            'week-start-${formatIsoDate(start.add(const Duration(days: 7)))}',
          ),
        ),
        findsOne,
      );

      // Never on the leading column: there is nothing to its left.
      expect(
        find.byKey(ValueKey('week-start-${formatIsoDate(start)}')),
        findsNothing,
      );
    }, seed: _seed());

    appTest('a day with two deadlines carries a count', (tester, store) async {
      expect(
        find.descendant(
          of: find.byType(HorizonStrip),
          matching: find.text('2'),
        ),
        findsOne,
      );
    }, seed: _seed());

    appTest('tapping a day filters the list to it', (tester, store) async {
      await tester.tap(
        find.bySemanticsLabel(
          '2 due ${longDate(isoIn(4))}, tap to show only these',
        ),
      );
      await tester.pumpAndSettle();

      // Only the two due that day survive.
      expect(find.text('Regression assignment'), findsOne);
      expect(find.text('Lab report titration'), findsOne);
      expect(find.text('Comparative essay'), findsNothing);
      expect(find.text('Reaction mechanisms problem set'), findsNothing);

      // And the reason is stated, with a way out.
      expect(find.textContaining('SHOW ALL'), findsOne);
    }, seed: _seed());

    appTest('tapping the same day again clears it', (tester, store) async {
      // The strip sits on the page it filters, so it holds the selection and
      // the same column is the way back out.
      final label = '2 due ${longDate(isoIn(4))}, tap to show only these';
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pumpAndSettle();
      expect(find.text('Comparative essay'), findsNothing);

      await tester.tap(
        find.bySemanticsLabel('Clear the filter on ${longDate(isoIn(4))}'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Comparative essay'), findsOne);
    }, seed: _seed());

    appTest('SHOW ALL clears the filter too', (tester, store) async {
      await tester.tap(
        find.bySemanticsLabel(
          '2 due ${longDate(isoIn(4))}, tap to show only these',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Clear the day filter'));
      await tester.pumpAndSettle();
      expect(find.text('Comparative essay'), findsOne);
    }, seed: _seed());

    appTest('an empty day is inert, not a route to an empty list', (
      tester,
      store,
    ) async {
      // Day +2 has nothing due, so it exposes no tappable semantics at all.
      expect(
        find.bySemanticsLabel(RegExp('due ${longDate(isoIn(2))}')),
        findsNothing,
      );
    }, seed: _seed());

    appTest('switching to Submitted drops the day filter', (
      tester,
      store,
    ) async {
      await tester.tap(
        find.bySemanticsLabel(
          '2 due ${longDate(isoIn(4))}, tap to show only these',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('SHOW ALL'), findsOne);

      await tester.tap(find.text('SUBMITTED (1)'));
      await tester.pumpAndSettle();

      // The strip only charts unsubmitted work, so keeping the filter would
      // show an empty list for no stated reason.
      expect(find.textContaining('SHOW ALL'), findsNothing);
      expect(find.text('Week 3 problem set'), findsOne);
    }, seed: _seed());

    appTest('the empty state explains a day filter that matches nothing', (
      tester,
      store,
    ) async {
      // The chip row scrolls, and this one sits off the right edge of a phone.
      // Tapping it unscrolled quietly hits nothing, which is how an earlier
      // version of this test passed while never applying the filter at all.
      await tester.ensureVisible(find.text('STATISTICS 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('STATISTICS 1'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.bySemanticsLabel(
          '2 due ${longDate(isoIn(4))}, tap to show only these',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Regression assignment'), findsOne);
      expect(find.text('Lab report titration'), findsNothing);
    }, seed: _seed());
  });

  group('a card', () {
    appTest(
      'expands to reveal tasks and actions',
      (tester, store) async {
        await tester.tap(find.text('Reaction mechanisms problem set'));
        await tester.pumpAndSettle();

        expect(find.text('Q1-Q5'), findsOne);
        expect(find.text('Q6-Q10'), findsOne);
        expect(find.text('MARK SUBMITTED'), findsOne);
        expect(find.text('EDIT'), findsOne);
        // Calendar export is gone; reminders are scheduled notifications now.
        expect(find.text('REMIND ME'), findsNothing);
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'a task can be added and ticked',
      (tester, store) async {
        await tester.tap(find.text('Comparative essay'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField).last,
          'Find third source',
        );
        await tester.tap(find.text('ADD'));
        await tester.pumpAndSettle();

        final essay = store.items.firstWhere((a) => a.id == 'a2');
        expect(essay.tasks.single.text, 'Find third source');
        expect(find.text('0/1'), findsOne);

        await tester.tap(find.bySemanticsLabel('Mark task finished'));
        await tester.pumpAndSettle();

        expect(essay.tasks.single.done, isTrue);
        expect(find.text('1/1'), findsOne);
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'a task can be removed',
      (tester, store) async {
        await tester.tap(find.text('Reaction mechanisms problem set'));
        await tester.pumpAndSettle();

        await tester.tap(find.bySemanticsLabel('Remove task Q6-Q10'));
        await tester.pumpAndSettle();

        final a = store.items.firstWhere((x) => x.id == 'a1');
        expect(a.tasks.map((t) => t.text), ['Q1-Q5']);
        expect(find.text('Q6-Q10'), findsNothing);
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'marking submitted moves it to the other tab',
      (tester, store) async {
        await tester.tap(find.text('Comparative essay'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('MARK SUBMITTED'));
        await tester.pumpAndSettle();

        expect(store.items.firstWhere((a) => a.id == 'a2').done, isTrue);
        expect(find.text('OPEN (4)'), findsOne);
        expect(find.text('SUBMITTED (2)'), findsOne);
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'the subject can be reassigned from the card',
      (tester, store) async {
        await tester.tap(find.text('Comparative essay'));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Statistics').last);
        await tester.pumpAndSettle();

        expect(store.items.firstWhere((a) => a.id == 'a2').subjectId, 's2');
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'deleting asks first, then removes it',
      (tester, store) async {
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
      },
      seed: _seed(),
      tab: 'Assignments',
    );
  });

  group('subtasks', () {
    appTest(
      'a task shows its steps only when tapped',
      (tester, store) async {
        await tester.tap(find.text('Reaction mechanisms problem set'));
        await tester.pumpAndSettle();

        // Collapsed: no step field, so the card stays compact.
        expect(find.widgetWithText(TextField, 'Add a step'), findsNothing);

        await tester.tap(find.bySemanticsLabel('Q1-Q5, tap to add steps'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(TextField, 'Add a step'), findsOne);
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'a step can be added, ticked and removed',
      (tester, store) async {
        await tester.tap(find.text('Comparative essay'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).last, 'Draft outline');
        await tester.tap(find.bySemanticsLabel('Add task'));
        await tester.pumpAndSettle();

        final task = store.items.firstWhere((a) => a.id == 'a2').tasks.single;
        await tester.tap(
          find.bySemanticsLabel('Draft outline, tap to add steps'),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Add a step'),
          'Agree the topic',
        );
        // By label, not by text: both buttons read ADD, and the step's renders
        // before the task's in the tree, so `.last` picks the wrong one.
        await tester.ensureVisible(find.bySemanticsLabel('Add step'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Add step'));
        await tester.pumpAndSettle();

        expect(task.subtasks.single.text, 'Agree the topic');
        // The parent now reports its steps rather than a bare tick. Asserted by
        // label, not by the '0/1' text: the card's own task counter reads the
        // same and would match it too.
        expect(
          find.bySemanticsLabel(
            'Draft outline, 0 of 1 steps done, tap to collapse',
          ),
          findsOne,
        );

        await tester.tap(find.bySemanticsLabel('Mark task finished').last);
        await tester.pumpAndSettle();
        expect(task.subtasks.single.done, isTrue);
        expect(task.done, isTrue, reason: 'the only step is done');

        await tester.tap(find.bySemanticsLabel('Remove step Agree the topic'));
        await tester.pumpAndSettle();
        expect(task.subtasks, isEmpty);
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'a task with steps is not finished until they all are',
      (tester, store) async {
        final a = store.items.firstWhere((x) => x.id == 'a1');
        store.addSubtask(a.tasks.first, 'Q1');
        store.addSubtask(a.tasks.first, 'Q2');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Reaction mechanisms problem set'));
        await tester.pumpAndSettle();

        // Q1-Q5 was already ticked, so both its new steps came in ticked and it
        // stays finished; Q6-Q10 was not.
        expect(a.tasks.first.done, isTrue);
        expect(a.tasks.first.subtasks.every((s) => s.done), isTrue);
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'only one task shows its steps at a time',
      (tester, store) async {
        await tester.tap(find.text('Reaction mechanisms problem set'));
        await tester.pumpAndSettle();

        await tester.tap(find.bySemanticsLabel('Q1-Q5, tap to add steps'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(TextField, 'Add a step'), findsOne);

        await tester.tap(find.bySemanticsLabel('Q6-Q10, tap to add steps'));
        await tester.pumpAndSettle();
        // Still one: opening the second closed the first.
        expect(find.widgetWithText(TextField, 'Add a step'), findsOne);
      },
      seed: _seed(),
      tab: 'Assignments',
    );
  });

  group('editing', () {
    appTest(
      'title and due date can both be changed after creation',
      (tester, store) async {
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
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'cancelling changes nothing',
      (tester, store) async {
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
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'a due date can be cleared back to undated',
      (tester, store) async {
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
      },
      seed: _seed(),
      tab: 'Assignments',
    );
  });

  group('adding', () {
    appTest('a new assignment with a brand new subject', (tester, store) async {
      await tester.tap(find.bySemanticsLabel('Add assignment'));
      await tester.pumpAndSettle();

      expect(find.text('NEW ASSIGNMENT'), findsOne);

      await tester.enterText(
        find.widgetWithText(TextField, 'e.g. Comparative essay'),
        'Comparative essay',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+ New subject…').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'e.g. Organic Chemistry'),
        'Organic Chemistry',
      );
      await tester.pumpAndSettle();

      // Search and the due-window chips pushed the panel down far enough that
      // its button starts below the fold on a phone.
      await tester.ensureVisible(find.text('TRACK IT'));
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

    appTest(
      'a blank title is refused rather than creating a nameless card',
      (tester, store) async {
        await tester.tap(find.bySemanticsLabel('Add assignment'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('TRACK IT'));
        await tester.pumpAndSettle();

        expect(store.items, isEmpty);
      },
      size: const Size(430, 1200),
    );

    appTest('an assignment can be filed as Unfiled', (tester, store) async {
      await tester.tap(find.bySemanticsLabel('Add assignment'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'e.g. Comparative essay'),
        'Read chapters 4-6',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('TRACK IT'));
      await tester.pumpAndSettle();

      expect(store.items.single.subjectId, isNull);
      expect(store.subjects, isEmpty);
      expect(find.text('NO DATE'), findsOne);
    }, size: const Size(430, 1200));
  });

  group('subjects', () {
    appTest(
      'a subject can be added from the manage panel',
      (tester, store) async {
        await tester.tap(find.text('MANAGE SUBJECTS'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'e.g. Organic Chemistry'),
          'Reinforcement Learning',
        );
        await tester.tap(find.bySemanticsLabel('Add subject'));
        await tester.pumpAndSettle();

        expect(
          store.subjects.map((s) => s.name),
          contains('Reinforcement Learning'),
        );
        // The field clears so the next one can be typed straight away.
        expect(
          tester
              .widget<TextField>(
                find.widgetWithText(TextField, 'e.g. Organic Chemistry'),
              )
              .controller!
              .text,
          isEmpty,
        );
        // And it shows up as a filter chip immediately.
        expect(find.text('REINFORCEMENT LEARNING 0'), findsOne);
      },
      seed: _seed(),
      size: const Size(430, 2000),
      tab: 'Assignments',
    );

    appTest(
      'a blank name is refused rather than creating a subject',
      (tester, store) async {
        await tester.tap(find.text('MANAGE SUBJECTS'));
        await tester.pumpAndSettle();

        final before = store.subjects.length;
        await tester.enterText(
          find.widgetWithText(TextField, 'e.g. Organic Chemistry'),
          '   ',
        );
        await tester.tap(find.bySemanticsLabel('Add subject'));
        await tester.pumpAndSettle();

        expect(store.subjects.length, before);
      },
      seed: _seed(),
      size: const Size(430, 2000),
      tab: 'Assignments',
    );

    appTest(
      'the chosen colour is the one the subject gets',
      (tester, store) async {
        await tester.tap(find.text('MANAGE SUBJECTS'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.bySemanticsLabel('Use this colour for the new subject').at(5),
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'e.g. Organic Chemistry'),
          'Networks',
        );
        await tester.tap(find.bySemanticsLabel('Add subject'));
        await tester.pumpAndSettle();

        expect(
          store.subjects.firstWhere((s) => s.name == 'Networks').color,
          kPalette[5],
        );
      },
      seed: _seed(),
      size: const Size(430, 2000),
      tab: 'Assignments',
    );

    appTest(
      'the panel says how to add one when there are none',
      (tester, store) async {
        await tester.tap(find.text('MANAGE SUBJECTS'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Name one below'), findsOne);
        // The field is there even with nothing to list.
        expect(find.bySemanticsLabel('Add subject'), findsOne);
      },
      size: const Size(430, 2000),
      tab: 'Assignments',
    );

    appTest(
      'the manage panel lists subjects',
      (tester, store) async {
        await tester.tap(find.text('MANAGE SUBJECTS'));
        await tester.pumpAndSettle();

        expect(find.text('SUBJECTS'), findsOne);
        expect(find.text('Organic Chemistry'), findsOne);
        expect(find.text('Medieval History'), findsOne);
      },
      seed: _seed(),
      size: const Size(430, 2000),
      tab: 'Assignments',
    );

    appTest(
      'recolouring cycles through the palette',
      (tester, store) async {
        await tester.tap(find.text('MANAGE SUBJECTS'));
        await tester.pumpAndSettle();

        final before = store.subjects.first.color;
        await tester.tap(
          find.bySemanticsLabel('Change colour for Organic Chemistry'),
        );
        await tester.pumpAndSettle();

        expect(store.subjects.first.color, isNot(before));
        expect(kPalette, contains(store.subjects.first.color));
      },
      seed: _seed(),
      size: const Size(430, 2000),
      tab: 'Assignments',
    );

    appTest(
      'deleting a subject unfiles its work instead of losing it',
      (tester, store) async {
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
      },
      seed: _seed(),
      size: const Size(430, 2000),
      tab: 'Assignments',
    );
  });

  group('settings', () {
    appTest(
      'orders the sections version-first',
      (tester, store) async {
        // The order is the whole point of the page's layout, and nothing else
        // would notice it drifting: every section renders fine in any position.
        const titles = {
          'VERSION',
          'APPEARANCE',
          'REMINDERS',
          'EXPORT',
          'IMPORT',
          'DANGER',
        };
        final rendered = tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .whereType<String>()
            .where(titles.contains)
            .toList();

        expect(rendered, [
          'VERSION',
          'APPEARANCE',
          'REMINDERS',
          'EXPORT',
          'IMPORT',
          'DANGER',
        ]);
      },
      seed: _seed(),
      size: const Size(430, 2000),
      tab: 'Settings',
    );

    appTest(
      'gathers everything configurable on one page',
      (tester, store) async {
        expect(find.text('Settings'), findsOne);
        expect(find.text('EXPORT'), findsOne);
        expect(find.text('IMPORT'), findsOne);
        expect(find.text('REMINDERS'), findsOne);
        expect(find.text('SAVE .JSON FILE'), findsOne);
        expect(find.text('CLEAR ALL DATA'), findsOne);
      },
      seed: _seed(),
      size: const Size(430, 2000),
      tab: 'Settings',
    );

    appTest(
      'pasting a backup and merging brings the work in',
      (tester, store) async {
        await tester.enterText(find.byType(TextField).last, _seed());
        await tester.pumpAndSettle();

        await tester.tap(find.text('MERGE'));
        await tester.pumpAndSettle();

        expect(store.items.length, 6);
        expect(store.subjects.length, 3);
      },
      size: const Size(430, 2000),
      tab: 'Settings',
    );

    appTest(
      'clearing everything asks first',
      (tester, store) async {
        await tester.ensureVisible(find.text('CLEAR ALL DATA'));
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
      },
      seed: _seed(),
      size: const Size(430, 2000),
      tab: 'Settings',
    );
  });

  group('marks', () {
    appTest(
      'every card shows its mark, filled in or not',
      (tester, store) async {
        // Blank where a mark belongs is indistinguishable from an assignment
        // with no marks at all, so the placeholder always renders.
        expect(find.text('-/-'), findsWidgets);

        final a = store.items.firstWhere((x) => x.id == 'a3');
        store.setMarks(a, outOf: 40.0);
        await tester.pumpAndSettle();
        expect(find.text('-/40'), findsOne);

        store.setMarks(a, earned: 30.0);
        await tester.pumpAndSettle();
        expect(find.text('30/40'), findsOne);
        expect(find.text('-/40'), findsNothing);
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'the countdown keeps its slot once a mark is in',
      (tester, store) async {
        // The mark used to take the countdown's place, so a graded card stopped
        // saying when it was due. It has its own home now, and showing it twice
        // on one card said nothing extra.
        final a = store.items.firstWhere((x) => x.id == 'a3');
        store.setMarks(a, earned: 30.0, outOf: 40.0);
        await tester.pumpAndSettle();

        // Two assignments fall on the same day in the seed, so this has to be
        // scoped to the card that carries the mark.
        final card = find.ancestor(
          of: find.text('Regression assignment'),
          matching: find.byType(AssignmentCard),
        );
        expect(
          find.descendant(of: card, matching: find.text('4 DAYS')),
          findsOne,
        );
        expect(
          find.descendant(of: card, matching: find.text('30/40')),
          findsOne,
        );
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'marks can be entered from the edit sheet',
      (tester, store) async {
        await tester.tap(find.text('Comparative essay'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('EDIT'));
        await tester.pumpAndSettle();

        await tester.enterText(find.bySemanticsLabel('Your score'), '18');
        await tester.enterText(
          find.bySemanticsLabel('Marks the assignment is out of'),
          '20',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('SAVE'));
        await tester.pumpAndSettle();

        final a = store.items.firstWhere((x) => x.id == 'a2');
        expect(a.earned, 18);
        expect(a.outOf, 20);
        expect(a.scored, closeTo(0.9, 1e-9));
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'marks can be set while adding an assignment',
      (tester, store) async {
        // The spec says what it is out of, so it is known at the point of
        // adding — the score arrives weeks later from the EDIT sheet.
        await tester.tap(find.bySemanticsLabel('Add assignment'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'e.g. Comparative essay'),
          'Week 5 quiz',
        );
        await tester.enterText(
          find.bySemanticsLabel('Marks the assignment is out of'),
          '25',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('TRACK IT'));
        await tester.pumpAndSettle();

        final created = store.items.firstWhere((x) => x.title == 'Week 5 quiz');
        expect(created.outOf, 25);
        expect(created.earned, isNull, reason: 'not marked yet');
        expect(created.graded, isFalse);
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'the two fields read in the order you would say them',
      (tester, store) async {
        await tester.tap(find.text('Comparative essay'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('EDIT'));
        await tester.pumpAndSettle();

        // "Out of 40, I got 34." The old pair of "Mark" and "Out of" gave no
        // clue which box was which.
        final labels = tester
            .widgetList<Text>(
              find.descendant(
                of: find.byType(Dialog),
                matching: find.byType(Text),
              ),
            )
            .map((w) => w.data)
            .whereType<String>()
            .where((s) => const {'WORTH', 'MARKS', 'YOUR SCORE'}.contains(s))
            .toList();
        // Worth is gone entirely: weighting is not tracked for now.
        expect(labels, ['MARKS', 'YOUR SCORE']);
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'a score above the marks available is flagged, not blocked',
      (tester, store) async {
        await tester.tap(find.text('Comparative essay'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('EDIT'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.bySemanticsLabel('Marks the assignment is out of'),
          '40',
        );
        await tester.enterText(find.bySemanticsLabel('Your score'), '45');
        await tester.pumpAndSettle();

        // Bonus marks and marking errors both happen, so this is a warning
        // rather than a refusal.
        expect(find.textContaining('more than the 40 marks'), findsOne);

        await tester.tap(find.text('SAVE'));
        await tester.pumpAndSettle();
        expect(store.items.firstWhere((x) => x.id == 'a2').earned, 45);
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'a task carries marks and an estimate',
      (tester, store) async {
        await tester.tap(find.text('Reaction mechanisms problem set'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Q6-Q10, tap to add steps'));
        await tester.pumpAndSettle();

        await tester.enterText(find.bySemanticsLabel('Marks for Q6-Q10'), '15');
        await tester.tap(find.bySemanticsLabel('Estimate 1h'));
        await tester.pumpAndSettle();

        final t = store.items
            .firstWhere((x) => x.id == 'a1')
            .tasks
            .firstWhere((x) => x.id == 't2');
        expect(t.points, 15);
        expect(t.minutes, 60);

        // Tapping the active estimate clears it rather than being a dead end.
        await tester.tap(find.bySemanticsLabel('Clear the 1h estimate'));
        await tester.pumpAndSettle();
        expect(t.minutes, isNull);
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'the grades page totals the marks that came back',
      (tester, store) async {
        store.setMarks(
          store.items.firstWhere((x) => x.id == 'a1'),
          earned: 40.0,
          outOf: 50.0,
        );
        store.setMarks(
          store.items.firstWhere((x) => x.id == 'a4'),
          earned: 8.0,
          outOf: 10.0,
        );
        await tester.pumpAndSettle();

        // Both are Organic Chemistry: 48 of 60, added as marks rather than
        // averaged as percentages.
        expect(find.text('80%'), findsOne);
        expect(find.text('48 of 60 marked · 2 results'), findsOne);
      },
      seed: _seed(),
      tab: 'Grades',
    );

    appTest(
      'an unscored assignment shows as marks still to come',
      (tester, store) async {
        // Not a result, so no average — but it is what makes the projection
        // answerable, so it has to be counted somewhere visible.
        store.setMarks(
          store.items.firstWhere((x) => x.id == 'a1'),
          outOf: 50.0,
        );
        await tester.pumpAndSettle();
        expect(find.text('0 of 0 marked · 50 still to come'), findsOne);
        expect(find.text('—'), findsOne);
      },
      seed: _seed(),
      tab: 'Grades',
    );
  });

  group('today', () {
    appTest(
      'lists a next action per assignment and ticks it off',
      (tester, store) async {
        await tester.tap(find.bySemanticsLabel('Today'));
        await tester.pumpAndSettle();

        // Only a1 has tasks in the seed, so it is the only thing to pick up.
        expect(find.text('Q6-Q10'), findsOne);
        expect(find.text('1 thing to pick up'), findsOne);

        await tester.tap(find.bySemanticsLabel('Mark task finished'));
        await tester.pumpAndSettle();

        expect(
          store.items.firstWhere((x) => x.id == 'a1').tasks.last.done,
          isTrue,
        );
        expect(find.text('Q6-Q10'), findsNothing, reason: 'it is done now');
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'totals the day once tasks are estimated',
      (tester, store) async {
        final a = store.items.firstWhere((x) => x.id == 'a1');
        store.setTaskMinutes(a.tasks.last, 90);
        await tester.pumpAndSettle();

        await tester.tap(find.bySemanticsLabel('Today'));
        await tester.pumpAndSettle();
        expect(find.text('About 1h 30m today'), findsOne);
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'names the next step when a task has been broken down',
      (tester, store) async {
        final a = store.items.firstWhere((x) => x.id == 'a1');
        store.addSubtask(a.tasks.last, 'Draw the mechanism');
        await tester.pumpAndSettle();

        await tester.tap(find.bySemanticsLabel('Today'));
        await tester.pumpAndSettle();
        // The step is the action; the task is the context around it.
        expect(find.text('Draw the mechanism'), findsOne);
        expect(find.text('Q6-Q10 · REACTION MECHANISMS PROBLEM SET'), findsOne);
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'opening a planned task jumps to its card',
      (tester, store) async {
        await tester.tap(find.bySemanticsLabel('Today'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.bySemanticsLabel(RegExp(r'^Q6-Q10, from Reaction mechanisms')),
        );
        await tester.pumpAndSettle();

        // Back on Open, with that card expanded — its tasks are on screen.
        expect(find.text('Q1-Q5'), findsOne);
        expect(find.widgetWithText(TextField, 'Add a task'), findsOne);
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'says so when there is nothing to pace',
      (tester, store) async {
        await tester.tap(find.bySemanticsLabel('Today'));
        await tester.pumpAndSettle();
        final a = store.items.firstWhere((x) => x.id == 'a1');
        store.toggleTask(a, a.tasks.last);
        await tester.pumpAndSettle();

        expect(find.text('No tasks yet'), findsOne);
      },
      seed: _seed(),
      tab: 'Assignments',
    );
  });

  group('the date picker', () {
    appTest('opens with today readable, not ink on ink', (tester, store) async {
      await tester.tap(find.bySemanticsLabel('Add assignment'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Pick a due date'));
      await tester.pumpAndSettle();

      // The calendar is up, and today is the selection it opened on.
      expect(find.byType(DatePickerDialog), findsOne);

      // Proves the themed properties are actually reaching the dialog, not
      // merely correct in isolation: a perfect theme nothing calls would look
      // identical to every unit test.
      final theme = Theme.of(
        tester.element(find.byType(DatePickerDialog)),
      ).datePickerTheme;
      const selected = {WidgetState.selected};
      expect(
        theme.todayForegroundColor!.resolve(selected),
        C.onInk,
        reason: 'today, while selected, must not be painted ink on ink',
      );
      expect(theme.todayBackgroundColor!.resolve(selected), C.ink);
    }, seed: _seed());
  });

  group('swiping between destinations', () {
    appTest('a swipe moves to the next destination', (tester, store) async {
      expect(find.text('Assignments, current page'), findsNothing);

      await tester.fling(_shellPager(), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Grades'), findsWidgets);
      // The bar follows the swipe rather than being a separate source of truth.
      expect(find.bySemanticsLabel('Grades, current page'), findsOne);
    }, seed: _seed());

    appTest('swiping back returns to the list as it was left', (
      tester,
      store,
    ) async {
      await tester.tap(find.text('SUBMITTED (1)'));
      await tester.pumpAndSettle();

      await tester.fling(_shellPager(), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      await tester.fling(_shellPager(), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Week 3 problem set'), findsOne);
      expect(find.bySemanticsLabel('Assignments, current page'), findsOne);
    }, seed: _seed());

    appTest('tapping the bar still works and agrees with the pager', (
      tester,
      store,
    ) async {
      await goTo(tester, 'Settings');
      expect(find.bySemanticsLabel('Settings, current page'), findsOne);
      expect(find.text('Settings'), findsWidgets);
    }, seed: _seed());
  });

  group('search and due windows', () {
    Finder searchBox() => find.widgetWithText(TextField, 'Search assignments');

    appTest(
      'typing narrows the list to matching titles',
      (tester, store) async {
        await tester.enterText(searchBox(), 'essay');
        await tester.pumpAndSettle();

        expect(find.text('Comparative essay'), findsOne);
        expect(find.text('Reaction mechanisms problem set'), findsNothing);
        expect(find.text('Regression assignment'), findsNothing);
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'the search can be cleared back to everything',
      (tester, store) async {
        await tester.enterText(searchBox(), 'essay');
        await tester.pumpAndSettle();
        expect(find.text('Regression assignment'), findsNothing);

        await tester.tap(find.bySemanticsLabel('Clear the search'));
        await tester.pumpAndSettle();
        expect(find.text('Regression assignment'), findsOne);
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'a search matching nothing says so rather than going blank',
      (tester, store) async {
        await tester.enterText(searchBox(), 'zzzz');
        await tester.pumpAndSettle();
        expect(find.text('Nothing here'), findsOne);
        expect(find.textContaining('zzzz'), findsWidgets);
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'a due window narrows the list, cumulatively',
      (tester, store) async {
        // a1 is overdue, a2 is tomorrow, a3 and a4 are four days out.
        await tester.tap(find.bySemanticsLabel('Show work due within 7 days'));
        await tester.pumpAndSettle();

        expect(find.text('Comparative essay'), findsOne);
        expect(find.text('Regression assignment'), findsOne);
        // Undated work has no date to be inside a window.
        expect(find.text('Read chapters 4-6'), findsNothing);
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'overdue work survives every window',
      (tester, store) async {
        // A filter that hides something already late is how it gets forgotten.
        await tester.tap(find.bySemanticsLabel('Show work due within 7 days'));
        await tester.pumpAndSettle();
        expect(find.text('Reaction mechanisms problem set'), findsOne);

        // The window chips scroll sideways, so the last one starts off the
        // right edge of a phone — tapping where it is not is how a test like
        // this ends up asserting nothing.
        final later = find.bySemanticsLabel(
          'Show work due more than 2 months out',
        );
        await tester.ensureVisible(later);
        await tester.pumpAndSettle();
        await tester.tap(later);
        await tester.pumpAndSettle();
        expect(find.text('Reaction mechanisms problem set'), findsOne);
        // And the window really did apply, rather than the tap missing: work
        // due tomorrow is not work due more than two months out.
        expect(find.text('Comparative essay'), findsNothing);
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'tapping the active window again clears it',
      (tester, store) async {
        await tester.tap(find.bySemanticsLabel('Show work due within 7 days'));
        await tester.pumpAndSettle();
        expect(find.text('Read chapters 4-6'), findsNothing);

        await tester.tap(find.bySemanticsLabel('Show work due within 7 days'));
        await tester.pumpAndSettle();
        expect(find.text('Read chapters 4-6'), findsOne);
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'search and subject filter both apply',
      (tester, store) async {
        await tester.ensureVisible(find.text('ORGANIC CHEMISTRY 2'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ORGANIC CHEMISTRY 2'));
        await tester.pumpAndSettle();

        await tester.enterText(searchBox(), 'lab');
        await tester.pumpAndSettle();

        expect(find.text('Lab report titration'), findsOne);
        expect(find.text('Reaction mechanisms problem set'), findsNothing);
      },
      seed: _seed(),
      tab: 'Assignments',
    );
  });

  group('grades detail', () {
    appTest(
      'a subject opens to show each result behind its total',
      (tester, store) async {
        store.setMarks(
          store.items.firstWhere((x) => x.id == 'a1'),
          earned: 30.0,
          outOf: 40.0,
        );
        store.setMarks(
          store.items.firstWhere((x) => x.id == 'a4'),
          earned: 8.0,
          outOf: 10.0,
        );
        await tester.pumpAndSettle();

        // Closed, only the total shows.
        expect(find.text('38 of 50 marked · 2 results'), findsOne);
        expect(find.text('Lab report titration'), findsNothing);

        await tester.tap(
          find.bySemanticsLabel(RegExp('^Organic Chemistry, 76%')),
        );
        await tester.pumpAndSettle();

        // Open, each assignment shows its own mark and percentage.
        expect(find.text('Reaction mechanisms problem set'), findsOne);
        expect(find.text('Lab report titration'), findsOne);
        expect(find.text('30/40'), findsOne);
        expect(find.text('8/10'), findsOne);
        expect(find.text('75%'), findsOne);
      },
      seed: _seed(),
      tab: 'Grades',
    );

    appTest(
      'only one subject is open at a time',
      (tester, store) async {
        store.setMarks(
          store.items.firstWhere((x) => x.id == 'a1'),
          earned: 30.0,
          outOf: 40.0,
        );
        store.setMarks(
          store.items.firstWhere((x) => x.id == 'a3'),
          earned: 20.0,
          outOf: 25.0,
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.bySemanticsLabel(RegExp('^Organic Chemistry, 75%')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Reaction mechanisms problem set'), findsOne);

        await tester.tap(find.bySemanticsLabel(RegExp('^Statistics, 80%')));
        await tester.pumpAndSettle();
        expect(find.text('Regression assignment'), findsOne);
        expect(find.text('Reaction mechanisms problem set'), findsNothing);
      },
      seed: _seed(),
      tab: 'Grades',
    );
  });

  group('the first-run question', () {
    appTest(
      'stands in front of the app until it is answered',
      (tester, store) async {
        expect(find.text('ONE QUESTION'), findsOne);
        // Nothing behind it is reachable, so it cannot be walked past.
        expect(find.text('Reaction mechanisms problem set'), findsNothing);
        expect(find.bySemanticsLabel('Go to Grades'), findsNothing);
      },
      seed: _seed(),
      onboarded: false,
    );

    appTest(
      'saying no goes straight to percentages',
      (tester, store) async {
        await tester.tap(find.text('NO, PERCENTAGES'));
        await tester.pumpAndSettle();

        expect(store.onboarded, isTrue);
        expect(store.usesLetterGrades, isFalse);
        expect(find.text('Reaction mechanisms problem set'), findsOne);
      },
      seed: _seed(),
      onboarded: false,
    );

    appTest(
      'saying yes offers the bands, already filled in',
      (tester, store) async {
        await tester.tap(find.text('YES, SET THEM UP'));
        await tester.pumpAndSettle();

        expect(store.usesLetterGrades, isTrue);
        expect(find.text('YOUR BANDS'), findsOne);
        expect(find.widgetWithText(TextField, 'High Distinction'), findsOne);
        // Still not past the question until it is dismissed.
        expect(store.onboarded, isFalse);

        await tester.tap(find.text('START TRACKING'));
        await tester.pumpAndSettle();
        expect(store.onboarded, isTrue);
        expect(find.text('Reaction mechanisms problem set'), findsOne);
      },
      seed: _seed(),
      size: const Size(430, 1600),
      onboarded: false,
    );

    appTest('is never asked twice', (tester, store) async {
      expect(find.text('ONE QUESTION'), findsNothing);
      expect(find.text('Reaction mechanisms problem set'), findsOne);
    }, seed: _seed());
  });

  group('letter grades', () {
    appTest(
      'a band shows beside the mark on a card',
      (tester, store) async {
        store.setMarks(
          store.items.firstWhere((x) => x.id == 'a3'),
          earned: 34.0,
          outOf: 40.0,
        );
        await tester.pumpAndSettle();

        // 85% is a High Distinction under the default bands.
        expect(find.text('34/40'), findsOne);
        expect(find.text('HIGH DISTINCTION'), findsOne);
      },
      seed: _seed(),
      bands: kDefaultBands,
      tab: 'Assignments',
    );

    appTest(
      'and nothing shows when letter grading is off',
      (tester, store) async {
        store.setMarks(
          store.items.firstWhere((x) => x.id == 'a3'),
          earned: 34.0,
          outOf: 40.0,
        );
        await tester.pumpAndSettle();

        expect(find.text('34/40'), findsOne);
        expect(find.text('HIGH DISTINCTION'), findsNothing);
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'the edit sheet names the band as the score is typed',
      (tester, store) async {
        await tester.tap(find.text('Comparative essay'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('EDIT'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.bySemanticsLabel('Marks the assignment is out of'),
          '40',
        );
        await tester.enterText(find.bySemanticsLabel('Your score'), '26');
        await tester.pumpAndSettle();

        // 65 of 100 is exactly the Credit boundary, which belongs to Credit.
        expect(find.textContaining('a Credit'), findsOne);
      },
      seed: _seed(),
      bands: kDefaultBands,
      tab: 'Assignments',
    );

    appTest(
      'turning them on from Settings is enough to set them up',
      (tester, store) async {
        expect(store.usesLetterGrades, isFalse);
        await tester.tap(find.bySemanticsLabel('Letter grades'));
        await tester.pumpAndSettle();

        expect(store.usesLetterGrades, isTrue);
        expect(find.text('LETTER GRADES ON'), findsOne);
        // The editor comes with it, filled in and editable.
        expect(find.widgetWithText(TextField, 'Pass'), findsOne);

        await tester.enterText(find.widgetWithText(TextField, 'Pass'), 'P');
        await tester.pumpAndSettle();
        expect(store.bands[1].name, 'P');
      },
      seed: _seed(),
      size: const Size(430, 1400),
      tab: 'Settings',
    );

    appTest(
      'turning them off again leaves the percentages alone',
      (tester, store) async {
        await tester.tap(find.bySemanticsLabel('Letter grades'));
        await tester.pumpAndSettle();

        expect(store.bands, isEmpty);
        expect(find.text('PERCENTAGES ONLY'), findsOne);
      },
      seed: _seed(),
      size: const Size(430, 1400),
      bands: kDefaultBands,
      tab: 'Settings',
    );
  });

  group('goals', () {
    appTest(
      'a goal can be set on an assignment as it is added',
      (tester, store) async {
        await tester.tap(find.bySemanticsLabel('Add assignment'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'e.g. Comparative essay'),
          'Week 5 quiz',
        );
        await tester.enterText(
          find.bySemanticsLabel('Marks the assignment is out of'),
          '25',
        );
        await tester.enterText(find.bySemanticsLabel('Goal score'), '20');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('TRACK IT'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('TRACK IT'));
        await tester.pumpAndSettle();

        final made = store.items.firstWhere((x) => x.title == 'Week 5 quiz');
        expect(made.outOf, 25);
        expect(made.goal, 20);
        expect(made.metGoal, isNull, reason: 'no score yet, so neither');
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'and the edit sheet says how far short a result fell',
      (tester, store) async {
        final a = store.items.firstWhere((x) => x.id == 'a2');
        store.setMarks(a, outOf: 40.0);
        store.setGoal(a, 30.0);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Comparative essay'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('EDIT'));
        await tester.pumpAndSettle();
        await tester.enterText(find.bySemanticsLabel('Your score'), '22');
        await tester.pumpAndSettle();

        expect(find.textContaining('8 short of the 30 you wanted'), findsOne);
      },
      seed: _seed(),
      tab: 'Assignments',
    );

    appTest(
      'a subject goal back-solves what is still needed',
      (tester, store) async {
        // Their worked example: three assignments worth 30, 30 and 40. Score 20
        // on the first and an 85 goal needs 65 of the remaining 70.
        final s = store.subjects.first;
        final first = store.addAssignment(
          title: 'One',
          subjectId: s.id,
          outOf: 30,
        );
        store.addAssignment(title: 'Two', subjectId: s.id, outOf: 30);
        store.addAssignment(title: 'Three', subjectId: s.id, outOf: 40);
        store.setMarks(first, earned: 20.0);
        store.setSubjectGoal(s, 85);
        await tester.pumpAndSettle();

        expect(find.textContaining('65 more of the 70 left'), findsOne);
        // Named as the band it is, since bands are configured.
        expect(find.textContaining('Goal High Distinction'), findsOne);
      },
      seed: _seed(),
      bands: kDefaultBands,
      tab: 'Grades',
    );

    appTest(
      'a goal already banked says so rather than a number',
      (tester, store) async {
        final s = store.subjects.first;
        store.setMarks(
          store.addAssignment(title: 'Big one', subjectId: s.id, outOf: 60),
          earned: 60.0,
        );
        store.addAssignment(title: 'Rest', subjectId: s.id, outOf: 40);
        store.setSubjectGoal(s, 50);
        await tester.pumpAndSettle();

        expect(find.textContaining('Goal 50% — already there'), findsOne);
      },
      seed: _seed(),
      tab: 'Grades',
    );

    appTest(
      'a goal that can no longer be reached says that too',
      (tester, store) async {
        final s = store.subjects.first;
        store.setMarks(
          store.addAssignment(title: 'Bombed it', subjectId: s.id, outOf: 60),
          earned: 5.0,
        );
        store.addAssignment(title: 'Rest', subjectId: s.id, outOf: 40);
        store.setSubjectGoal(s, 85);
        await tester.pumpAndSettle();

        expect(find.textContaining('out of reach'), findsOne);
      },
      seed: _seed(),
      tab: 'Grades',
    );

    appTest(
      'the goal sheet writes a percentage onto the subject',
      (tester, store) async {
        final s = store.subjects.first;
        store.addAssignment(title: 'One', subjectId: s.id, outOf: 50);
        await tester.pumpAndSettle();

        await tester.tap(find.bySemanticsLabel('Set a goal for ${s.name}'));
        await tester.pumpAndSettle();
        // The bands are offered as shortcuts onto the same percentage field.
        await tester.tap(
          find.bySemanticsLabel('Aim for Distinction, 75 percent'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Save the goal'));
        await tester.pumpAndSettle();

        expect(store.subjects.first.goalPercent, 75);
      },
      seed: _seed(),
      bands: kDefaultBands,
      tab: 'Grades',
    );

    appTest(
      'Grades spells out what each band would take, in marks',
      (tester, store) async {
        final s = store.subjects.first;
        store.setMarks(
          store.addAssignment(title: 'One', subjectId: s.id, outOf: 50),
          earned: 30.0,
        );
        store.addAssignment(title: 'Two', subjectId: s.id, outOf: 50);
        await tester.pumpAndSettle();

        await tester.tap(find.bySemanticsLabel(RegExp('^${s.name},')));
        await tester.pumpAndSettle();

        expect(find.text('MARKS NEEDED'), findsOne);
        // 30 banked of 100: a Pass at 50 needs 20 more of the 50 left.
        expect(find.text('20 OF 50'), findsOne);
        // Fail opens at 0, which cannot be lost.
        expect(find.text('SAFE'), findsOne);
        // A High Distinction would take 55 of the 50 left — gone.
        expect(find.text('OUT OF REACH'), findsOne);
      },
      seed: _seed(),
      bands: kDefaultBands,
      tab: 'Grades',
    );
  });

  group('dark mode', () {
    // The palette is global mutable state, so a test that leaves it dark would
    // silently change what every later test renders.
    tearDown(() => C.palette = Palette.light);

    appTest(
      'the toggle swaps the palette and persists',
      (tester, store) async {
        expect(C.isDark, isFalse);

        await tester.tap(find.bySemanticsLabel('Dark mode'));
        await tester.pumpAndSettle();

        expect(store.darkMode, isTrue);
        expect(C.isDark, isTrue);
        expect(find.text('DARK'), findsOne);

        // Survives a reload, which is the whole point of persisting it.
        final reloaded = AppStore();
        await reloaded.init();
        expect(reloaded.darkMode, isTrue);
        expect(C.isDark, isTrue);
      },
      seed: _seed(),
      size: const Size(430, 2600),
      tab: 'Settings',
    );

    appTest(
      'the app actually repaints, rather than keeping a stale theme',
      (tester, store) async {
        // buildTheme() reads the palette in force, so a MaterialApp constructed
        // outside the listenable would hold its original colours for ever.
        final before = Theme.of(
          tester.element(find.bySemanticsLabel('Dark mode')),
        );
        expect(before.scaffoldBackgroundColor, Palette.light.paper);

        await tester.tap(find.bySemanticsLabel('Dark mode'));
        await tester.pumpAndSettle();

        final after = Theme.of(
          tester.element(find.bySemanticsLabel('Dark mode')),
        );
        expect(after.scaffoldBackgroundColor, Palette.night.paper);
        expect(after.brightness, Brightness.dark);
      },
      seed: _seed(),
      size: const Size(430, 2600),
      tab: 'Settings',
    );

    appTest(
      'opens dark when it was left dark, with no flash of light',
      (tester, store) async {
        // The palette is applied during init, before the first frame.
        expect(store.darkMode, isTrue);
        expect(C.isDark, isTrue);
        expect(
          Theme.of(tester.element(find.text("What's due"))).brightness,
          Brightness.dark,
        );
      },
      seed: _seed(),
      dark: true,
    );

    test('what sits on ink and on the highlighter inverts with the palette', () {
      // Reversing out to white would be invisible after dark, where ink is
      // near-white; the highlighter does not move, so what sits on it does not
      // either.
      expect(Palette.light.onInk, const Color(0xFFFFFFFF));
      expect(Palette.night.onInk, Palette.night.paper);
      expect(Palette.light.mark, Palette.night.mark);
      expect(Palette.light.onMark, Palette.night.onMark);
    });
  });

  group('layout', () {
    // Overflow throws inside a widget test, so building at each size *is* the
    // assertion. These are the extremes the app has to survive: a small phone
    // through to a tablet held in landscape. The desktop build is gone, but
    // the 620px column still has to behave when it is given far more room
    // than it wants.
    for (final (label, size) in const [
      ('small phone', Size(360, 640)),
      ('tall phone', Size(430, 932)),
      ('tablet', Size(834, 1112)),
      ('landscape tablet', Size(1512, 945)),
      ('very wide', Size(2560, 1440)),
    ]) {
      appTest(
        'renders on a $label without overflowing',
        (tester, store) async {
          expect(tester.takeException(), isNull);

          // Expanding a card puts the densest thing on screen.
          await tester.tap(find.text('Reaction mechanisms problem set'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
        seed: _seed(),
        size: size,
        tab: 'Assignments',
      );
    }

    appTest(
      'the add panel survives a narrow phone',
      (tester, store) async {
        await tester.tap(find.bySemanticsLabel('Add assignment'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('NEW ASSIGNMENT'), findsOne);
      },
      seed: _seed(),
      size: const Size(320, 900),
    );
  });
}
