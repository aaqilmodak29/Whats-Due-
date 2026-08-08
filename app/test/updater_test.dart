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

  group('parsing a GitHub release', () {
    String payload({
      String tag = 'v1.2.0',
      List<Map<String, Object?>>? assets,
      String body = 'Notes here',
    }) => jsonEncode({
      'tag_name': tag,
      'body': body,
      'assets': assets ??
          [
            {
              'name': 'whats-due-v1.2.0.apk',
              'browser_download_url': 'https://example.test/app.apk',
              'size': 18500000,
            },
          ],
    });

    test('reads the tag, version, notes and APK asset', () {
      final r = Updater.parseRelease(payload())!;
      expect(r.tag, 'v1.2.0');
      expect(r.version, '1.2.0', reason: 'the leading v must be stripped');
      expect(r.notes, 'Notes here');
      expect(r.apkUrl, 'https://example.test/app.apk');
      expect(r.apkBytes, 18500000);
    });

    test('picks the APK out of a release with several attachments', () {
      final r = Updater.parseRelease(
        payload(assets: [
          {
            'name': 'source.zip',
            'browser_download_url': 'https://example.test/src.zip',
            'size': 100,
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

    test('a release with no APK parses, but offers nothing to install', () {
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
