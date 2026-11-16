import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whats_due/grades.dart';
import 'package:whats_due/models.dart';
import 'package:whats_due/store.dart';

Future<AppStore> storeWith(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = AppStore();
  await store.init();
  return store;
}

/// Written before sections existed: no `section` anywhere.
final _legacy = jsonEncode({
  'subjects': [
    {'id': 's1', 'name': 'Statistics', 'color': '#2F5FA8'},
  ],
  'items': [
    {'id': 'a1', 'title': 'Essay', 'subjectId': 's1', 'due': '', 'done': false},
    {
      'id': 'a2',
      'title': 'Quiz',
      'subjectId': 's1',
      'due': '',
      'done': true,
      'earned': 8,
      'outOf': 10,
    },
  ],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('model', () {
    test('a missing or unknown section is school work', () {
      expect(Assignment.fromJson({'id': 'a'}).section, WorkSection.school);
      expect(
        Assignment.fromJson({'id': 'a', 'section': 'nonsense'}).section,
        WorkSection.school,
      );
    });

    test('general work round-trips; school work serialises as before', () {
      final g = Assignment(id: 'a', title: 'x', section: WorkSection.general);
      expect(g.toJson()['section'], 'general');
      expect(Assignment.fromJson(g.toJson()).section, WorkSection.general);
      final s = Assignment(id: 'b', title: 'y');
      expect(s.toJson().containsKey('section'), isFalse);
    });
  });

  group('store', () {
    test('legacy data all lands in school work, which is the default',
        () async {
      final store = await storeWith({AppStore.storageKey: _legacy});
      expect(store.section, WorkSection.school);
      expect(store.items.every((a) => a.section == WorkSection.school), isTrue);
      expect(store.sectionItems.length, 2);
    });

    test('new work goes into the section being shown', () async {
      final store = await storeWith({AppStore.storageKey: _legacy});
      store.setSection(WorkSection.general);
      final a = store.addAssignment(title: 'Renew licence');
      expect(a.section, WorkSection.general);
      store.setSection(WorkSection.school);
      expect(store.addAssignment(title: 'Lab').section, WorkSection.school);
    });

    test('the lists show only the current section', () async {
      final store = await storeWith({AppStore.storageKey: _legacy});
      store.setSection(WorkSection.general);
      expect(store.active, isEmpty);
      expect(store.submitted, isEmpty);
      store.addAssignment(title: 'Renew licence');
      expect(store.active.map((a) => a.title), ['Renew licence']);

      store.setSection(WorkSection.school);
      expect(store.active.map((a) => a.title), ['Essay']);
      expect(store.submitted.map((a) => a.title), ['Quiz']);
      // Everything is still there underneath.
      expect(store.items.length, 3);
    });

    test('the section is remembered between launches', () async {
      final store = await storeWith({});
      store.setSection(WorkSection.general);
      final reloaded = AppStore();
      await reloaded.init();
      expect(reloaded.section, WorkSection.general);
    });

    test('general work survives a reload and a backup', () async {
      final store = await storeWith({});
      store.setSection(WorkSection.general);
      store.addAssignment(title: 'Renew licence');

      final reloaded = AppStore();
      await reloaded.init();
      expect(reloaded.items.single.section, WorkSection.general);

      final restored = await storeWith({});
      restored.importJson(store.exportJson(), merge: false);
      expect(restored.items.single.section, WorkSection.general);
    });

    test('grades count school work only', () async {
      final store = await storeWith({AppStore.storageKey: _legacy});
      store.setSection(WorkSection.general);
      final g = store.addAssignment(
        title: 'Side project',
        subjectId: 's1',
        outOf: 10,
      );
      store.setMarks(g, earned: 1);
      final grades = gradesBySubject(store.schoolItems);
      expect(grades.single.gradedCount, 1);
    });
  });
}
