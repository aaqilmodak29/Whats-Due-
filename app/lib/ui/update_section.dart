import 'package:flutter/material.dart';

import '../theme.dart';
import '../updater.dart';
import 'atoms.dart';

/// The update panel, shown on the backup screen.
class UpdateSection extends StatelessWidget {
  const UpdateSection({super.key, required this.updater});

  final Updater updater;

  String _size(int bytes) => bytes <= 0
      ? ''
      : ' · ${(bytes / 1048576).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: updater,
    builder: (context, _) {
      final release = updater.release;
      final accent = switch (updater.status) {
        UpdateStatus.available || UpdateStatus.ready => C.mark,
        UpdateStatus.failed => C.red,
        _ => C.ink,
      };

      return Surface(
        topBorder: accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow('Version', color: C.ink),
            const SizedBox(height: 10),
            Text(
              updater.currentVersion.isEmpty
                  ? 'Installed version unknown'
                  : 'Installed: ${updater.currentVersion}',
              style: T.count(C.ink),
            ),
            const SizedBox(height: 8),

            if (updater.status == UpdateStatus.downloading) ...[
              Text(
                'Downloading ${release?.tag ?? ''} — '
                '${(updater.progress * 100).round()}%',
                style: T.note,
              ),
              const SizedBox(height: 8),
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
            ] else if (release != null) ...[
              Text(
                '${release.tag} is available${_size(release.apkBytes)}.'
                '${Updater.canSelfInstall ? '' : '\n\nThis platform cannot '
                    'update itself — download it from\n${Updater.releasesPage}'}',
                style: T.note,
              ),
              if (release.notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  release.notes.length > 400
                      ? '${release.notes.substring(0, 400)}…'
                      : release.notes,
                  style: T.note,
                ),
              ],
            ] else
              Text(
                updater.message ?? 'Check whether a newer build is available.',
                style: T.note.copyWith(
                  color: updater.status == UpdateStatus.failed
                      ? C.red
                      : C.muted,
                ),
              ),

            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (release != null &&
                    Updater.canSelfInstall &&
                    updater.status != UpdateStatus.downloading)
                  GhostButton(
                    label: updater.status == UpdateStatus.ready
                        ? 'Install again'
                        : 'Download and install',
                    filled: true,
                    onPressed: () => updater.status == UpdateStatus.ready
                        ? updater.retryInstall()
                        : updater.downloadAndInstall(),
                  ),
                if (updater.status != UpdateStatus.downloading)
                  GhostButton(
                    label: 'Check for updates',
                    onPressed: () => updater.check(quiet: false),
                  ),
              ],
            ),

            if (updater.status == UpdateStatus.ready) ...[
              const SizedBox(height: 10),
              Text(
                'If nothing happened, Android needs permission to install apps '
                'from here — it will have offered a settings link. Grant it, '
                'then tap Install again.',
                style: T.note,
              ),
            ],
          ],
        ),
      );
    },
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
          semanticLabel: 'Version ${release.tag} is available, tap to install',
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
                    '${release.tag} available'.toUpperCase(),
                    style: T.count(C.ink),
                  ),
                ),
                Text('INSTALL', style: T.ghost()),
              ],
            ),
          ),
        ),
      );
    },
  );
}
