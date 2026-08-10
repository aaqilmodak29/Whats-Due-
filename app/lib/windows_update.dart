import 'dart:io';

import 'package:flutter/foundation.dart';

/// Replaces a running Windows install with a freshly downloaded one.
///
/// A process cannot overwrite its own executable while it is running, so the
/// swap is handed to a PowerShell script that waits for this process to exit,
/// copies the new files over, and starts the app again. The app then quits.
///
/// The risk here is obvious — this deletes and replaces the directory the app
/// is running from — so the order is chosen to fail safe:
///
///   1. verify the extracted payload actually contains the executable
///   2. copy the current install aside as a backup
///   3. only then copy the new files over
///   4. on any failure, restore the backup and relaunch what was there before
///
/// The worst case is the app reappearing at its old version, not a half-written
/// install directory.
class WindowsUpdate {
  WindowsUpdate._();

  static const _exeName = 'whats_due.exe';

  /// Unpacks [zip] into a staging folder and returns it, or null on failure.
  ///
  /// Extraction goes through PowerShell rather than a Dart zip package: it is
  /// already present on every Windows machine, and this whole file is
  /// Windows-only, so a cross-platform dependency would buy nothing.
  static Future<Directory?> stage(File zip) async {
    final staging = Directory(
      '${Directory.systemTemp.path}\\whats-due-update',
    );
    try {
      if (staging.existsSync()) staging.deleteSync(recursive: true);
      staging.createSync(recursive: true);

      final result = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        'Expand-Archive -LiteralPath "${zip.path}" '
            '-DestinationPath "${staging.path}" -Force',
      ]);
      if (result.exitCode != 0) {
        debugPrint('WindowsUpdate: extract failed — ${result.stderr}');
        return null;
      }

      // A zip that unpacked without the executable would leave the install
      // broken if copied over it.
      if (!File('${staging.path}\\$_exeName').existsSync()) {
        debugPrint('WindowsUpdate: no $_exeName in the archive');
        return null;
      }
      return staging;
    } catch (e) {
      debugPrint('WindowsUpdate: staging failed — $e');
      return null;
    }
  }

  /// Launches the swap and returns true once it is under way, at which point
  /// the caller should exit promptly — the script is waiting on this process.
  static Future<bool> handOff(Directory staging) async {
    try {
      final exe = File(Platform.resolvedExecutable);
      final installDir = exe.parent.path;
      final script = File(
        '${Directory.systemTemp.path}\\whats-due-apply-update.ps1',
      );

      // $PID is a read-only automatic variable in PowerShell, hence AppPid.
      script.writeAsStringSync(r'''
param([int]$AppPid, [string]$Source, [string]$Target, [string]$Exe)
$ErrorActionPreference = 'Stop'

# Wait for the app to let go of its own files.
$deadline = (Get-Date).AddSeconds(60)
while ((Get-Process -Id $AppPid -ErrorAction SilentlyContinue) -and
       ((Get-Date) -lt $deadline)) {
  Start-Sleep -Milliseconds 250
}
Start-Sleep -Milliseconds 500

$backup = Join-Path $env:TEMP ('whats-due-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
try {
  # Keep a copy before touching anything, so a failure is recoverable.
  Copy-Item -LiteralPath $Target -Destination $backup -Recurse -Force
  Copy-Item -Path (Join-Path $Source '*') -Destination $Target -Recurse -Force
  Start-Process -FilePath $Exe
} catch {
  # Put back whatever was there and start it, rather than leaving a
  # half-written install behind.
  if (Test-Path $backup) {
    Copy-Item -Path (Join-Path $backup '*') -Destination $Target -Recurse -Force
    Start-Process -FilePath $Exe
  }
  exit 1
}
''', flush: true);

      await Process.start(
        'powershell',
        [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy', 'Bypass',
          '-File', script.path,
          '-AppPid', '$pid',
          '-Source', staging.path,
          '-Target', installDir,
          '-Exe', exe.path,
        ],
        // Detached, or the script dies with the process it is waiting for.
        mode: ProcessStartMode.detached,
      );
      return true;
    } catch (e) {
      debugPrint('WindowsUpdate: hand-off failed — $e');
      return false;
    }
  }
}
