import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whats_due/filters.dart';
import 'package:whats_due/models.dart';
import 'package:whats_due/store.dart';

Future<AppStore> storeWith(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = AppStore();
  await store.init();
  return store;
}

/// A document as written before semesters existed.
final _legacy = jsonEncode({
  'subjects': [
    {'id': 's1', 'name': 'Statistics', 'color': '#2F5FA8'},
  ],
  'items': [
    {'id': 'a1', 'title': 'Essay', 'subjectId': 's1', 'due': '', 'done': false},
  ],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('semester model', () {
    test('round-trips through JSON', () {
      final s = Semester.fromJson(Semester(id: 'x', name: 'Sem 1').toJson());
      expect(s.id, 'x');
      expect(s.name, 'Sem 1');
    });

    test(
      'a subject keeps its semester through JSON, and omits it when unset',
      () {
        final filed = Subject(id: 's', name: 'A', color: '#000000')
          ..semesterId = 'x';
        expect(Subject.fromJson(filed.toJson()).semesterId, 'x');
        final loose = Subject(id: 's', name: 'A', color: '#000000');
        expect(loose.toJson().containsKey('semesterId'), isFalse);
        expect(Subject.fromJson(loose.toJson()).semesterId, isNull);
      },
    );
  });

  group('legacy data', () {
    test('a document without semesters loads with none', () async {
      final store = await storeWith({AppStore.storageKey: _legacy});
      expect(store.semesters, isEmpty);
      expect(store.subjects.single.semesterId, isNull);
      expect(store.storageBlocked, isFalse);
    });

    test('a store with no semesters serialises exactly as before', () async {
      final store = await storeWith({AppStore.storageKey: _legacy});
      expect(store.toJson().containsKey('semesters'), isFalse);
    });

    test('an old backup imports with no semesters', () async {
      final store = await storeWith({});
      final r = store.importJson(_legacy, merge: false);
      expect(r.succeeded, isTrue);
      expect(store.semesters, isEmpty);
    });
  });

  group('semesters in the store', () {
    test('adding persists and survives a reload', () async {
      final store = await storeWith({AppStore.storageKey: _legacy});
      final sem = store.addSemester('  Semester 2, 2026 ')!;
      expect(sem.name, 'Semester 2, 2026');
      store.setSubjectSemester(store.subjects.single, sem.id);

      final reloaded = AppStore();
      await reloaded.init();
      expect(reloaded.semesters.single.name, 'Semester 2, 2026');
      expect(reloaded.subjects.single.semesterId, sem.id);
      expect(
        reloaded.semesterOf(reloaded.subjects.single)?.name,
        'Semester 2, 2026',
      );
    });

    test('a blank name is refused', () async {
      final store = await storeWith({});
      expect(store.addSemester('   '), isNull);
      expect(store.semesters, isEmpty);
    });

    test('renaming changes the name; a blank rename is ignored', () async {
      final store = await storeWith({});
      final sem = store.addSemester('Sem 1')!;
      store.renameSemester(sem, 'Semester 1');
      expect(store.semesters.single.name, 'Semester 1');
      store.renameSemester(sem, ' ');
      expect(store.semesters.single.name, 'Semester 1');
    });

    test('deleting leaves its subjects unassigned, not deleted', () async {
      final store = await storeWith({AppStore.storageKey: _legacy});
      final sem = store.addSemester('Sem 1')!;
      store.setSubjectSemester(store.subjects.single, sem.id);
      store.deleteSemester(sem);
      expect(store.semesters, isEmpty);
      expect(store.subjects.single.semesterId, isNull);
      expect(store.items.single.subjectId, 's1');
    });

    test('a backup carries semesters, replace and merge', () async {
      final source = await storeWith({AppStore.storageKey: _legacy});
      final sem = source.addSemester('Sem 1')!;
      source.setSubjectSemester(source.subjects.single, sem.id);
      final json = source.exportJson();

      final replaced = await storeWith({});
      replaced.importJson(json, merge: false);
      expect(replaced.semesters.single.name, 'Sem 1');
      expect(replaced.subjects.single.semesterId, replaced.semesters.single.id);

      // Merging onto a store that already has a same-named semester reuses it.
      final merged = await storeWith({});
      final existing = merged.addSemester('SEM 1')!;
      merged.importJson(json, merge: true);
      expect(merged.semesters.length, 1);
      expect(merged.subjects.single.semesterId, existing.id);
    });
  });

  group('assigning and filtering', () {
    test('a subject can be added straight into a semester', () async {
      final store = await storeWith({});
      final sem = store.addSemester('Sem 1')!;
      final sub = store.addSubject('Physics', '#000000', semesterId: sem.id);
      expect(sub.semesterId, sem.id);
      store.setSubjectSemester(sub, null);
      expect(sub.semesterId, isNull);
    });

    test('only work filed under another semester is hidden', () {
      expect(matchesSemester('a', null), isTrue);
      expect(matchesSemester('a', 'a'), isTrue);
      expect(matchesSemester('b', 'a'), isFalse);
      // No semester, or no subject at all: nothing says it is finished.
      expect(matchesSemester(null, 'a'), isTrue);
    });

    test('applyFilters narrows by semester', () async {
      final store = await storeWith({});
      final now = store.addSemester('Now')!;
      final past = store.addSemester('Past')!;
      final a = store.addSubject('A', '#000000', semesterId: now.id);
      final b = store.addSubject('B', '#000000', semesterId: past.id);
      store.addAssignment(title: 'current', subjectId: a.id);
      store.addAssignment(title: 'old', subjectId: b.id);
      store.addAssignment(title: 'loose');
      final shown = applyFilters(
        store.items,
        semester: now.id,
        semesterOf: store.semesterIdOf,
      ).map((x) => x.title);
      expect(shown, unorderedEquals(['current', 'loose']));
    });

    test('the chosen semester is remembered, and forgotten once deleted',
        () async {
      final store = await storeWith({});
      final sem = store.addSemester('Sem 1')!;
      store.setSemesterFilter(sem.id);

      final reloaded = AppStore();
      await reloaded.init();
      expect(reloaded.semesterFilter, sem.id);
      reloaded.deleteSemester(reloaded.semesters.single);
      expect(reloaded.semesterFilter, isNull);
    });
  });
}
