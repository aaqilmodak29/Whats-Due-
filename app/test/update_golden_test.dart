import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_due/theme.dart';
import 'package:whats_due/ui/update_section.dart';
import 'package:whats_due/updater.dart';

/// Snapshot of the update panel in each state it can be in.
Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      loader.addFont(Future.value(ByteData.sublistView(await File(path).readAsBytes())));
    }
    await loader.load();
  }
  await load('Inter', ['assets/fonts/Inter-Variable.ttf']);
  await load('PlexMono', [
    'assets/fonts/IBMPlexMono-Regular.ttf',
    'assets/fonts/IBMPlexMono-SemiBold.ttf',
  ]);
  final root = Platform.environment['FLUTTER_ROOT'] ?? '';
  final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) await load('MaterialIcons', [icons.path]);
}

const realNotes = '''
## What's Changed
* feat: Flutter port for Windows, Android and web by @aaqilmodak29 in https://github.com/aaqilmodak29/Whats-Due-/pull/1
* feat(sync): share one list across Windows, Android and web by @aaqilmodak29 in https://github.com/aaqilmodak29/Whats-Due-/pull/2
* refactor(sync): inject Firebase config at build time instead of hardc... by @aaqilmodak29 in https://github.com/aaqilmodak29/Whats-Due-/pull/3
* Secrets out of git by @aaqilmodak29 in https://github.com/aaqilmodak29/Whats-Due-/pull/4
* ci: harden the workflows before the repository goes public by @aaqilmodak29 in https://github.com/aaqilmodak29/Whats-Due-/pull/5

## New Contributors
* @aaqilmodak29 made their first contribution in https://github.com/aaqilmodak29/Whats-Due-/pull/1

**Full Changelog**: https://github.com/aaqilmodak29/Whats-Due-/commits/v1.0.1
''';

class FakeUpdater extends Updater {
  FakeUpdater(this._status, this._release, this._version, [this._msg, this._prog = 0]);
  final UpdateStatus _status;
  final Release? _release;
  final String _version;
  final String? _msg;
  final double _prog;
  @override UpdateStatus get status => _status;
  @override Release? get release => _release;
  @override String get currentVersion => _version;
  @override String? get message => _msg;
  @override double get progress => _prog;
}

void main() {
  setUpAll(() async {
    await _loadFonts();
    // Render the Android layout: tests run on the host, which would otherwise
    // only ever capture the desktop variant the phone never sees.
    Updater.canSelfInstall = true;
  });

  Future<void> shot(WidgetTester t, Updater u, String name) async {
    t.view.devicePixelRatio = 1.0;
    t.view.physicalSize = const Size(430, 620);
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        backgroundColor: C.paper,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: UpdateSection(updater: u),
        ),
      ),
    ));
    await t.pumpAndSettle();
    await expectLater(find.byType(UpdateSection), matchesGoldenFile('goldens/update-$name.png'));
  }

  final release = const Release(
    tag: 'v1.0.1', version: '1.0.1', notes: realNotes,
    apkUrl: 'https://example.test/a.apk', apkBytes: 53000000,
  );

  testWidgets('available', (t) => shot(t, FakeUpdater(UpdateStatus.available, release, '1.0.0'), 'available'));
  testWidgets('up to date', (t) => shot(t, FakeUpdater(UpdateStatus.upToDate, null, '1.0.1', 'Running the latest version.'), 'uptodate'));
  testWidgets('downloading', (t) => shot(t, FakeUpdater(UpdateStatus.downloading, release, '1.0.0', null, 0.42), 'downloading'));

  testWidgets('desktop, cannot self install', (t) async {
    Updater.canSelfInstall = false;
    addTearDown(() => Updater.canSelfInstall = true);
    await shot(t, FakeUpdater(UpdateStatus.available, release, '1.0.0'), 'desktop');
  });

  testWidgets('check failed', (t) => shot(t, FakeUpdater(UpdateStatus.failed, null, '1.0.1', 'Could not reach GitHub.'), 'failed'));
}
