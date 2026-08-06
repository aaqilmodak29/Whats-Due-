import 'dart:convert';

import 'package:file_saver/file_saver.dart';

import 'models.dart';

/// Escapes commas, semicolons, backslashes and newlines per RFC 5545.
String icsEscape(String s) => s
    .replaceAllMapped(RegExp(r'([,;\\])'), (m) => '\\${m[1]}')
    .replaceAll('\n', r'\n');

String _two(int v) => v.toString().padLeft(2, '0');

/// Builds a single-event calendar file carrying three alarms.
///
/// `DTSTART` uses floating local time — no `TZID`, no trailing `Z` — so the
/// event lands at 9am wherever the owner happens to be, without shipping a
/// timezone database inside the file.
String buildIcs(Assignment a, Subject? subject) {
  final tag = subject?.name ?? '';
  final d = a.due.replaceAll('-', '');

  final now = DateTime.now().toUtc();
  final stamp =
      '${now.year}${_two(now.month)}${_two(now.day)}'
      'T${_two(now.hour)}${_two(now.minute)}${_two(now.second)}Z';

  final pending = a.tasks.where((t) => !t.done).map((t) => '- ${t.text}');
  final desc = StringBuffer()
    ..write(tag.isEmpty ? '' : '$tag — ')
    ..write('due ${longDate(a.due)}');
  if (pending.isNotEmpty) {
    desc.write('\nOutstanding:\n${pending.join('\n')}');
  }

  final summary = 'Due: ${a.title}${tag.isEmpty ? '' : ' ($tag)'}';

  return [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Coursework Tracker//EN',
    'CALSCALE:GREGORIAN',
    'BEGIN:VEVENT',
    'UID:${a.id}@coursework.local',
    'DTSTAMP:$stamp',
    'DTSTART:${d}T090000',
    'DTEND:${d}T093000',
    'SUMMARY:${icsEscape(summary)}',
    'DESCRIPTION:${icsEscape(desc.toString())}',
    // One week out.
    'BEGIN:VALARM',
    'TRIGGER:-P7D',
    'ACTION:DISPLAY',
    'DESCRIPTION:${icsEscape('One week until: ${a.title}')}',
    'END:VALARM',
    // Two days out.
    'BEGIN:VALARM',
    'TRIGGER:-P2D',
    'ACTION:DISPLAY',
    'DESCRIPTION:${icsEscape('Two days until: ${a.title}')}',
    'END:VALARM',
    // 18:00 the evening before.
    'BEGIN:VALARM',
    'TRIGGER:-PT15H',
    'ACTION:DISPLAY',
    'DESCRIPTION:${icsEscape('Due tomorrow: ${a.title}')}',
    'END:VALARM',
    'END:VEVENT',
    'END:VCALENDAR',
  ].join('\r\n');
}

String icsFileName(Assignment a) {
  final slug = a.title
      .replaceAll(RegExp('[^a-z0-9]+', caseSensitive: false), '-')
      .toLowerCase();
  final trimmed = slug.length > 40 ? slug.substring(0, 40) : slug;
  final cleaned = trimmed.replaceAll(RegExp(r'^-+|-+$'), '');
  return cleaned.isEmpty ? 'assignment' : cleaned;
}

/// Writes the calendar file out. Returns the saved location, or null if the
/// platform reported nothing useful.
Future<String?> saveIcs(Assignment a, Subject? subject) async {
  final bytes = utf8.encode(buildIcs(a, subject));
  return FileSaver.instance.saveFile(
    name: icsFileName(a),
    bytes: bytes,
    fileExtension: 'ics',
    customMimeType: 'text/calendar',
  );
}

/// Writes a full JSON backup of everything.
Future<String?> saveBackup(String json) async {
  final now = DateTime.now();
  return FileSaver.instance.saveFile(
    name: 'whats-due-backup-${formatIsoDate(now)}',
    bytes: utf8.encode(json),
    fileExtension: 'json',
    customMimeType: 'application/json',
  );
}
