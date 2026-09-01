import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'models.dart';
import 'planner.dart';

/// Pushes today's plan to the Android home-screen widget.
///
/// Deliberately the same [todayPlan] the Today tab renders, rather than a
/// second "next few deadlines" rule. Two rules would drift, and a widget that
/// disagrees with the app is worse than no widget.
///
/// Everything here is best-effort: the widget is a convenience, and a failure
/// to update it must never surface as an error in an app that is otherwise
/// working. On any platform but Android this is a no-op, so the Windows build
/// never reaches a plugin that has no Windows implementation.
class WidgetBridge {
  WidgetBridge._();

  /// Matches `android:name` on the receiver in AndroidManifest.xml.
  static const _provider = 'WhatsDueWidgetProvider';

  /// How many rows the layout has. Sending more would be silently dropped.
  static const rows = 3;

  /// Guards every call. Tests and the Windows build both land here and stop,
  /// so neither ever reaches a plugin with no implementation for them.
  static bool get _supported => !kIsWeb && Platform.isAndroid;

  static Future<void> push(List<Assignment> items) async {
    if (!_supported) return;
    try {
      final data = buildPayload(todayPlan(items));
      for (final entry in data.entries) {
        await HomeWidget.saveWidgetData<String>(entry.key, entry.value);
      }
      await HomeWidget.updateWidget(name: _provider, androidName: _provider);
    } catch (e) {
      debugPrint('WidgetBridge: could not update the home widget — $e');
    }
  }

  /// The flat key/value payload the Kotlin provider reads.
  ///
  /// Flat strings rather than JSON: the provider would otherwise need a parser
  /// and an error path for malformed input, to carry four short lines.
  @visibleForTesting
  static Map<String, String> buildPayload(DayPlan plan) {
    final shown = plan.tasks.take(rows).toList();
    final out = <String, String>{
      'wd_headline': plan.isEmpty
          ? 'Nothing to pick up'
          : plan.estimatedMinutes > 0
          ? 'About ${formatMinutes(plan.estimatedMinutes)} today'
          : '${plan.tasks.length} ${plan.tasks.length == 1 ? 'thing' : 'things'} to pick up',
      'wd_count': '${plan.tasks.length}',
      // Named so the widget can say "and 4 more" rather than implying the three
      // it shows are the whole day.
      'wd_more': '${plan.tasks.length - shown.length}',
    };

    for (var i = 0; i < rows; i++) {
      final p = i < shown.length ? shown[i] : null;
      out['wd_t${i}_text'] = p?.label ?? '';
      out['wd_t${i}_meta'] = p == null ? '' : _meta(p);
    }
    return out;
  }

  static String _meta(PlannedTask p) {
    final n = daysUntil(p.assignment.due);
    final parts = [
      countdown(n),
      if (p.minutes != null) formatMinutes(p.minutes!),
    ];
    return parts.join(' · ');
  }
}
