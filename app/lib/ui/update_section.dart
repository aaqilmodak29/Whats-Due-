import 'package:flutter/material.dart';

import '../theme.dart';
import '../updater.dart';
import 'atoms.dart';

/// The update panel on the backup screen.
///
/// The state line answers "should I do something?" in one glance — a version
/// transition when there is an update, a green all-clear when there isn't.
/// Release notes sit below that in sans, because they are prose written by a
/// person; setting them in the mono data face made them read as a log dump.
class UpdateSection extends StatelessWidget {
  const UpdateSection({super.key, required this.updater});

  final Updater updater;

  String _size(int bytes) =>
      bytes <= 0 ? '' : '${(bytes / 1048576).toStringAsFixed(0)} MB';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: updater,
    builder: (context, _) {
      final release = updater.release;
      final downloading = updater.status == UpdateStatus.downloading;
      final failed = updater.status == UpdateStatus.failed;

      return Surface(
        topBorder: failed
            ? C.red
            : release != null
            ? C.mark
            : C.ink,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow('Version', color: C.ink),
            const SizedBox(height: 10),

            if (downloading)
              _downloading(release)
            else if (release != null)
              _available(release)
            else
              _current(failed),

            if (release != null && !downloading) ...[
              const SizedBox(height: 16),
              _notes(release),
            ],

            const SizedBox(height: 14),
            _actions(release, downloading),

            if (updater.status == UpdateStatus.ready) ...[
              const SizedBox(height: 12),
              Text(
                'Nothing happened? Android needs permission to install apps '
                'from here. It will have offered a settings link — grant it, '
                'then tap Install again.',
                style: T.emptyBody,
              ),
            ],
          ],
        ),
      );
    },
  );

  /// No update: the installed version, and why we think that's current.
  Widget _current(bool failed) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        spacing: 8,
        children: [
          Text(
            updater.currentVersion.isEmpty ? '—' : updater.currentVersion,
            style: T.title(),
          ),
          Text(
            failed ? 'COULD NOT CHECK' : 'UP TO DATE',
            style: T.count(failed ? C.red : C.green),
          ),
        ],
      ),
      if (updater.message != null) ...[
        const SizedBox(height: 6),
        Text(
          updater.message!,
          style: T.emptyBody.copyWith(color: failed ? C.red : C.muted),
        ),
      ],
    ],
  );

  /// An update is waiting: show it as a transition, not two loose facts.
  Widget _available(Release release) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        spacing: 8,
        children: [
          Text(
            updater.currentVersion.isEmpty ? '—' : updater.currentVersion,
            style: T.title().copyWith(color: C.muted),
          ),
          Text('→', style: T.count(C.muted)),
          Text(release.version, style: T.title()),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        Updater.canSelfInstall
            ? 'Update available · ${_size(release.apkBytes)}'
            : 'Update available · ${_size(release.apkBytes)}. This platform '
                  'cannot install it for you — download it from:',
        style: T.emptyBody,
      ),
      // The link goes on its own line in the data face. Inline, it wrapped
      // mid-URL through the middle of a sentence and was unreadable.
      if (!Updater.canSelfInstall) ...[
        const SizedBox(height: 6),
        SelectableText(Updater.releasesPage, style: T.frac),
      ],
    ],
  );

  Widget _downloading(Release? release) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Downloading ${release?.version ?? ''}',
        style: T.count(C.ink),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 3,
        child: Stack(
          children: [
            Container(color: C.rule),
            FractionallySizedBox(
              widthFactor: updater.progress.clamp(0.0, 1.0),
              child: Container(color: C.ink),
            ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      Text('${(updater.progress * 100).round()}%', style: T.frac),
    ],
  );

  Widget _notes(Release release) {
    final lines = Updater.summarise(release.notes);
    if (lines.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow("What's new"),
        const SizedBox(height: 8),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1, right: 8),
                  child: Text('·', style: T.count(C.mark)),
                ),
                Expanded(child: Text(line, style: T.emptyBody)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _actions(Release? release, bool downloading) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      if (release != null && Updater.canSelfInstall && !downloading)
        GhostButton(
          label: updater.status == UpdateStatus.ready
              ? 'Install again'
              : 'Update now',
          filled: true,
          onPressed: () => updater.status == UpdateStatus.ready
              ? updater.retryInstall()
              : updater.downloadAndInstall(),
        ),
      if (!downloading)
        GhostButton(
          label: 'Check again',
          onPressed: () => updater.check(quiet: false),
        ),
    ],
  );
}

/// A one-line nudge on the main screen when an update is waiting.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key, required this.updater, required this.onTap});

  final Updater updater;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: updater,
    builder: (context, _) {
      final release = updater.release;
      if (release == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Tap(
          onTap: onTap,
          semanticLabel: 'Version ${release.version} is available, tap to install',
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: C.mark,
              border: Border(left: BorderSide(color: C.ink, width: 6)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Version ${release.version} available'.toUpperCase(),
                    style: T.count(C.ink),
                  ),
                ),
                Text('UPDATE', style: T.ghost()),
              ],
            ),
          ),
        ),
      );
    },
  );
}
