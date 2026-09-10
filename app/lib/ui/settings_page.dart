import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import 'atoms.dart';
import 'backup_page.dart';
import 'sync_page.dart';
import 'update_section.dart';

/// Everything that is configuration rather than coursework.
///
/// Sync and Backup were two separate pushed pages reached from footer links,
/// which meant the two halves of "where does my data live" were never visible
/// at once — and a sync conflict was only discoverable by going looking for it.
/// They are one scroll now, ordered by how often you come here for each:
/// the version first, because checking for an update is the main reason to
/// open this page at all, then how sync works, then appearance, then the
/// operational sections — sync status, reminders, backup, restore and erasing.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.store,
    required this.controller,
  });

  final AppStore store;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) => PageBody(
    controller: controller,
    title: 'Settings',
    eyebrow: 'Version, sync, appearance, reminders and backup',
    children: [
      UpdateSection(updater: store.updater),
      const SizedBox(height: 16),
      SyncHowItWorks(store: store),
      const SizedBox(height: 16),
      _appearance(),
      const SizedBox(height: 16),
      SyncSection(store: store),
      const SizedBox(height: 16),
      BackupSections(store: store),
    ],
  );

  /// The theme switch. First, because it is the only setting here that changes
  /// something you can see immediately.
  Widget _appearance() => Surface(
    topBorder: C.ink,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow('Appearance', color: C.ink),
        const SizedBox(height: 10),
        Text(
          'The same design after dark rather than a different one: the paper '
          'goes to ink, the ink to paper, and the highlighter stays exactly '
          'where it is.',
          style: T.note,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                store.darkMode ? 'DARK' : 'LIGHT',
                style: T.count(C.ink),
              ),
            ),
            Switch(
              value: store.darkMode,
              activeThumbColor: C.onMark,
              activeTrackColor: C.mark,
              onChanged: store.setDarkMode,
            ),
          ],
        ),
      ],
    ),
  );
}
