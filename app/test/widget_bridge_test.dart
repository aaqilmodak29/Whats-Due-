import 'package:flutter_test/flutter_test.dart';
import 'package:whats_due/models.dart';
import 'package:whats_due/planner.dart';
import 'package:whats_due/widget_bridge.dart';

/// The payload handed to the Android widget.
///
/// The Kotlin side is deliberately dumb — it renders strings and hides empty
/// rows — so everything worth testing about the widget is testable here, on the
/// Dart side, without a device.
void main() {
  final fixedNow = DateTime(2026, 8, 6, 12);
  setUp(() => clock = () => fixedNow);
  tearDown(() => clock = DateTime.now);

  String inDays(int n) => formatIsoDate(
    DateTime(fixedNow.year, fixedNow.month, fixedNow.day).add(
      Duration(days: n),
    ),
  );

  Assignment work(String id, int dueInDays, List<Task> tasks) => Assignment(
    id: id,
    title: 'Item $id',
    due: inDays(dueInDays),
    tasks: tasks,
  );

  test('fills every row slot, so stale text cannot survive a refresh', () {
    // The provider hides a row on an empty string. Omitting the key instead
    // would leave the launcher rendering yesterday's task forever.
    final payload = WidgetBridge.buildPayload(
      todayPlan([
        work('a', 1, [Task(id: 't1', text: 'Only task')]),
      ]),
    );
    for (var i = 0; i < WidgetBridge.rows; i++) {
      expect(payload.containsKey('wd_t${i}_text'), isTrue);
      expect(payload.containsKey('wd_t${i}_meta'), isTrue);
    }
    expect(payload['wd_t0_text'], 'Only task');
    expect(payload['wd_t1_text'], '');
    expect(payload['wd_t2_text'], '');
  });

  test('reports the total when the day is estimated', () {
    final payload = WidgetBridge.buildPayload(
      todayPlan([
        work('a', 0, [
          Task(id: 't1', text: 'One', minutes: 60),
          Task(id: 't2', text: 'Two', minutes: 30),
        ]),
      ]),
    );
    expect(payload['wd_headline'], 'About 1h 30m today');
  });

  test('counts the work when nothing is estimated', () {
    final payload = WidgetBridge.buildPayload(
      todayPlan([
        work('a', 1, [Task(id: 't1', text: 'One')]),
        work('b', 2, [Task(id: 't2', text: 'Two')]),
      ]),
    );
    expect(payload['wd_headline'], '2 things to pick up');
  });

  test('says how much is not shown', () {
    // Three rows must not read as the whole day.
    final payload = WidgetBridge.buildPayload(
      todayPlan([
        for (var i = 0; i < 6; i++)
          work('a$i', 0, [Task(id: 't$i', text: 'Task $i', minutes: 30)]),
      ]),
    );
    expect(payload['wd_count'], '6');
    expect(payload['wd_more'], '3');
  });

  test('carries the countdown and the estimate as the row meta', () {
    final payload = WidgetBridge.buildPayload(
      todayPlan([
        work('a', 0, [Task(id: 't1', text: 'One', minutes: 45)]),
      ]),
    );
    expect(payload['wd_t0_meta'], 'DUE TODAY · 45m');
  });

  test('omits the estimate from the meta when there is none', () {
    final payload = WidgetBridge.buildPayload(
      todayPlan([
        work('a', 1, [Task(id: 't1', text: 'One')]),
      ]),
    );
    expect(payload['wd_t0_meta'], 'TOMORROW');
  });

  test('shows the next step rather than the task it sits under', () {
    final payload = WidgetBridge.buildPayload(
      todayPlan([
        work('a', 1, [
          Task(
            id: 't1',
            text: 'Part A',
            subtasks: [SubTask(id: 's1', text: 'Draft the abstract')],
          ),
        ]),
      ]),
    );
    expect(payload['wd_t0_text'], 'Draft the abstract');
  });

  test('an empty plan still produces a complete payload', () {
    final payload = WidgetBridge.buildPayload(todayPlan([]));
    expect(payload['wd_headline'], 'Nothing to pick up');
    expect(payload['wd_count'], '0');
    expect(payload['wd_more'], '0');
    expect(payload['wd_t0_text'], '');
  });
}
