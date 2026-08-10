import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'windows_update.dart';

enum UpdateStatus { idle, checking, upToDate, available, downloading, ready, failed }

/// A release newer than what is running.
class Release {
  const Release({
    required this.tag,
    required this.version,
    required this.notes,
    required this.apkUrl,
    required this.apkBytes,
  });

  final String tag;

  /// The tag without its leading `v`, matching what [PackageInfo] reports.
  final String version;
  final String notes;
  final String? apkUrl;
  final int apkBytes;
}

/// Checks GitHub Releases for a newer build and installs it.
///
/// Replaces copying an APK to the phone by hand after every change. The release
/// workflow publishes a signed APK on a version tag; this finds it, downloads
/// it, and hands it to Android's package installer.
///
/// The update only installs if it is signed with the same key as what is
/// already there — which is why release signing uses a committed-nowhere
/// keystore shared with CI rather than Flutter's per-machine debug key.
class Updater extends ChangeNotifier {
  static const repo = 'aaqilmodak29/Whats-Due-';
  static const releasesPage = 'https://github.com/$repo/releases/latest';

  /// Android installs an APK over itself; Windows swaps its own directory via
  /// a helper script. Both are covered — this was Android-only at first, which
  /// left the desktop app permanently stuck, pointing at a releases page that
  /// held nothing it could run.
  ///
  /// A field rather than a getter so snapshot tests can render either layout.
  /// Tests run on the host and would otherwise only ever capture one.
  static bool canSelfInstall =
      !kIsWeb && (Platform.isAndroid || Platform.isWindows);

  /// The file extension this platform can actually install.
  ///
  /// A field rather than a getter, like [canSelfInstall], so tests can assert
  /// both platforms' selection whatever host they run on. The first version of
  /// those tests derived it from the host and passed on Windows while failing
  /// on the Linux CI runner.
  static String assetExtension =
      !kIsWeb && Platform.isWindows ? '.zip' : '.apk';

  UpdateStatus _status = UpdateStatus.idle;
  Release? _release;
  String? _message;
  double _progress = 0;
  String? _downloadedPath;
  String _currentVersion = '';

  UpdateStatus get status => _status;
  Release? get release => _release;
  String? get message => _message;
  double get progress => _progress;
  String get currentVersion => _currentVersion;

  void _set(UpdateStatus status, [String? message]) {
    _status = status;
    _message = message;
    notifyListeners();
  }

  /// Compares dotted version strings numerically.
  ///
  /// String comparison would put "1.10.0" before "1.9.0", which is exactly the
  /// point at which an update would silently stop being offered.
  @visibleForTesting
  static int compareVersions(String a, String b) {
    List<int> parts(String v) => v
        .split(RegExp(r'[.+-]'))
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
    final x = parts(a);
    final y = parts(b);
    for (var i = 0; i < (x.length > y.length ? x.length : y.length); i++) {
      final l = i < x.length ? x[i] : 0;
      final r = i < y.length ? y[i] : 0;
      if (l != r) return l.compareTo(r);
    }
    return 0;
  }

  /// Turns GitHub's generated release notes into a few readable lines.
  ///
  /// The raw form is written for a web page, not a phone: markdown headings,
  /// one bullet per merged pull request, each ending `by @someone in <url>`,
  /// and a trailing full-changelog link. Rendered as-is it wraps into an
  /// unreadable wall of URLs, which is what it did.
  ///
  /// This keeps the human half of each line — dropping the heading, the
  /// attribution trailer, bare links, and the conventional-commit prefix that
  /// means nothing to someone deciding whether to tap Install.
  static List<String> summarise(String notes, {int max = 4}) {
    final out = <String>[];
    var skippingSection = false;

    for (var line in notes.split('\n')) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#')) {
        // "New Contributors" is about the repository, not about the app. Its
        // entries are pure attribution and reduce to nothing once the handle
        // and link are stripped.
        skippingSection = line.toLowerCase().contains('contributor');
        continue;
      }
      if (skippingSection) continue;
      if (line.toLowerCase().startsWith('**full changelog')) continue;

      // Bullet marker.
      line = line.replaceFirst(RegExp(r'^[*\-+]\s+'), '');
      // "... by @someone in https://github.com/owner/repo/pull/1"
      line = line.replaceFirst(RegExp(r'\s+by\s+@\S+\s+in\s+\S+$'), '');
      // Any remaining bare link.
      line = line.replaceAll(RegExp(r'https?://\S+'), '').trim();
      // Conventional-commit prefix: "feat:", "fix(android):", "refactor(sync)!:"
      line = line.replaceFirst(
        RegExp(
          r'^(feat|fix|chore|docs|refactor|test|ci|build|perf|style)'
          r'(\([^)]*\))?!?:\s*',
          caseSensitive: false,
        ),
        '',
      );
      line = line.replaceAll(RegExp(r'\s+'), ' ').trim();
      // Stripping a link can leave a dangling preposition — "…contribution in".
      line = line.replaceFirst(RegExp(r'\s+(in|by|at|to|from)$'), '');
      // A line that was only a link or an attribution is now noise. Anything
      // still carrying a handle is about people, not about the release.
      if (line.isEmpty || line.length < 3 || line.contains('@')) continue;

      out.add(line[0].toUpperCase() + line.substring(1));
      if (out.length == max) break;
    }
    return out;
  }

  /// Parses the GitHub release payload. Split out so it can be tested without
  /// reaching the network.
  @visibleForTesting
  static Release? parseRelease(String body) {
    final json = jsonDecode(body);
    if (json is! Map) return null;
    final tag = json['tag_name'] as String?;
    if (tag == null) return null;

    // A release carries a build per platform, so pick the one this machine can
    // install rather than whichever happens to be listed first.
    final wanted = assetExtension;
    String? url;
    var size = 0;
    for (final asset in (json['assets'] as List? ?? const [])) {
      if (asset is! Map) continue;
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name.endsWith(wanted)) {
        url = asset['browser_download_url'] as String?;
        size = (asset['size'] as num?)?.toInt() ?? 0;
        break;
      }
    }

    return Release(
      tag: tag,
      version: tag.startsWith('v') ? tag.substring(1) : tag,
      notes: (json['body'] as String? ?? '').trim(),
      apkUrl: url,
      apkBytes: size,
    );
  }

  Future<void> check({bool quiet = true}) async {
    if (_status == UpdateStatus.downloading) return;
    _set(UpdateStatus.checking);
    try {
      final info = await PackageInfo.fromPlatform();
      _currentVersion = info.version;

      final res = await http
          .get(
            Uri.parse('https://api.github.com/repos/$repo/releases/latest'),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode == 404) {
        // Nothing published yet. Not an error worth shouting about.
        _set(UpdateStatus.upToDate, 'No releases published yet.');
        return;
      }
      if (res.statusCode != 200) {
        _set(UpdateStatus.failed, 'GitHub returned HTTP ${res.statusCode}.');
        return;
      }

      final release = parseRelease(res.body);
      if (release == null) {
        _set(UpdateStatus.failed, 'Could not read the release feed.');
        return;
      }

      if (compareVersions(release.version, _currentVersion) <= 0) {
        _release = null;
        _set(UpdateStatus.upToDate, 'Running the latest version.');
        return;
      }

      _release = release;
      _set(UpdateStatus.available);
    } on TimeoutException {
      _set(UpdateStatus.failed, quiet ? null : 'Timed out reaching GitHub.');
    } catch (e) {
      debugPrint('Updater: check failed — $e');
      _set(UpdateStatus.failed, quiet ? null : 'Could not check for updates.');
    }
  }

  /// Downloads the APK and hands it to the system installer.
  Future<void> downloadAndInstall() async {
    final release = _release;
    if (release == null) return;
    final url = release.apkUrl;
    if (url == null) {
      _set(
        UpdateStatus.failed,
        'That release has no $assetExtension build attached.',
      );
      return;
    }
    if (!canSelfInstall) {
      _set(UpdateStatus.failed, 'Install updates from $releasesPage');
      return;
    }

    _progress = 0;
    _set(UpdateStatus.downloading);

    try {
      final client = http.Client();
      final response = await client.send(
        http.Request('GET', Uri.parse(url))..followRedirects = true,
      );
      if (response.statusCode != 200) {
        client.close();
        _set(UpdateStatus.failed, 'Download failed (HTTP ${response.statusCode}).');
        return;
      }

      final isWindows = !kIsWeb && Platform.isWindows;
      // The Windows archive is scratch data: it is unpacked and thrown away, so
      // it belongs in temp rather than somewhere the user has to tidy up.
      final dir = isWindows
          ? Directory.systemTemp
          : await getExternalStorageDirectory() ??
                await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/whats-due-${release.tag}$assetExtension',
      );
      final sink = file.openWrite();
      final total = response.contentLength ?? release.apkBytes;
      var received = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          final next = received / total;
          // Only repaint on visible movement, not on every chunk.
          if (next - _progress > 0.01) {
            _progress = next;
            notifyListeners();
          }
        }
      }
      await sink.close();
      client.close();

      _downloadedPath = file.path;
      _progress = 1;
      _set(UpdateStatus.ready);

      if (isWindows) {
        await _installOnWindows(file);
        return;
      }

      // Android shows its own installer UI from here. The first time, it will
      // also ask for permission to install from this app.
      final result = await OpenFilex.open(
        file.path,
        type: 'application/vnd.android.package-archive',
      );
      if (result.type != ResultType.done) {
        _set(
          UpdateStatus.failed,
          'Downloaded, but the installer would not open: ${result.message}. '
          'The file is at ${file.path}.',
        );
      }
    } catch (e) {
      debugPrint('Updater: download failed — $e');
      _set(UpdateStatus.failed, 'Download failed — $e');
    }
  }

  /// Unpacks the Windows archive and hands the swap to a helper, then quits.
  ///
  /// The app has to exit: a running process holds its own executable open, so
  /// the files cannot be replaced until it is gone. The helper waits for that,
  /// swaps them, and starts the app again.
  Future<void> _installOnWindows(File zip) async {
    final staging = await WindowsUpdate.stage(zip);
    if (staging == null) {
      _set(
        UpdateStatus.failed,
        'The download could not be unpacked, so nothing was changed. '
        'The file is at ${zip.path}.',
      );
      return;
    }

    if (!await WindowsUpdate.handOff(staging)) {
      _set(
        UpdateStatus.failed,
        'Could not start the updater, so nothing was changed. The new version '
        'is unpacked at ${staging.path} if you want to copy it over yourself.',
      );
      return;
    }

    _set(UpdateStatus.ready, 'Restarting to finish the update…');
    // Give the message a frame to land, then get out of the helper's way.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    exit(0);
  }

  /// Re-opens an already-downloaded APK, for when the install prompt was
  /// dismissed and the permission has since been granted.
  Future<void> retryInstall() async {
    final path = _downloadedPath;
    if (path == null) return;
    await OpenFilex.open(
      path,
      type: 'application/vnd.android.package-archive',
    );
  }
}
