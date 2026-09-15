import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whats_due/bands.dart';
import 'package:whats_due/store.dart';

/// Letter grade bands.
///
/// Bands are stored as lower bounds, so the thing worth guarding is that every
/// percentage lands in exactly one band and that the boundary itself falls the
/// way a handbook says it does — 65 is a Credit, not the top of a Pass.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const bands = kDefaultBands;

  group('which band a percentage falls in', () {
    test('the boundary belongs to the band it opens', () {
      expect(bandFor(65, bands)!.name, 'Credit');
      expect(bandFor(64.9, bands)!.name, 'Pass');
      expect(bandFor(50, bands)!.name, 'Pass');
      expect(bandFor(49.9, bands)!.name, 'Fail');
    });

    test('the top band catches everything above it', () {
      expect(bandFor(85, bands)!.name, 'High Distinction');
      expect(bandFor(100, bands)!.name, 'High Distinction');
      expect(bandFor(140, bands)!.name, 'High Distinction');
    });

    test('zero lands in the lowest band rather than nowhere', () {
      expect(bandFor(0, bands)!.name, 'Fail');
    });

    test('no bands means no letter, not a crash', () {
      expect(bandFor(72, const []), isNull);
    });

    test('a percentage beneath every bound has no band', () {
      // Only reachable when the lowest band does not start at zero, which is
      // what bandProblem warns about.
      const gapped = [GradeBand(name: 'Pass', min: 50)];
      expect(bandFor(20, gapped), isNull);
      expect(bandProblem(gapped), isNotNull);
    });
  });

  group('normalising', () {
    test('sorts by bound whatever order they were entered', () {
      final out = normaliseBands(const [
        GradeBand(name: 'HD', min: 85),
        GradeBand(name: 'Fail', min: 0),
        GradeBand(name: 'Pass', min: 50),
      ]);
      expect(out.map((b) => b.name), ['Fail', 'Pass', 'HD']);
    });

    test('drops bands with no name', () {
      final out = normaliseBands(const [
        GradeBand(name: 'Fail', min: 0),
        GradeBand(name: '   ', min: 50),
      ]);
      expect(out.length, 1);
    });
  });

  group('what the editor warns about', () {
    test('accepts a sane set', () {
      expect(bandProblem(bands), isNull);
    });

    test('rejects fewer than two bands', () {
      expect(bandProblem(const [GradeBand(name: 'Pass', min: 0)]), isNotNull);
    });

    test('warns when the lowest band leaves a gap under it', () {
      final p = bandProblem(const [
        GradeBand(name: 'Pass', min: 50),
        GradeBand(name: 'Credit', min: 65),
      ]);
      expect(p, contains('0'));
    });

    test('warns when two bands share a bound', () {
      final p = bandProblem(const [
        GradeBand(name: 'Fail', min: 0),
        GradeBand(name: 'Pass', min: 50),
        GradeBand(name: 'Credit', min: 50),
      ]);
      expect(p, contains('Credit'));
    });
  });

  group('bandAbove', () {
    test('names the next one up, and nothing past the top', () {
      expect(bandAbove(bands[1], bands)!.name, 'Credit');
      expect(bandAbove(bands.last, bands), isNull);
    });
  });

  group('storage', () {
    test('a document without bands round-trips unchanged', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppStore();
      await s.init();
      expect(s.usesLetterGrades, isFalse);
      expect(s.toJson().containsKey('bands'), isFalse);
    });

    test('bands travel with a backup', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppStore();
      await s.init();
      s.setBands(kDefaultBands);

      final reloaded = AppStore();
      await reloaded.init();
      expect(reloaded.bands.map((b) => b.name), bands.map((b) => b.name));
      expect(reloaded.usesLetterGrades, isTrue);
    });

    test('a malformed band is read leniently rather than fatally', () {
      final b = GradeBand.fromJson({'name': 'Pass', 'min': '50'});
      expect(b.min, 50);
      expect(GradeBand.fromJson({'name': 'X', 'min': 'nonsense'}).min, 0);
      expect(GradeBand.fromJson({'name': 'X', 'min': 500}).min, 100);
    });

    test('turning letter grading off clears them from storage', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppStore();
      await s.init();
      s.setBands(kDefaultBands);
      s.setBands(const []);

      final reloaded = AppStore();
      await reloaded.init();
      expect(reloaded.bands, isEmpty);
      expect(jsonDecode(reloaded.exportJson()).containsKey('bands'), isFalse);
    });

    test('an import does not redefine bands that already exist', () async {
      // Bands are one shared setting, not per-item data. Taking the incoming
      // set on a merge would silently change what every existing grade means.
      SharedPreferences.setMockInitialValues({});
      final s = AppStore();
      await s.init();
      s.setBands(const [
        GradeBand(name: 'Fail', min: 0),
        GradeBand(name: 'Pass', min: 40),
      ]);

      final incoming = jsonEncode({
        'subjects': <Object>[],
        'items': [
          {'id': 'x', 'title': 'Essay', 'due': '', 'done': false},
        ],
        'bands': kDefaultBands.map((b) => b.toJson()).toList(),
      });
      s.importJson(incoming, merge: true);

      expect(s.bands.length, 2, reason: 'mine, not theirs');
      expect(s.bands.last.min, 40);
    });

    test('a replace takes the backup’s bands wholesale', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppStore();
      await s.init();

      s.importJson(
        jsonEncode({
          'subjects': <Object>[],
          'items': [
            {'id': 'x', 'title': 'Essay', 'due': '', 'done': false},
          ],
          'bands': kDefaultBands.map((b) => b.toJson()).toList(),
        }),
        merge: false,
      );
      expect(s.bands.length, kDefaultBands.length);
    });
  });
}
