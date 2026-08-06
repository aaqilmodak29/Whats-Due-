import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whats_due/store.dart';
import 'package:whats_due/theme.dart';

/// Sync is the one place in this app where a bug loses work rather than merely
/// looking wrong, so the pieces that decide *what wins* are tested directly.
///
/// The network layer itself is not covered here — that needs a live Firebase
/// project. What is covered is everything that decides whether local or remote
/// data survives, plus the guarantee that a pulled payload cannot be mistaken
/// for a local edit and bounced straight back.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppStore> freshStore([Map<String, Object>? prefs]) async {
    SharedPreferences.setMockInitialValues(prefs ?? {});
    final store = AppStore();
    await store.init();
    return store;
  }

  group('payload format', () {
    test('the sync payload is byte-identical to what is stored', () async {
      final store = await freshStore();
      final subject = store.addSubject('Chemistry', kPalette.first);
      store.addAssignment(
        title: 'Essay',
        subjectId: subject.id,
        due: '2026-08-19',
      );

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(AppStore.storageKey);

      expect(
        store.payloadJson(),
        stored,
        reason: 'remote copy, local copy and backup must share one format',
      );
    });

    test('a payload round-trips through the wire format unchanged', () async {
      final a = await freshStore();
      final s = a.addSubject('Chemistry', kPalette[2]);
      final item = a.addAssignment(
        title: 'Essay',
        subjectId: s.id,
        due: '2026-08-19',
      );
      a.addTask(item, 'Draft outline');
      final payload = a.payloadJson();

      final b = await freshStore();
      b.adoptRemote(payload);

      expect(b.payloadJson(), payload);
      expect(b.subjects.single.name, 'Chemistry');
      expect(b.subjects.single.color, kPalette[2]);
      expect(b.items.single.due, '2026-08-19');
      expect(b.items.single.tasks.single.text, 'Draft outline');
    });
  });

  group('adopting a remote payload', () {
    test('replaces local state wholesale, including deletions', () async {
      // Whole-document last-write-wins means a deletion is just an item that is
      // absent from the newer document — there are no tombstones, so adopting
      // must not merge the two sides.
      final store = await freshStore();
      store.addAssignment(title: 'Deleted on the other device');
      store.addAssignment(title: 'Also deleted');
      expect(store.items.length, 2);

      store.adoptRemote(jsonEncode({'subjects': [], 'items': []}));

      expect(store.items, isEmpty, reason: 'deletions must propagate');
      expect(store.subjects, isEmpty);
    });

    test('persists what it adopted, so a restart keeps it', () async {
      final store = await freshStore();
      store.addAssignment(title: 'Local only');

      final incoming = jsonEncode({
        'subjects': [
          {'id': 's1', 'name': 'Statistics', 'color': '#2F5FA8'},
        ],
        'items': [
          {
            'id': 'a1',
            'title': 'From the other device',
            'subjectId': 's1',
            'due': '2026-09-01',
            'done': false,
            'tasks': <Object>[],
          },
        ],
      });
      store.adoptRemote(incoming);

      final reloaded = AppStore();
      await reloaded.init();
      expect(reloaded.items.single.title, 'From the other device');
      expect(reloaded.subjects.single.name, 'Statistics');
    });

    test('a corrupt payload is refused without destroying local work', () async {
      final store = await freshStore();
      store.addAssignment(title: 'Precious');

      for (final junk in ['', 'not json', '[1,2,3]', '{"items":"nope"}']) {
        store.adoptRemote(junk);
        expect(
          store.items.single.title,
          'Precious',
          reason: 'refused payload "$junk" must leave local state intact',
        );
      }
    });

    test('adopting does not mark the state as a local edit', () async {
      // If adopting set the dirty flag, the pulled copy would be pushed
      // straight back to the device it came from, and every pull would look
      // like a fresh change on both sides forever.
      final store = await freshStore();
      final prefs = await SharedPreferences.getInstance();

      store.addAssignment(title: 'Local');
      // A real engine sets this via onLocalChange; emulate the post-sync state.
      await prefs.setBool('sync:dirty', false);

      store.adoptRemote(jsonEncode({'subjects': [], 'items': []}));

      expect(prefs.getBool('sync:dirty'), isFalse);
    });
  });

  group('describing a conflict', () {
    test('counts items in an arbitrary payload without adopting it', () async {
      final store = await freshStore();
      store.addAssignment(title: 'Mine');

      final other = jsonEncode({
        'subjects': [],
        'items': [
          {'id': 'x1', 'title': 'Theirs 1', 'tasks': <Object>[]},
          {'id': 'x2', 'title': 'Theirs 2', 'tasks': <Object>[]},
          {'id': 'x3', 'title': 'Theirs 3', 'tasks': <Object>[]},
        ],
      });

      expect(store.countItemsIn(other), 3);
      // Counting must not have swapped local state for the thing being counted.
      expect(store.items.single.title, 'Mine');
    });

    test('an unreadable payload counts as zero rather than throwing', () async {
      final store = await freshStore();
      expect(store.countItemsIn('garbage'), 0);
      expect(store.countItemsIn(''), 0);
    });
  });

  group('local change tracking', () {
    test('every mutation marks the state as needing a push', () async {
      final store = await freshStore();
      final prefs = await SharedPreferences.getInstance();

      // No engine attached, so drive the flag the way the engine would and
      // confirm each mutation routes through the commit path.
      for (final mutate in <void Function()>[
        () => store.addAssignment(title: 'One'),
        () => store.addSubject('Chemistry', kPalette.first),
        () => store.toggleSubmitted(store.items.first),
        () => store.editAssignment(store.items.first, title: 'Renamed'),
        () => store.addTask(store.items.first, 'A task'),
        () => store.toggleTask(store.items.first, store.items.first.tasks.first),
      ]) {
        await prefs.setString(AppStore.storageKey, 'sentinel');
        mutate();
        expect(
          prefs.getString(AppStore.storageKey),
          isNot('sentinel'),
          reason: 'mutation did not persist, so it would never sync',
        );
      }
    });
  });
}
