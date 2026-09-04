import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'models.dart';
import 'theme.dart';

/// Pushes the week's deadlines to the Android home-screen widget.
///
/// The widget answers the same question the Assignments list does — what is
/// due, and how far through it am I — rather than a second, different one. Each
/// row carries the subject, the title, the countdown and the task fraction, in
/// the same order and with the same urgency colour on its left edge, so the
/// widget reads as a cut-down view of that list rather than its own invention.
///
/// Everything here is best-effort: the widget is a convenience, and failing to
/// update it must never surface as an error in an app that is otherwise
/// working. On any platform but Android this is a no-op, so the Windows build
/// never reaches a plugin that has no Windows implementation.
class WidgetBridge {
  WidgetBridge._();

  /// Matches `android:name` on the receiver in AndroidManifest.xml.
  static const _provider = 'WhatsDueWidgetProvider';

  /// How many rows the layout has. Sending more would be silently dropped.
  static const rows = 4;

  /// The horizon the widget covers.
  static const withinDays = 7;

  /// Guards every call. Tests and the Windows build both land here and stop,
  /// so neither ever reaches a plugin with no implementation for them.
  static bool get _supported => !kIsWeb && Platform.isAndroid;

  static Future<void> push(List<Assignment> items, List<Subject> subjects)
      async {
    if (!_supported) return;
    try {
      final data = buildPayload(items, subjects);
      for (final entry in data.entries) {
        await HomeWidget.saveWidgetData<String>(entry.key, entry.value);
      }
      await HomeWidget.updateWidget(name: _provider, androidName: _provider);
    } catch (e) {
      debugPrint('WidgetBridge: could not update the home widget — $e');
    }
  }

  /// Unsubmitted, dated work falling within the next [withinDays], soonest
  /// first.
  ///
  /// Overdue work is included even though it is not, strictly, "due in the next
  /// week": it is the most urgent thing there is, and an assignment silently
  /// disappearing from the widget on the day it goes late would be the exact
  /// opposite of useful.
  static List<Assignment> dueSoon(List<Assignment> items) {
    final soon = items.where((a) {
      if (a.done) return false;
      final n = daysUntil(a.due);
      return n != null && n <= withinDays;
    }).toList();
    soon.sort((x, y) => sortKey(x).compareTo(sortKey(y)));
    return soon;
  }

  /// The flat key/value payload the Kotlin provider reads.
  ///
  /// Flat strings rather than JSON: the provider would otherwise need a parser
  /// and an error path for malformed input, to carry a handful of short lines.
  @visibleForTesting
  static Map<String, String> buildPayload(
    List<Assignment> items,
    List<Subject> subjects,
  ) {
    final soon = dueSoon(items);
    final shown = soon.take(rows).toList();

    final out = <String, String>{
      'wd_empty': soon.isEmpty
          ? 'No assignments due in the next $withinDays days'
          : '',
      'wd_count': '${soon.length}',
      // Named so the widget can say "and 2 more" rather than implying the rows
      // it shows are everything.
      'wd_more': '${soon.length - shown.length}',
    };

    for (var i = 0; i < rows; i++) {
      final a = i < shown.length ? shown[i] : null;
      // Every slot is written on every push, including the empty ones. Omitting
      // a key would leave the launcher rendering last week's deadline forever.
      out['wd_t${i}_subject'] = a == null
          ? ''
          : _subjectName(a, subjects).toUpperCase();
      out['wd_t${i}_title'] = a?.title ?? '';
      out['wd_t${i}_count'] = a == null ? '' : countdown(daysUntil(a.due));
      out['wd_t${i}_progress'] = a == null ? '' : _progress(a);
      // The urgency channel, as an ARGB int the provider paints onto the row's
      // left edge — the same spine the card in the list carries.
      //
      // Resolved against the light palette rather than whichever theme the app
      // is showing: the launcher draws this, and follows the system's dark mode
      // through values-night rather than the app's own toggle.
      out['wd_t${i}_spine'] = a == null
          ? '0'
          : '${urgency(daysUntil(a.due), Palette.light).toARGB32()}';
    }
    return out;
  }

  /// The widget has no access to the store, so the payload carries the resolved
  /// subject name rather than its id.
  static String _subjectName(Assignment a, List<Subject> subjects) =>
      subjects.where((s) => s.id == a.subjectId).firstOrNull?.name ?? 'Unfiled';

  static String _progress(Assignment a) =>
      a.tasks.isEmpty ? 'NO TASKS' : '${a.finishedTasks}/${a.tasks.length}';
}
