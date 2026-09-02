@Tags(['golden'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whats_due/main.dart';
import 'package:whats_due/models.dart';
import 'package:whats_due/store.dart';

/// Rendered snapshots of the design.
///
/// These exist because the design system is load-bearing — two colour channels
/// carrying two meanings, mono-for-data, the horizon strip — and none of that is
/// verifiable by asserting on strings. Regenerate with:
///
/// ```
/// flutter test --update-goldens test/golden_test.dart
/// ```
///
/// Caveat: font rasterisation differs between platforms, so these were captured
/// on Windows and will show diffs if regenerated elsewhere. Treat a diff as
/// "look at the image", not automatically as a bug.

/// The bundled fonts have to be handed to the engine explicitly; a widget test
/// otherwise renders every glyph as the fallback test font and the snapshot
/// tells you nothing about the typography.
Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      final bytes = await File(path).readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await load('Inter', ['assets/fonts/Inter-Variable.ttf']);
  await load('PlexMono', [
    'assets/fonts/IBMPlexMono-Regular.ttf',
    'assets/fonts/IBMPlexMono-SemiBold.ttf',
  ]);

  // The icon font comes from the SDK, not this package, and is not present in a
  // test binary by default — without it every icon renders as a blank box and
  // the snapshot can't tell a missing glyph from a working one.
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.path;
  final iconFont = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (iconFont.existsSync()) {
    await load('MaterialIcons', [iconFont.path]);
  } else {
    // Not fatal: the layout snapshots are still meaningful, but say so loudly
    // rather than quietly shipping boxes.
    // ignore: avoid_print
    print('WARNING: MaterialIcons not found at ${iconFont.path}');
  }
}

String _iso(int offsetDays) =>
    formatIsoDate(midnight().add(Duration(days: offsetDays)));

/// Fixed relative to today so the countdowns read naturally in the snapshot.
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
      'tasks': [
        {'id': 't3', 'text': 'Draft outline', 'done': true},
        {'id': 't4', 'text': 'Find third source', 'done': true},
        {'id': 't5', 'text': 'Write body', 'done': false},
      ],
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
      'title': 'Lab report: titration',
      'subjectId': 's1',
      'due': _iso(4),
      'done': false,
      'tasks': [
        {'id': 't6', 'text': 'Plot results', 'done': false},
      ],
    },
    {
      'id': 'a5',
      'title': 'Hypothesis testing worksheet',
      'subjectId': 's2',
      'due': _iso(9),
      'done': false,
      'tasks': <Object>[],
    },
    {
      'id': 'a6',
      'title': 'Crusades reading response',
      'subjectId': 's3',
      'due': _iso(12),
      'done': false,
      'tasks': <Object>[],
    },
    {
      'id': 'a7',
      'title': 'Read chapters 4-6',
      'subjectId': null,
      'due': '',
      'done': false,
      'tasks': <Object>[],
    },
    {
      'id': 'a8',
      'title': 'Week 3 problem set',
      'subjectId': 's2',
      'due': _iso(-9),
      'done': true,
      'tasks': <Object>[],
    },
  ],
});

Future<AppStore> _boot(WidgetTester tester, Size size, {String? seed}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(
    seed == null ? {} : {AppStore.storageKey: seed},
  );
  final store = AppStore();
  await store.init();
  await tester.pumpWidget(WhatsDueApp(store: store));
  await tester.pumpAndSettle();
  return store;
}

/// Pinned so the snapshots are reproducible. Without this the seeded dates are
/// relative to the real clock, the rendered date line changes every day, and
/// these fail on any day but the one they were captured on.
final _fixedNow = DateTime(2026, 8, 6, 12);

/// Taps a bottom-nav destination. Goldens run without a semantics handle, so
/// this matches the visible label rather than the screen-reader one.
Future<void> _goTo(WidgetTester tester, String label) async {
  await tester.tap(find.text(label.toUpperCase()).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    clock = () => _fixedNow;
    await _loadFonts();
  });

  tearDownAll(() => clock = DateTime.now);

  testWidgets('phone, home', (tester) async {
    await _boot(tester, const Size(430, 932), seed: _seed());
    await expectLater(
      find.byType(WhatsDueApp),
      matchesGoldenFile('goldens/phone-home.png'),
    );
  });

  testWidgets('phone, list', (tester) async {
    await _boot(tester, const Size(430, 932), seed: _seed());
    await _goTo(tester, 'Assignments');
    await expectLater(
      find.byType(WhatsDueApp),
      matchesGoldenFile('goldens/phone-list.png'),
    );
  });

  testWidgets('phone, card expanded', (tester) async {
    await _boot(tester, const Size(430, 932), seed: _seed());
    await _goTo(tester, 'Assignments');
    await tester.tap(find.text('Comparative essay'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(WhatsDueApp),
      matchesGoldenFile('goldens/phone-expanded.png'),
    );
  });

  testWidgets('phone, task steps open', (tester) async {
    final store = await _boot(tester, const Size(430, 932), seed: _seed());
    await _goTo(tester, 'Assignments');
    await tester.tap(find.text('Comparative essay'));
    await tester.pumpAndSettle();

    final task = store.items.firstWhere((a) => a.id == 'a2').tasks.last;
    store.addSubtask(task, 'Pull three sources');
    store.addSubtask(task, 'Draft the argument');
    await tester.pumpAndSettle();
    await tester.tap(
      find.bySemanticsLabel(
        '${task.text}, 0 of 2 steps done, tap to expand',
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(WhatsDueApp),
      matchesGoldenFile('goldens/phone-steps.png'),
    );
  });

  testWidgets('phone, today', (tester) async {
    final store = await _boot(tester, const Size(430, 932), seed: _seed());
    // Estimates are what turn the plan from a next-action list into a paced
    // day, so the snapshot covers the estimated case.
    final a1 = store.items.firstWhere((a) => a.id == 'a1');
    store.setTaskMinutes(a1.tasks.last, 90);
    final a2 = store.items.firstWhere((a) => a.id == 'a2');
    store.setTaskMinutes(store.addTask(a2, 'Draft the argument')!, 60);
    store.addTask(a2, 'Find a third source');
    await tester.pumpAndSettle();

    await _goTo(tester, 'Assignments');
    await tester.tap(find.text('TODAY'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(WhatsDueApp),
      matchesGoldenFile('goldens/phone-today.png'),
    );
  });

  testWidgets('phone, grades', (tester) async {
    final store = await _boot(tester, const Size(430, 932), seed: _seed());
    // One unit part-marked and one with nothing back yet, so the snapshot
    // covers both the projection table and the untracked warning.
    store.setMarks(
      store.items.firstWhere((a) => a.id == 'a1'),
      weight: 40,
      earned: 30,
      outOf: 40,
    );
    store.setMarks(store.items.firstWhere((a) => a.id == 'a4'), weight: 60);
    store.setMarks(store.items.firstWhere((a) => a.id == 'a3'), weight: 25);
    await tester.pumpAndSettle();

    await _goTo(tester, 'Grades');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/phone-grades.png'),
    );
  });

  testWidgets('phone, add panel', (tester) async {
    await _boot(tester, const Size(430, 932), seed: _seed());
    await tester.tap(find.bySemanticsLabel('Add assignment'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(WhatsDueApp),
      matchesGoldenFile('goldens/phone-add.png'),
    );
  }, skip: false);

  testWidgets('phone, empty', (tester) async {
    await _boot(tester, const Size(430, 932));
    await expectLater(
      find.byType(WhatsDueApp),
      matchesGoldenFile('goldens/phone-empty.png'),
    );
  });

  testWidgets('desktop, list', (tester) async {
    await _boot(tester, const Size(1100, 900), seed: _seed());
    await _goTo(tester, 'Assignments');
    await expectLater(
      find.byType(WhatsDueApp),
      matchesGoldenFile('goldens/desktop-list.png'),
    );
  });

  testWidgets('phone, settings', (tester) async {
    // Tall, so the whole merged page is in one snapshot: sync, reminders,
    // backup, restore, updates and erasing used to be spread over two screens.
    await _boot(tester, const Size(430, 2000), seed: _seed());
    await _goTo(tester, 'Settings');
    await expectLater(
      find.byType(WhatsDueApp),
      matchesGoldenFile('goldens/phone-settings.png'),
    );
  });
}
