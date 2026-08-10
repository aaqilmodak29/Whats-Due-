import 'dart:io';

import 'package:flutter/foundation.dart';

/// Replaces a running Windows install with a freshly downloaded one.
///
/// A process cannot overwrite its own executable while it is running, so the
/// swap is handed to a PowerShell script that waits for this process to exit,
/// copies the new files over, and starts the app again. The app then quits.
///
/// The risk here is obvious — this replaces the directory the app is running
/// from — so the order is chosen to fail safe:
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

  /// Everything the helper does is written here, so a failed update leaves an
  /// explanation instead of an app that simply never came back. The first
  /// version logged nothing, and the failure was invisible.
  static String get logPath =>
      '${Directory.systemTemp.path}\\whats-due-update.log';

  /// Unpacks [zip] into a staging folder and returns it, or null on failure.
  ///
  /// Extraction goes through PowerShell rather than a Dart zip package: it is
  /// already present on every Windows machine, and this whole file is
  /// Windows-only, so a cross-platform dependency would buy nothing.
  static Future<Directory?> stage(File zip) async {
    final staging = Directory('${Directory.systemTemp.path}\\whats-due-update');
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

  /// A PowerShell single-quoted literal, so a path containing a space or a
  /// quote cannot split into two arguments or break out of the string.
  @visibleForTesting
  static String psLiteral(String value) => "'${value.replaceAll("'", "''")}'";

  /// The helper script, with every value baked in.
  ///
  /// Embedded rather than passed as arguments: the launcher goes through cmd's
  /// `start`, and threading quoted paths intact through both cmd and PowerShell
  /// is a well-known way to get subtly wrong behaviour the first time a path
  /// contains a space.
  @visibleForTesting
  static String buildScript({
    required int appPid,
    required String source,
    required String target,
    required String exe,
    required String log,
  }) =>
      '''
\$ErrorActionPreference = 'Stop'
Start-Transcript -Path ${psLiteral(log)} -Force | Out-Null

\$AppPid = $appPid
\$Source = ${psLiteral(source)}
\$Target = ${psLiteral(target)}
\$Exe    = ${psLiteral(exe)}

Write-Output "waiting for pid \$AppPid to exit"
\$deadline = (Get-Date).AddSeconds(60)
while ((Get-Process -Id \$AppPid -ErrorAction SilentlyContinue) -and
       ((Get-Date) -lt \$deadline)) {
  Start-Sleep -Milliseconds 250
}
# A moment more for Windows to release the file handles.
Start-Sleep -Milliseconds 750

\$backup = Join-Path \$env:TEMP ('whats-due-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
try {
  Write-Output "backing up \$Target to \$backup"
  Copy-Item -LiteralPath \$Target -Destination \$backup -Recurse -Force

  Write-Output "copying new files over \$Target"
  Copy-Item -Path (Join-Path \$Source '*') -Destination \$Target -Recurse -Force

  if (-not (Test-Path (Join-Path \$Target '$_exeName'))) {
    throw "no $_exeName in \$Target after the copy"
  }

  Write-Output "relaunching \$Exe"
  Start-Process -FilePath \$Exe
  Write-Output "done"
} catch {
  Write-Output "FAILED: \$_"
  if (Test-Path \$backup) {
    Write-Output "restoring from \$backup"
    Copy-Item -Path (Join-Path \$backup '*') -Destination \$Target -Recurse -Force
    Start-Process -FilePath \$Exe
  }
  Stop-Transcript | Out-Null
  exit 1
}
Stop-Transcript | Out-Null
''';

  /// Launches the swap and returns true once it is under way, at which point
  /// the caller should exit promptly — the script is waiting on this process.
  static Future<bool> handOff(Directory staging) async {
    try {
      final exe = File(Platform.resolvedExecutable);
      final script = File(
        '${Directory.systemTemp.path}\\whats-due-apply-update.ps1',
      );
      script.writeAsStringSync(
        buildScript(
          appPid: pid,
          source: staging.path,
          target: exe.parent.path,
          exe: exe.path,
          log: logPath,
        ),
        flush: true,
      );

      // Launched through cmd's `start`, not as a direct child.
      //
      // ProcessStartMode.detached is not enough: a detached child is still a
      // child, and when the app called exit(0) a moment later Windows tore the
      // helper down with it. The script was written to disk and never ran, so
      // the app closed and simply never came back. Measured both ways — the
      // detached child dies, the one handed to `start` survives.
      await Process.start(
        'cmd',
        [
          '/c',
          'start',
          '""', // `start` reads the first quoted argument as a window title
          '/min',
          'powershell',
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          script.path,
        ],
        mode: ProcessStartMode.detached,
        runInShell: false,
      );
      return true;
    } catch (e) {
      debugPrint('WindowsUpdate: hand-off failed — $e');
      return false;
    }
  }
}
