import 'dart:convert';

import 'package:file_saver/file_saver.dart';

import 'models.dart';

/// Writes a full JSON backup of everything.
///
/// Sync keeps the devices in step, so this is no longer the way data moves
/// between them. It is the escape hatch: a copy that survives signing out,
/// uninstalling, or deciding to stop using the app at all.
Future<String?> saveBackup(String json) async {
  final now = clock();
  return FileSaver.instance.saveFile(
    name: 'whats-due-backup-${formatIsoDate(now)}',
    bytes: utf8.encode(json),
    fileExtension: 'json',
    customMimeType: 'application/json',
  );
}
