import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';
import 'reminder_schedule.dart';

/// Real on-device reminders, and the only reminder mechanism in the app.
///
/// Calendar (`.ics`) export used to sit alongside this, because a web page
/// cannot schedule its own future notifications and handing the deadline to the
/// phone's calendar was the only way to get one. Now that the desktop and phone
/// builds are the product, that indirection is gone: notifications are
/// scheduled directly, six per deadline. See [Milestone] for the schedule.
///
/// Assignments that come due at the same moment are collapsed into a single
/// notification — see [planReminders].
class Reminders {
  Reminders._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  static bool _ready = false;

  /// Set once initialisation has been tried, successfully or not. Without it a
  /// failed init is retried on every mutation — which is exactly what happens
  /// under test, where the platform channels do not exist.
  static bool _attempted = false;

  /// True once the OS has actually granted permission to post notifications.
  static bool granted = false;

  static const _channelId = 'whats_due_deadlines';

  static Future<void> init() async {
    if (_attempted) return;
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
    await init();
    if (!_ready) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        // Already granted: asking again returns false on some versions once
        // the prompt has been dismissed, so checking first avoids reporting a
        // failure for a permission we actually hold.
        granted = await android.areNotificationsEnabled() ?? false;
        if (!granted) {
          granted = await android.requestNotificationsPermission() ?? false;
        }
        // Best-effort: without this, scheduling silently downgrades to
        // inexact timing rather than failing.
        if (await android.canScheduleExactNotifications() == false) {
          await android.requestExactAlarmsPermission();
        }
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
    await init();
    if (!_ready) return;

    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Reminders: cancelAll failed — $e');
      return;
    }
    if (!enabled) return;

    Subject? subjectOf(Assignment a) =>
        subjects.where((s) => s.id == a.subjectId).firstOrNull;

    final groups = planReminders(items, now: clock());
    var id = 1;

    for (final group in groups) {
      final when = tz.TZDateTime.from(group.when, tz.local);
      try {
        await _plugin.zonedSchedule(
          id: id++,
          title: group.title(subjectOf),
          body: group.body(subjectOf),
          scheduledDate: when,
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('Reminders: schedule failed for ${group.when} — $e');
      }
    }
    debugPrint('Reminders: scheduled ${groups.length} notifications');
  }

  /// How many reminders are currently queued with the OS. Shown in the backup
  /// screen so the setting is verifiable rather than a matter of faith.
  static Future<int> pendingCount() async {
    if (!_ready) return 0;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return pending.length;
    } catch (_) {
      return 0;
    }
  }

  /// What the OS currently allows, so "reminders aren't working" is an
  /// answerable question rather than a guess.
  ///
  /// Every field is separately capable of silently swallowing a reminder:
  /// scheduling succeeds and returns normally whether or not the notification
  /// will ever be shown, which is exactly how a missing POST_NOTIFICATIONS
  /// grant went unnoticed.
  static Future<({bool ready, bool? notifications, bool? exactAlarms, int pending})>
      diagnose() async {
    await init();
    if (!_ready) {
      return (ready: false, notifications: null, exactAlarms: null, pending: 0);
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    bool? notifications;
    bool? exact;
    try {
      notifications = await android?.areNotificationsEnabled();
      exact = await android?.canScheduleExactNotifications();
    } catch (e) {
      debugPrint('Reminders: could not read permission state — $e');
    }
    return (
      ready: true,
      notifications: notifications,
      exactAlarms: exact,
      pending: await pendingCount(),
    );
  }

  /// Fires a notification a few seconds out, so the permission chain can be
  /// tested without waiting for a real deadline.
  ///
  /// Asks for permission first. Scheduling without it succeeds and shows
  /// nothing, so a test that skipped this step reported success and then sat
  /// there silently — which is precisely what happened.
  static Future<bool> sendTest() async {
    await init();
    if (!_ready) return false;
    if (!await requestPermission()) return false;
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
