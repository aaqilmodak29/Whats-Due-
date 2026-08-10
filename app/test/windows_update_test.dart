import 'package:flutter_test/flutter_test.dart';
import 'package:whats_due/windows_update.dart';

/// Guards the generated update script.
///
/// This is the only code in the project that deletes and replaces the directory
/// the app runs from, and it executes after the app has exited — so nothing it
/// does can be caught, retried, or reported at the time. What it says has to be
/// right before it is handed over.
void main() {
  String script({
    String source = r'C:\Users\me\AppData\Local\Temp\whats-due-update',
    String target = r'C:\Apps\WhatsDue',
    String exe = r'C:\Apps\WhatsDue\whats_due.exe',
  }) => WindowsUpdate.buildScript(
    appPid: 4242,
    source: source,
    target: target,
    exe: exe,
    log: r'C:\Temp\whats-due-update.log',
  );

  group('quoting', () {
    test('a path with spaces stays one argument', () {
      final s = script(target: r'C:\Program Files\What Is Due');
      expect(s, contains(r"'C:\Program Files\What Is Due'"));
    });

    test('a path with both a space and an apostrophe survives', () {
      final s = script(target: r"C:\Users\O'Brien\My Apps");
      expect(s, contains(r"'C:\Users\O''Brien\My Apps'"));
    });

    test('an apostrophe is doubled, not left to end the string early', () {
      // "C:\Users\O'Brien\App" would otherwise terminate the literal and turn
      // the rest of the path into stray PowerShell.
      expect(
        WindowsUpdate.psLiteral(r"C:\Users\O'Brien\App"),
        r"'C:\Users\O''Brien\App'",
      );
    });

    test('every path in the script is quoted', () {
      final s = script();
      for (final line in s.split('\n')) {
        if (line.startsWith(r'$Source') ||
            line.startsWith(r'$Target') ||
            line.startsWith(r'$Exe')) {
          final value = line.split('=')[1].trim();
          expect(value, startsWith("'"), reason: line);
          expect(value, endsWith("'"), reason: line);
        }
      }
    });
  });

  group('the sequence that makes it recoverable', () {
    final s = script();

    test('it waits for the app to exit before touching anything', () {
      final wait = s.indexOf('Get-Process -Id');
      final copy = s.indexOf('copying new files');
      expect(wait, greaterThan(-1));
      expect(wait, lessThan(copy), reason: 'files are held open until it exits');
    });

    test('it backs up before it overwrites', () {
      expect(
        s.indexOf('backing up'),
        lessThan(s.indexOf('copying new files')),
        reason: 'the backup is the only way back from a failed copy',
      );
    });

    test('it verifies the executable landed', () {
      expect(s, contains('whats_due.exe'));
      expect(s, contains('after the copy'));
    });

    test('a failure restores the backup and relaunches', () {
      final catchBlock = s.substring(s.indexOf('} catch {'));
      expect(catchBlock, contains('restoring from'));
      expect(catchBlock, contains('Copy-Item'));
      expect(catchBlock, contains('Start-Process'));
      expect(catchBlock, contains('exit 1'));
    });

    test('it logs, so a failure leaves an explanation', () {
      // The first version logged nothing. When it silently never ran, there was
      // no way to tell that from the app having crashed.
      expect(s, contains('Start-Transcript'));
      expect(s, contains('Stop-Transcript'));
      expect(s, contains('FAILED:'));
    });

    test('it stops on error rather than ploughing on', () {
      expect(s, contains(r"$ErrorActionPreference = 'Stop'"));
    });
  });

  test('the pid it waits on is the one it was given', () {
    expect(script(), contains(r'$AppPid = 4242'));
  });
}
