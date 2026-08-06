import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whats_due/store.dart';
import 'package:whats_due/theme.dart';

Future<AppStore> storeWith(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = AppStore();
  await store.init();
  return store;
}

void main() {
  // The store schedules reminders on load; the plugin channels are absent under
  // test and the calls are caught, so nothing here needs them stubbed.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('loading', () {
    test('an empty install starts empty rather than failing', () async {
      final store = await storeWith({});
      expect(store.items, isEmpty);
      expect(store.subjects, isEmpty);
      expect(store.storageBlocked, isFalse);
    });

    test('reads the same key and shape the web app writes', () async {
      final store = await storeWith({
        AppStore.storageKey: jsonEncode({
          'subjects': [
            {'id': 's1', 'name': 'Organic Chemistry', 'color': '#0E7C7B'},
          ],
          'items': [
            {
              'id': 'a1',
              'title': 'Comparative essay',
              'subjectId': 's1',
              'due': '2026-08-19',
              'done': false,
              'tasks': [
                {'id': 't1', 'text': 'Draft outline', 'done': false},
              ],
            },
          ],
        }),
      });

      expect(store.subjects.single.name, 'Organic Chemistry');
      expect(store.items.single.title, 'Comparative essay');
      expect(store.items.single.tasks.single.text, 'Draft outline');
      expect(store.subjectOf(store.items.single)?.name, 'Organic Chemistry');
    });

    test('malformed stored JSON is survived, not fatal', () async {
      final store = await storeWith({AppStore.storageKey: 'not json at all'});
      expect(store.items, isEmpty);
      expect(store.storageBlocked, isTrue);
    });
  });

  group('v1 migration', () {
    test('groups free-text modules into subjects, case-insensitively', () async {
      final store = await storeWith({
        AppStore.legacyKey: jsonEncode([
          {'id': 'a1', 'title': 'Essay', 'module': 'Chemistry', 'due': ''},
          {'id': 'a2', 'title': 'Prac', 'module': 'CHEMISTRY', 'due': ''},
          {'id': 'a3', 'title': 'Report', 'module': 'Physics', 'due': ''},
          {'id': 'a4', 'title': 'Loose', 'module': '', 'due': ''},
        ]),
      });

      expect(store.subjects.map((s) => s.name), ['Chemistry', 'Physics']);
      expect(store.items.length, 4);

      final chemistry = store.subjects.first;
      expect(store.countFor(chemistry.id), 2);
      // Distinct palette colours, assigned round-robin.
      expect(store.subjects[0].color, kPalette[0]);
      expect(store.subjects[1].color, kPalette[1]);
      // The unfiled one keeps its work rather than being dropped.
      expect(
        store.items.where((a) => a.subjectId == null).single.title,
        'Loose',
      );
    });

    test('the v1 key is left in place as an accidental backup', () async {
      SharedPreferences.setMockInitialValues({
        AppStore.legacyKey: jsonEncode([
          {'id': 'a1', 'title': 'Essay', 'module': 'Chemistry', 'due': ''},
        ]),
      });
      final store = AppStore();
      await store.init();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppStore.legacyKey), isNotNull);
    });
  });

  group('mutations', () {
    test('deleting a subject unfiles its work instead of cascading', () async {
      final store = await storeWith({});
      final subject = store.addSubject('Chemistry', kPalette.first);
      store.addAssignment(title: 'Essay', subjectId: subject.id);

      store.deleteSubject(subject);

      expect(store.subjects, isEmpty);
      expect(store.items.single.title, 'Essay');
      expect(store.items.single.subjectId, isNull);
    });

    test('editing changes title and due date after creation', () async {
      final store = await storeWith({});
      final a = store.addAssignment(title: 'Draft', due: '');

      store.editAssignment(a, title: 'Final essay', due: '2026-08-19');
      expect(a.title, 'Final essay');
      expect(a.due, '2026-08-19');

      // A blank title is refused rather than wiping the card's label.
      store.editAssignment(a, title: '   ');
      expect(a.title, 'Final essay');

      // Clearing the date back to unset is allowed.
      store.editAssignment(a, due: '');
      expect(a.due, '');
    });

    test('active excludes submitted work and sorts undated last', () async {
      final store = await storeWith({});
      store.addAssignment(title: 'later', due: '2026-12-01');
      store.addAssignment(title: 'undated');
      store.addAssignment(title: 'sooner', due: '2026-08-19');
      final done = store.addAssignment(title: 'finished', due: '2026-09-01');
      store.toggleSubmitted(done);

      expect(store.active.map((a) => a.title), [
        'sooner',
        'later',
        'undated',
      ]);
      expect(store.submitted.map((a) => a.title), ['finished']);
    });

    test('changes survive a reload', () async {
      final store = await storeWith({});
      final subject = store.addSubject('Chemistry', kPalette.first);
      store.addAssignment(
        title: 'Essay',
        subjectId: subject.id,
        due: '2026-08-19',
      );

      final reloaded = AppStore();
      await reloaded.init();

      expect(reloaded.subjects.single.name, 'Chemistry');
      expect(reloaded.items.single.title, 'Essay');
      expect(reloaded.items.single.due, '2026-08-19');
    });
  });

  group('import', () {
    String backup() => jsonEncode({
      'subjects': [
        {'id': 's1', 'name': 'Chemistry', 'color': '#0E7C7B'},
      ],
      'items': [
        {
          'id': 'a1',
          'title': 'Essay',
          'subjectId': 's1',
          'due': '2026-08-19',
          'done': false,
          'tasks': <Object>[],
        },
      ],
    });

    test('replace swaps everything out', () async {
      final store = await storeWith({});
      store.addAssignment(title: 'Old thing');

      final result = store.importJson(backup(), merge: false);

      expect(result.succeeded, isTrue);
      expect(store.items.map((a) => a.title), ['Essay']);
      expect(store.subjects.single.name, 'Chemistry');
    });

    test('merge keeps existing work and remaps subjects by name', () async {
      final store = await storeWith({});
      final existing = store.addSubject('Chemistry', kPalette[3]);
      store.addAssignment(title: 'Old thing', subjectId: existing.id);

      final result = store.importJson(backup(), merge: true);

      expect(result.succeeded, isTrue);
      expect(result.subjects, 0, reason: 'Chemistry already existed by name');
      expect(result.items, 1);
      // One chip, not two.
      expect(store.subjects.length, 1);
      expect(store.items.map((a) => a.title), ['Old thing', 'Essay']);
      // The imported assignment attached to the subject already present.
      expect(store.items.last.subjectId, existing.id);
    });

    test('merging the same backup twice is a no-op', () async {
      final store = await storeWith({});
      store.importJson(backup(), merge: true);
      final second = store.importJson(backup(), merge: true);

      expect(second.items, 0);
      expect(store.items.length, 1);
    });

    test('accepts a v1 bare array as well as the v2 object', () async {
      final store = await storeWith({});
      final result = store.importJson(
        jsonEncode([
          {'id': 'a1', 'title': 'Essay', 'module': 'Chemistry', 'due': ''},
        ]),
        merge: false,
      );

      expect(result.succeeded, isTrue);
      expect(store.subjects.single.name, 'Chemistry');
      expect(store.items.single.title, 'Essay');
    });

    test('rejects junk without touching what is already there', () async {
      final store = await storeWith({});
      store.addAssignment(title: 'Precious');

      for (final junk in ['', '   ', 'nonsense', '{"subjects":[],"items":[]}']) {
        final result = store.importJson(junk, merge: false);
        expect(result.succeeded, isFalse, reason: 'accepted "$junk"');
        expect(result.error, isNotNull);
      }
      expect(store.items.single.title, 'Precious');
    });
  });

  test('exported JSON re-imports cleanly', () async {
    final store = await storeWith({});
    final subject = store.addSubject('Chemistry', kPalette.first);
    final a = store.addAssignment(
      title: 'Essay',
      subjectId: subject.id,
      due: '2026-08-19',
    );
    store.addTask(a, 'Draft outline');

    final exported = store.exportJson();
    final fresh = AppStore();
    SharedPreferences.setMockInitialValues({});
    await fresh.init();
    final result = fresh.importJson(exported, merge: false);

    expect(result.succeeded, isTrue);
    expect(fresh.subjects.single.name, 'Chemistry');
    expect(fresh.items.single.title, 'Essay');
    expect(fresh.items.single.due, '2026-08-19');
    expect(fresh.items.single.tasks.single.text, 'Draft outline');
  });
}
