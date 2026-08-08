import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Android release manifest.
///
/// These are declarations no Dart test can otherwise reach: they only take
/// effect in a built release APK, so a mistake here compiles cleanly, passes
/// every other test, and then fails on the phone. That is exactly what happened
/// with INTERNET — sync failed with a DNS error in release while the web build
/// and the whole suite stayed green.
void main() {
  late String manifest;

  setUpAll(() {
    manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
  });

  bool declares(String permission) =>
      manifest.contains('android.permission.$permission');

  test('INTERNET is declared, or sync cannot resolve a hostname', () {
    // The Flutter template puts this in the debug and profile manifests only.
    // Without it here, a release build has no network access and every request
    // fails as "Failed host lookup ... errno = 7".
    expect(
      declares('INTERNET'),
      isTrue,
      reason: 'release builds would have no network access at all',
    );
  });

  test('notification permissions are declared', () {
    expect(declares('POST_NOTIFICATIONS'), isTrue,
        reason: 'Android 13+ needs this to post any notification');
    expect(declares('RECEIVE_BOOT_COMPLETED'), isTrue,
        reason: 'reminders would not survive a reboot');
    expect(
      declares('SCHEDULE_EXACT_ALARM') || declares('USE_EXACT_ALARM'),
      isTrue,
      reason: 'reminders would be batched instead of firing at 9am',
    );
  });

  test('the notification receivers are registered', () {
    // flutter_local_notifications delivers through these; without them a
    // scheduled reminder is armed and then never shown.
    expect(
      manifest.contains('ScheduledNotificationBootReceiver'),
      isTrue,
    );
    expect(manifest.contains('ScheduledNotificationReceiver'), isTrue);
  });

  test('the app is labelled, not left as the package name', () {
    expect(manifest.contains('android:label="What'), isTrue);
  });
}
