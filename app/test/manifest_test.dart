import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whats_due/widget_bridge.dart';

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

  test('REQUEST_INSTALL_PACKAGES is declared, or in-app updates cannot install', () {
    expect(
      declares('REQUEST_INSTALL_PACKAGES'),
      isTrue,
      reason: 'the downloaded APK could not be handed to the installer',
    );
  });

  test('the app is labelled, not left as the package name', () {
    expect(manifest.contains('android:label="What'), isTrue);
  });

  group('the home-screen widget', () {
    test('the provider is registered and exported', () {
      // The launcher is a different process. An unexported provider never
      // appears in the widget picker, and nothing about that shows up at build
      // time — the APK is valid, the widget is simply missing.
      final receiver = RegExp(
        r'<receiver[^>]*android:name="\.WhatsDueWidgetProvider"'
        r'[\s\S]*?</receiver>',
      ).firstMatch(manifest)?.group(0);

      expect(receiver, isNotNull, reason: 'no widget receiver declared');
      expect(
        receiver,
        contains('android:exported="true"'),
        reason: 'the launcher could not bind it',
      );
      expect(
        receiver,
        contains('android.appwidget.action.APPWIDGET_UPDATE'),
        reason: 'the system would never ask it to draw',
      );
      expect(
        receiver,
        contains('@xml/whats_due_widget_info'),
        reason: 'without the metadata it is not a widget provider at all',
      );
    });

    test('the resources it names all exist', () {
      // A missing drawable or layout fails the resource link step rather than
      // the Dart analyzer, so it is worth catching without a full APK build.
      for (final path in const [
        'android/app/src/main/res/xml/whats_due_widget_info.xml',
        'android/app/src/main/res/layout/whats_due_widget.xml',
        'android/app/src/main/res/drawable/whats_due_widget_background.xml',
        'android/app/src/main/res/values/whats_due_widget.xml',
        'android/app/src/main/kotlin/com/aaqilmodak/whats_due/'
            'WhatsDueWidgetProvider.kt',
      ]) {
        expect(File(path).existsSync(), isTrue, reason: '$path is missing');
      }
    });

    test('every field the payload fills exists in the layout', () {
      // The Dart side writes a fixed set of ids per row; the layout has to
      // carry every one, or that field is silently dropped at render time with
      // nothing failing at build time.
      final layout = File(
        'android/app/src/main/res/layout/whats_due_widget.xml',
      ).readAsStringSync();
      for (var i = 0; i < WidgetBridge.rows; i++) {
        expect(layout, contains('@+id/wd_row$i'));
        for (final field in const [
          'spine',
          'subject',
          'title',
          'count',
          'progress',
        ]) {
          expect(layout, contains('@+id/wd_t${i}_$field'));
        }
      }
      expect(layout, contains('@+id/wd_empty'));
      expect(layout, contains('@+id/wd_more'));
      expect(layout, contains('@+id/wd_root'));
    });

    test('the Kotlin provider wires up every row the layout has', () {
      // A row present in the layout but missing from the provider's list
      // renders permanently blank, which no build step catches.
      final kotlin = File(
        'android/app/src/main/kotlin/com/aaqilmodak/whats_due/'
        'WhatsDueWidgetProvider.kt',
      ).readAsStringSync();
      for (var i = 0; i < WidgetBridge.rows; i++) {
        expect(kotlin, contains('R.id.wd_row$i'));
        expect(kotlin, contains('R.id.wd_t${i}_spine'));
      }
    });
  });
}
