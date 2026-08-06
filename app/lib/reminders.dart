import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

/// Real on-device reminders — the one thing the web build could not do.
///
/// The web app shipped `.ics` export instead, because a web page cannot
/// schedule its own future notifications: the Notification Triggers API never
/// shipped broadly, and genuine push would have meant a service worker, a push
/// subscription and a server. A native app needs none of that, so the three
/// alarms the `.ics` carried are now also scheduled locally:
///
///   * 7 days before, 09:00
///   * 2 days before, 09:00
///   * 18:00 the evening before
///
/// `.ics` export is kept alongside this, unchanged. The two are complementary:
/// notifications live in the app, calendar events live in the phone's calendar
/// and survive uninstalling.
class Reminders {
  Reminders._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  /// The plugin has no meaningful web implementation — a browser tab cannot be
  /// relied on to fire a notification days later while closed. On web the
  /// `.ics` export stays the only reminder path, exactly as before.
  static bool get platformSupported => !kIsWeb;

  static bool _ready = false;

  /// Set once initialisation has been tried, successfully or not. Without it a
  /// failed init is retried on every mutation — which is exactly what happens
  /// under test, where the platform channels do not exist.
  static bool _attempted = false;

  /// True once the OS has actually granted permission to post notifications.
  static bool granted = false;

  static const _channelId = 'whats_due_deadlines';

  static Future<void> init() async {
    if (!platformSupported || _attempted) return;
    _attempted = true;
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Falls back to whatever `tz.local` defaults to. Scheduling still works;
      // it just may drift by the UTC offset, so failing soft beats crashing.
    }

    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          macOS: DarwinInitializationSettings(),
          windows: WindowsInitializationSettings(
            appName: "What's due",
            appUserModelId: 'com.aaqilmodak.whatsDue',
            guid: '6b6f4d21-2f8a-4f0c-9a7e-8c1f0b3d5e42',
          ),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Reminders: init failed — $e');
    }
  }

  /// Asks the OS for permission. Returns whether it was granted.
  ///
  /// Android 13+ needs `POST_NOTIFICATIONS` at runtime, and exact alarms are a
  /// separate grant again. Both are requested; neither failing is fatal.
  static Future<bool> requestPermission() async {
    if (!platformSupported) return false;
    await init();
    if (!_ready) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        granted = await android.requestNotificationsPermission() ?? false;
        // Best-effort: without this, scheduling silently downgrades to
        // inexact timing rather than failing.
        await android.requestExactAlarmsPermission();
        return granted;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        granted = await ios.requestPermissions(alert: true, sound: true) ??
            false;
        return granted;
      }
    } catch (e) {
      debugPrint('Reminders: permission request failed — $e');
      return false;
    }
    // Desktop platforms have no runtime prompt.
    granted = true;
    return true;
  }

  static NotificationDetails get _details => const NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Deadlines',
      channelDescription: 'Reminders that coursework is coming due.',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
    macOS: DarwinNotificationDetails(),
    windows: WindowsNotificationDetails(),
  );

  /// Replaces every scheduled reminder with a fresh set derived from [items].
  ///
  /// Cancel-all-then-reschedule rather than tracking ids per assignment: the
  /// lists are tens of items, and rebuilding from scratch removes the same
  /// class of sync bugs that full re-render removes in the UI. It also means
  /// notification ids can be a plain running counter.
  static Future<void> sync(
    List<Assignment> items,
    List<Subject> subjects, {
    required bool enabled,
  }) async {
    if (!platformSupported) return;
    await init();
    if (!_ready) return;

    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Reminders: cancelAll failed — $e');
      return;
    }
    if (!enabled) return;

    final now = tz.TZDateTime.now(tz.local);
    var id = 1;

    for (final a in items) {
      if (a.done || a.due.isEmpty) continue;
      final date = parseIsoDate(a.due);
      if (date == null) continue;

      final subject = subjects.where((s) => s.id == a.subjectId).firstOrNull;
      final tag = subject == null ? '' : ' (${subject.name})';
      final nineAm = tz.TZDateTime(
        tz.local,
        date.year,
        date.month,
        date.day,
        9,
      );

      final schedule = <(tz.TZDateTime, String)>[
        (nineAm.subtract(const Duration(days: 7)), 'One week until'),
        (nineAm.subtract(const Duration(days: 2)), 'Two days until'),
        (nineAm.subtract(const Duration(hours: 15)), 'Due tomorrow —'),
      ];

      for (final (fireAt, lead) in schedule) {
        if (!fireAt.isAfter(now)) continue; // never schedule into the past
        final pending = a.tasks.where((t) => !t.done).length;
        try {
          await _plugin.zonedSchedule(
            id: id++,
            title: '$lead ${a.title}$tag',
            body: pending == 0
                ? 'Due ${longDate(a.due)}.'
                : 'Due ${longDate(a.due)} — $pending task${pending == 1 ? '' : 's'} outstanding.',
            scheduledDate: fireAt,
            notificationDetails: _details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        } catch (e) {
          debugPrint('Reminders: schedule failed for ${a.title} — $e');
        }
      }
    }
  }

  /// How many reminders are currently queued with the OS. Shown in the backup
  /// screen so the setting is verifiable rather than a matter of faith.
  static Future<int> pendingCount() async {
    if (!platformSupported || !_ready) return 0;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return pending.length;
    } catch (_) {
      return 0;
    }
  }

  /// Fires a notification a few seconds out, so the permission chain can be
  /// tested without waiting for a real deadline.
  static Future<bool> sendTest() async {
    if (!platformSupported) return false;
    await init();
    if (!_ready) return false;
    try {
      await _plugin.zonedSchedule(
        id: 999999,
        title: 'Reminders are working',
        body: 'This is what a deadline reminder will look like.',
        scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      return true;
    } catch (e) {
      debugPrint('Reminders: test failed — $e');
      return false;
    }
  }
}
