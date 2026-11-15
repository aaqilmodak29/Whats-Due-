// Screenshots of every main screen, for judging the UI.
//
// Drives the real app (WhatsDueApp over a real AppStore on mocked shared
// preferences) at a phone's 430x932 logical size, and saves one PNG per
// screen plus a11y.json (Flutter's contrast and tap-target-label checks,
// counted per screen). See tool/ui_shots/README.md.
//
// Tagged ui_shots and skipped unless UI_SHOTS=1, so a plain `flutter test`
// (and CI's `--exclude-tags golden`) never runs it.
@Tags(['ui_shots'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whats_due/bands.dart';
import 'package:whats_due/main.dart';
import 'package:whats_due/models.dart';
import 'package:whats_due/store.dart';
import 'package:whats_due/theme.dart';
import 'package:whats_due/updater.dart';

final bool _enabled = Platform.environment['UI_SHOTS'] == '1';
final String _out = Platform.environment['UI_SHOTS_OUT'] ?? 'build/ui_shots';

/// Logical phone size. Rendered at 2x so phone-sized type is legible to a
/// judge looking at the PNG; layout is the 430x932 one.
const Size kPhone = Size(430, 932);
const double kRatio = 2;
final _root = GlobalKey();

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      loader.addFont(Future.value(ByteData.sublistView(await File(path).readAsBytes())));
    }
    await loader.load();
  }

  await load('Inter', ['assets/fonts/Inter-Variable.ttf']);
  await load('PlexMono', ['assets/fonts/IBMPlexMono-Regular.ttf', 'assets/fonts/IBMPlexMono-SemiBold.ttf']);
  final root = Platform.environment['FLUTTER_ROOT'] ?? File(Platform.resolvedExecutable).parent.parent.path;
  final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (!icons.existsSync()) fail('MaterialIcons not found at ${icons.path}; set FLUTTER_ROOT');
  await load('MaterialIcons', [icons.path]);
}

String _iso(int offsetDays) => formatIsoDate(midnight().add(Duration(days: offsetDays)));

/// The golden tests' sample data (test/golden_test.dart).
String _seed() => jsonEncode({
  'subjects': [
    {'id': 's1', 'name': 'Organic Chemistry', 'color': '#0E7C7B'},
    {'id': 's2', 'name': 'Statistics', 'color': '#2F5FA8'},
    {'id': 's3', 'name': 'Medieval History', 'color': '#7B3F61'},
  ],
  'items': [
    {'id': 'a1', 'title': 'Reaction mechanisms problem set', 'subjectId': 's1', 'due': _iso(-2), 'done': false,
      'tasks': [
        {'id': 't1', 'text': 'Q1-Q5', 'done': true},
        {'id': 't2', 'text': 'Q6-Q10', 'done': false},
      ]},
    {'id': 'a2', 'title': 'Comparative essay', 'subjectId': 's3', 'due': _iso(1), 'done': false,
      'tasks': [
        {'id': 't3', 'text': 'Draft outline', 'done': true},
        {'id': 't4', 'text': 'Find third source', 'done': true},
        {'id': 't5', 'text': 'Write body', 'done': false},
      ]},
    {'id': 'a3', 'title': 'Regression assignment', 'subjectId': 's2', 'due': _iso(4), 'done': false, 'tasks': <Object>[]},
    {'id': 'a4', 'title': 'Lab report: titration', 'subjectId': 's1', 'due': _iso(4), 'done': false,
      'tasks': [
        {'id': 't6', 'text': 'Plot results', 'done': false},
      ]},
    {'id': 'a5', 'title': 'Hypothesis testing worksheet', 'subjectId': 's2', 'due': _iso(9), 'done': false, 'tasks': <Object>[]},
    {'id': 'a6', 'title': 'Crusades reading response', 'subjectId': 's3', 'due': _iso(12), 'done': false, 'tasks': <Object>[]},
    {'id': 'a7', 'title': 'Read chapters 4-6', 'subjectId': null, 'due': '', 'done': false, 'tasks': <Object>[]},
    {'id': 'a8', 'title': 'Week 3 problem set', 'subjectId': 's2', 'due': _iso(-9), 'done': true, 'tasks': <Object>[]},
  ],
});

/// Pinned so the dates and countdowns are the same every run.
final _fixedNow = DateTime(2026, 8, 6, 12);

const _release = Release(
  tag: 'v1.9.9',
  version: '1.9.9',
  notes: '* feat(grades): goals per subject\n* fix: reminders after a restore',
  apkUrl: 'https://example.invalid/whats-due.apk',
  apkBytes: 31000000,
);

Future<AppStore> _boot(WidgetTester t, {String? seed, bool dark = false, bool onboarded = true, List<GradeBand>? bands}) async {
  t.view.devicePixelRatio = kRatio;
  t.view.physicalSize = kPhone * kRatio;
  addTearDown(t.view.reset);
  addTearDown(() => C.palette = Palette.light);
  SharedPreferences.setMockInitialValues({
    AppStore.storageKey: ?seed,
    if (dark) 'coursework:dark': true,
    if (onboarded) 'coursework:onboarded': true,
  });
  final store = AppStore();
  await store.init();
  if (bands != null) store.setBands(bands);
  await t.pumpWidget(RepaintBoundary(key: _root, child: WhatsDueApp(store: store)));
  await t.pumpAndSettle();
  return store;
}

Assignment _item(AppStore s, String id) => s.items.firstWhere((a) => a.id == id);

/// The marks the golden "grades" snapshot uses: one subject per colour.
Future<void> _marks(WidgetTester t, AppStore s) async {
  s.setMarks(_item(s, 'a1'), earned: 30, outOf: 40);
  s.setMarks(_item(s, 'a4'), earned: 8, outOf: 10);
  s.setMarks(_item(s, 'a3'), earned: 10, outOf: 25);
  s.setMarks(_item(s, 'a2'), earned: 46, outOf: 50);
  await t.pumpAndSettle();
}

Future<void> _goTo(WidgetTester t, String label) async {
  await t.tap(find.text(label.toUpperCase()).last);
  await t.pumpAndSettle();
}

Future<void> _tap(WidgetTester t, Finder f) async {
  // Below the fold (or under the nav bar) a tap would land on something else,
  // so bring it on screen first, but leave a visible target where it is.
  final r = t.getRect(f.first);
  if (r.top < 0 || r.bottom > kPhone.height - 70) {
    await t.ensureVisible(f.first);
    await t.pumpAndSettle();
  }
  await t.tap(f.first, warnIfMissed: false);
  await t.pumpAndSettle();
}

/// Scrolls the current page so [f] sits [top] logical pixels from the top.
Future<void> _scrollTo(WidgetTester t, Finder f, {double top = 40}) async {
  final page = find.ancestor(
    of: f.first,
    matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
  );
  final position = t.state<ScrollableState>(page.first).position;
  final y = t.getTopLeft(f.first).dy;
  position.jumpTo((position.pixels + y - top).clamp(0.0, position.maxScrollExtent));
  await t.pumpAndSettle();
}

Future<void> _shot(WidgetTester t, String name) async {
  await t.pumpAndSettle();
  final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(_root));
  await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: kRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$name.png');
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
  await _audit(t, name);
}

/// Flutter's own accessibility checks on the screen just shot: text that
/// fails the contrast guideline and tap targets with no label. Counted, not
/// asserted, and written to a11y.json beside the shots.
final _a11y = <String, Map<String, int>>{};

Future<void> _audit(WidgetTester t, String name) async {
  final handle = t.ensureSemantics();
  await t.pump();
  int failures(Evaluation e) {
    if (e.passed) return 0;
    final nodes = RegExp(r'SemanticsNode#\d+').allMatches(e.reason ?? '').length;
    return nodes == 0 ? 1 : nodes;
  }

  try {
    _a11y[name] = {
      'contrast': failures(await textContrastGuideline.evaluate(t)),
      'unlabelled': failures(await labeledTapTargetGuideline.evaluate(t)),
    };
  } finally {
    handle.dispose();
    await t.pump();
  }
}

/// The notifications plugin as a phone with permission granted sees it, so
/// the Reminders section shows its working state rather than the "could not
/// start on this device" warning a test host would otherwise get.
void _fakeNotifications() {
  // Tests already report Android as the platform; the registrant that would
  // install the Android implementation never runs under `flutter test`.
  AndroidFlutterLocalNotificationsPlugin.registerWith();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final pending = [
    for (var i = 0; i < 14; i++) {'id': i, 'title': 'Due soon', 'body': '', 'payload': null},
  ];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
    switch (call.method) {
      case 'initialize':
      case 'areNotificationsEnabled':
      case 'canScheduleExactNotifications':
      case 'requestNotificationsPermission':
      case 'requestExactAlarmsPermission':
        return true;
      case 'pendingNotificationRequests':
        return pending;
    }
    return null;
  });
}

void shots(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets(name, (t) async {
    debugDisableShadows = false;
    try {
      await body(t);
    } finally {
      debugDisableShadows = true;
    }
  }, skip: !_enabled);
}


void main() {
  setUpAll(() async {
    if (!_enabled) return;
    clock = () => _fixedNow;
    // The Android layout of the update panel, as on the phone.
    Updater.canSelfInstall = true;
    // The installed version the update panel names.
    PackageInfo.setMockInitialValues(
        appName: "What's due", packageName: 'com.whatsdue', version: '1.4.0', buildNumber: '14', buildSignature: '');
    _fakeNotifications();
    await _loadFonts();
  });

  tearDownAll(() {
    clock = DateTime.now;
    if (!_enabled) return;
    const pretty = JsonEncoder.withIndent('  ');
    File('$_out/a11y.json').writeAsStringSync('${pretty.convert(_a11y)}\n');
  });

  shots('list', (t) async {
    final s = await _boot(t, seed: _seed());
    s.setMarks(_item(s, 'a3'), earned: 30, outOf: 40);
    s.setMarks(_item(s, 'a4'), outOf: 25);
    await t.pumpAndSettle();
    await _shot(t, '01-list');
    await _tap(t, find.text('Comparative essay'));
    await _shot(t, '02-card-expanded');
    final task = _item(s, 'a2').tasks.last;
    s.addSubtask(task, 'Pull three sources');
    s.addSubtask(task, 'Draft the argument');
    await t.pumpAndSettle();
    await _tap(t, find.bySemanticsLabel('${task.text}, 0 of 2 steps done, tap to expand'));
    await _scrollTo(t, find.text('Comparative essay'), top: 80);
    await _shot(t, '03-steps-open');
    await _tap(t, find.text('EDIT'));
    FocusManager.instance.primaryFocus?.unfocus(); // no selection handle
    await _shot(t, '05-edit-sheet');
  });

  shots('add', (t) async {
    await _boot(t, seed: _seed());
    await _tap(t, find.byIcon(Icons.add));
    await _shot(t, '04-add-panel');
    await _tap(t, find.text('yyyy-mm-dd'));
    await _shot(t, '06-date-picker');
  });

  shots('delete', (t) async {
    await _boot(t, seed: _seed());
    await _tap(t, find.text('Regression assignment'));
    await _scrollTo(t, find.text('Regression assignment'), top: 80);
    await _tap(t, find.byIcon(Icons.delete_outline));
    await _shot(t, '07-delete-confirm');
  });

  shots('filters', (t) async {
    await _boot(t, seed: _seed());
    await _tap(t, find.text('MANAGE SUBJECTS'));
    await _shot(t, '08-manage-subjects');
    await _tap(t, find.text('HIDE SUBJECTS'));
    await _tap(t, find.textContaining('STATISTICS'));
    await _shot(t, '09-subject-filter');
    await _tap(t, find.textContaining(RegExp('Submitted', caseSensitive: false)));
    await _shot(t, '10-submitted');
  });

  shots('search empty', (t) async {
    await _boot(t, seed: _seed());
    await t.enterText(find.byType(TextField).first, 'thermodynamics');
    await t.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await _shot(t, '11-search-no-match');
  });

  shots('update banner', (t) async {
    final s = await _boot(t, seed: _seed());
    s.updater.offerForTest(_release);
    await t.pumpAndSettle();
    await _shot(t, '12-update-banner');
  });

  shots('grades', (t) async {
    final s = await _boot(t, seed: _seed(), bands: kDefaultBands);
    await _marks(t, s);
    await _goTo(t, 'Grades');
    await _shot(t, '13-grades');
    await _tap(t, find.text('ORGANIC CHEMISTRY'));
    await _shot(t, '14-grades-open');
  });

  shots('grades goal', (t) async {
    final s = await _boot(t, seed: _seed(), bands: kDefaultBands);
    s.setMarks(_item(s, 'a1'), earned: 30, outOf: 40);
    s.setMarks(_item(s, 'a4'), outOf: 60);
    s.setGoal(_item(s, 'a4'), 45);
    s.setSubjectGoal(s.subjects.first, 75);
    await t.pumpAndSettle();
    await _goTo(t, 'Grades');
    await _tap(t, find.text('ORGANIC CHEMISTRY'));
    await _shot(t, '15-grades-goal');
  });

  shots('goal sheet', (t) async {
    final s = await _boot(t, seed: _seed(), bands: kDefaultBands);
    s.setMarks(_item(s, 'a1'), earned: 30, outOf: 40);
    await t.pumpAndSettle();
    await _goTo(t, 'Grades');
    await _tap(t, find.text('SET A GOAL'));
    await _shot(t, '16-goal-sheet');
  });

  shots('grades empty', (t) async {
    await _boot(t, seed: _seed());
    await _goTo(t, 'Grades');
    await _shot(t, '17-grades-no-marks');
  });

  shots('settings', (t) async {
    final s = await _boot(t, seed: _seed(), bands: kDefaultBands);
    s.updater.offerForTest(_release);
    await t.pumpAndSettle();
    await _goTo(t, 'Settings');
    await _shot(t, '18-settings');
    await _tap(t, find.bySemanticsLabel(RegExp('^Grading, ')));
    await _scrollTo(t, find.bySemanticsLabel(RegExp('^Grading, ')));
    await _shot(t, '19-settings-grading');
    await _scrollTo(t, find.text('REMINDERS'));
    await _shot(t, '20-settings-backup');
  });

  shots('welcome', (t) async {
    await _boot(t, seed: _seed(), onboarded: false);
    await _shot(t, '21-welcome');
    await _tap(t, find.text('YES, SET THEM UP'));
    await _shot(t, '22-welcome-bands');
  });

  shots('empty', (t) async {
    await _boot(t);
    await _shot(t, '23-empty');
  });

  shots('dark', (t) async {
    final s = await _boot(t, seed: _seed(), dark: true, bands: kDefaultBands);
    await _shot(t, '24-dark-list');
    await _tap(t, find.text('Comparative essay'));
    await _shot(t, '25-dark-expanded');
    await _marks(t, s);
    await _goTo(t, 'Grades');
    await _shot(t, '26-dark-grades');
  });
}
