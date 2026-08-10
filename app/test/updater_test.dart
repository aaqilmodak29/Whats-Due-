import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:whats_due/updater.dart';

void main() {
  group('version comparison', () {
    test('orders numerically, not as strings', () {
      // The one that matters: "1.10.0" sorts before "1.9.0" as text, which
      // would silently stop offering updates from 1.9 onwards.
      expect(Updater.compareVersions('1.10.0', '1.9.0'), greaterThan(0));
      expect(Updater.compareVersions('2.0.0', '1.99.99'), greaterThan(0));
      expect(Updater.compareVersions('1.0.10', '1.0.9'), greaterThan(0));
    });

    test('equal versions compare equal', () {
      expect(Updater.compareVersions('1.2.3', '1.2.3'), 0);
    });

    test('missing components count as zero', () {
      expect(Updater.compareVersions('1.2', '1.2.0'), 0);
      expect(Updater.compareVersions('1.2.1', '1.2'), greaterThan(0));
    });

    test('a build suffix does not outrank the version', () {
      expect(Updater.compareVersions('1.2.3+9', '1.2.3+1'), greaterThan(0));
      expect(Updater.compareVersions('1.2.3+1', '1.2.4'), lessThan(0));
    });

    test('an unparseable component degrades instead of throwing', () {
      expect(() => Updater.compareVersions('rubbish', '1.0.0'), returnsNormally);
      expect(Updater.compareVersions('rubbish', '1.0.0'), lessThan(0));
    });
  });

  group('summarising release notes', () {
    // Copied verbatim from the v1.0.1 release GitHub generated, because that
    // is the shape that actually has to render on a phone.
    const real = '''
## What's Changed
* feat: Flutter port for Windows, Android and web by @aaqilmodak29 in https://github.com/aaqilmodak29/Whats-Due-/pull/1
* feat(sync): share one list across Windows, Android and web by @aaqilmodak29 in https://github.com/aaqilmodak29/Whats-Due-/pull/2
* refactor(sync): inject Firebase config at build time instead of hardc... by @aaqilmodak29 in https://github.com/aaqilmodak29/Whats-Due-/pull/3
* Secrets out of git by @aaqilmodak29 in https://github.com/aaqilmodak29/Whats-Due-/pull/4
* ci: harden the workflows before the repository goes public by @aaqilmodak29 in https://github.com/aaqilmodak29/Whats-Due-/pull/5

## New Contributors
* @aaqilmodak29 made their first contribution in https://github.com/aaqilmodak29/Whats-Due-/pull/1

**Full Changelog**: https://github.com/aaqilmodak29/Whats-Due-/commits/v1.0.1
''';

    test('turns the real v1.0.1 notes into readable lines', () {
      expect(Updater.summarise(real), [
        'Flutter port for Windows, Android and web',
        'Share one list across Windows, Android and web',
        'Inject Firebase config at build time instead of hardc...',
        'Secrets out of git',
      ]);
    });

    test('drops every URL — they wrap badly and say nothing', () {
      for (final line in Updater.summarise(real, max: 99)) {
        expect(line, isNot(contains('http')));
        expect(line, isNot(contains('github.com')));
      }
    });

    test('drops attribution, headings and the changelog footer', () {
      final lines = Updater.summarise(real, max: 99);
      for (final line in lines) {
        expect(line, isNot(contains('@')));
        expect(line, isNot(startsWith('#')));
        expect(line.toLowerCase(), isNot(contains('full changelog')));
      }
    });

    test('the New Contributors section is dropped entirely', () {
      // Its one entry is pure attribution: strip the handle and the link and
      // "@someone made their first contribution in" is left saying nothing.
      final lines = Updater.summarise(real, max: 99);
      expect(
        lines.any((l) => l.toLowerCase().contains('contribution')),
        isFalse,
      );
      expect(lines.length, 5, reason: 'the five merged changes, and nothing else');
    });

    test('a stripped link never leaves a dangling preposition', () {
      expect(
        Updater.summarise('* Something happened in https://example.test/x'),
        ['Something happened'],
      );
    });

    test('strips conventional-commit prefixes, including scopes', () {
      expect(Updater.summarise('* feat: add a thing'), ['Add a thing']);
      expect(Updater.summarise('* fix(android): stop crashing'),
          ['Stop crashing']);
      expect(Updater.summarise('* refactor(sync)!: rework'), ['Rework']);
      // A colon that is not a commit prefix must survive.
      expect(Updater.summarise('* Note: this stays'), ['Note: this stays']);
    });

    test('honours the line cap', () {
      expect(Updater.summarise(real, max: 2).length, 2);
      expect(Updater.summarise(real, max: 1), [
        'Flutter port for Windows, Android and web',
      ]);
    });

    test('empty or junk notes produce nothing rather than blank bullets', () {
      expect(Updater.summarise(''), isEmpty);
      expect(Updater.summarise('## Heading only'), isEmpty);
      expect(Updater.summarise('* https://example.test/x'), isEmpty);
      expect(Updater.summarise('\n\n   \n'), isEmpty);
    });
  });

  group('parsing a GitHub release', () {
    // Every test here pins the extension rather than inheriting the host's.
    // The first version of these did inherit it, so they passed on a Windows
    // machine and failed on the Linux CI runner — the assertions were about
    // the runner, not about the code.
    setUp(() => Updater.assetExtension = '.apk');
    tearDown(() => Updater.assetExtension = '.apk');

    String payload({
      String tag = 'v1.2.0',
      List<Map<String, Object?>>? assets,
      String body = 'Notes here',
    }) => jsonEncode({
      'tag_name': tag,
      'body': body,
      // Both builds, as a real release carries.
      'assets': assets ??
          [
            {
              'name': 'whats-due-v1.2.0.apk',
              'browser_download_url': 'https://example.test/app.apk',
              'size': 18500000,
            },
            {
              'name': 'whats-due-v1.2.0-windows.zip',
              'browser_download_url': 'https://example.test/app-windows.zip',
              'size': 28000000,
            },
          ],
    });

    test('reads the tag, version and notes', () {
      final r = Updater.parseRelease(payload())!;
      expect(r.tag, 'v1.2.0');
      expect(r.version, '1.2.0', reason: 'the leading v must be stripped');
      expect(r.notes, 'Notes here');
    });

    test('an Android build picks the APK', () {
      Updater.assetExtension = '.apk';
      final r = Updater.parseRelease(payload())!;
      expect(r.apkUrl, 'https://example.test/app.apk');
      expect(r.apkBytes, 18500000);
    });

    test('a Windows build picks the zip, though the APK is listed first', () {
      // Taking the first attachment would have the desktop app download an
      // Android package it can do nothing with.
      Updater.assetExtension = '.zip';
      final r = Updater.parseRelease(payload())!;
      expect(r.apkUrl, 'https://example.test/app-windows.zip');
      expect(r.apkBytes, 28000000);
    });

    test('a release missing the build for this platform offers nothing', () {
      // This was the desktop case until a Windows zip was published: the
      // release held only an APK, and offering that would be worse than
      // offering nothing.
      Updater.assetExtension = '.zip';
      final r = Updater.parseRelease(
        payload(assets: [
          {
            'name': 'whats-due-v1.2.0.apk',
            'browser_download_url': 'https://example.test/app.apk',
            'size': 50000000,
          },
        ]),
      )!;
      expect(r.tag, 'v1.2.0');
      expect(r.apkUrl, isNull);
    });

    test('unrelated attachments are ignored', () {
      Updater.assetExtension = '.apk';
      final r = Updater.parseRelease(
        payload(assets: [
          {
            'name': 'notes.txt',
            'browser_download_url': 'https://example.test/notes.txt',
            'size': 10,
          },
          {
            'name': 'whats-due-v1.2.0.apk',
            'browser_download_url': 'https://example.test/app.apk',
            'size': 18500000,
          },
        ]),
      )!;
      expect(r.apkUrl, 'https://example.test/app.apk');
    });

    test('a release with no assets at all parses', () {
      final r = Updater.parseRelease(payload(assets: []))!;
      expect(r.tag, 'v1.2.0');
      expect(r.apkUrl, isNull);
    });

    test('a tag without a v prefix still works', () {
      final r = Updater.parseRelease(payload(tag: '1.2.0'))!;
      expect(r.version, '1.2.0');
    });

    test('junk returns null rather than throwing', () {
      expect(Updater.parseRelease('{}'), isNull);
      expect(Updater.parseRelease('[]'), isNull);
      expect(() => Updater.parseRelease('not json'), throwsFormatException);
    });
  });

  test('a newer release is offered, an older or equal one is not', () {
    // The decision the whole feature turns on.
    const installed = '1.2.0';
    for (final (candidate, shouldOffer) in <(String, bool)>[
      ('1.2.1', true),
      ('1.3.0', true),
      ('2.0.0', true),
      ('1.10.0', true),
      ('1.2.0', false),
      ('1.1.9', false),
      ('0.9.0', false),
    ]) {
      expect(
        Updater.compareVersions(candidate, installed) > 0,
        shouldOffer,
        reason: '$candidate against installed $installed',
      );
    }
  });
}
