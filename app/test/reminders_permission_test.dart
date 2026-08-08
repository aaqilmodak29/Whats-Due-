import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_due/reminders.dart';

/// Guards the permission chain.
///
/// Reminders failed silently for a whole release: POST_NOTIFICATIONS was only
/// ever requested by the reminders switch, and the switch defaults to on, so
/// nobody ever touched it. Scheduling then succeeded and displayed nothing —
/// there is no error to catch, which is why this needs a test of its own.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  late List<String> calls;
  late Map<String, Object?> responses;

  setUp(() {
    // Two bits of setup the plugin normally gets for free on a device.
    //
    // It picks its Android implementation off defaultTargetPlatform, which on a
    // Windows host is windows; and FlutterLocalNotificationsPlatform.instance
    // is a late field the platform registrant sets at startup, which never runs
    // under `flutter test`. Without both, none of the calls under test are made
    // and the mock sees nothing at all.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    calls = [];
    // `initialize` is typed bool, not bool?: returning null from the mock makes
    // it throw, which leaves the plugin un-ready and every later call a no-op.
    responses = {'initialize': true};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return responses[call.method];
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('sendTest asks for permission before scheduling anything', () async {
    responses['areNotificationsEnabled'] = false;
    responses['requestNotificationsPermission'] = true;
    responses['canScheduleExactNotifications'] = true;

    await Reminders.sendTest();

    expect(
      calls,
      contains('requestNotificationsPermission'),
      reason: 'scheduling without the grant succeeds and shows nothing',
    );
    // And the request must come first: a schedule issued beforehand would be
    // silently dropped.
    if (calls.contains('zonedSchedule')) {
      expect(
        calls.indexOf('requestNotificationsPermission'),
        lessThan(calls.indexOf('zonedSchedule')),
      );
    }
  });

  test('a refused permission reports failure rather than false success',
      () async {
    responses['areNotificationsEnabled'] = false;
    responses['requestNotificationsPermission'] = false;
    responses['canScheduleExactNotifications'] = true;

    expect(
      await Reminders.sendTest(),
      isFalse,
      reason: 'the old code returned true and promised a notification that '
          'could never arrive',
    );
  });

  test('an already-granted permission is not re-requested', () async {
    responses['areNotificationsEnabled'] = true;
    responses['canScheduleExactNotifications'] = true;

    await Reminders.requestPermission();

    expect(calls, contains('areNotificationsEnabled'));
    expect(
      calls,
      isNot(contains('requestNotificationsPermission')),
      reason: 'asking again can return false once the prompt has been seen, '
          'which would look like a permission we do not hold',
    );
  });

  test('exact alarms are only requested when not already permitted', () async {
    responses['areNotificationsEnabled'] = true;
    responses['canScheduleExactNotifications'] = true;

    await Reminders.requestPermission();
    expect(calls, isNot(contains('requestExactAlarmsPermission')));
  });

  test('diagnose reports each link in the chain separately', () async {
    responses['areNotificationsEnabled'] = false;
    responses['canScheduleExactNotifications'] = true;
    responses['pendingNotificationRequests'] = <Object?>[];

    final d = await Reminders.diagnose();
    expect(d.notifications, isFalse);
    expect(d.exactAlarms, isTrue);
  });
}
