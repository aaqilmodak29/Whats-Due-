import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import 'atoms.dart';
import 'backup_page.dart';
import 'update_section.dart';

/// Everything that is configuration rather than coursework.
///
/// Ordered by how often you come here for each: the version first, because
/// checking for an update is the main reason to open this page at all, then
/// appearance, then the operational sections — reminders, backup, restore and
/// erasing.
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
    eyebrow: 'Version, appearance, reminders and backup',
    children: [
      UpdateSection(updater: store.updater),
      const SizedBox(height: 16),
      _appearance(),
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
