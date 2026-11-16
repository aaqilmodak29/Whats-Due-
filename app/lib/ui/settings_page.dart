import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import 'atoms.dart';
import 'band_editor.dart';
import 'backup_page.dart';
import 'update_section.dart';

/// Everything that is configuration rather than coursework.
///
/// Ordered by how often you come here for each: the version first, because
/// checking for an update is the main reason to open this page at all, then
/// grading and appearance, then the operational sections — reminders, backup,
/// restore and erasing.
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
    children: [
      UpdateSection(updater: store.updater),
      const SizedBox(height: 12),
      // The two one-line preferences share a card: each alone was a whole
      // card for a single row.
      Surface(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GradingSection(store: store),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(height: 1, color: C.rule),
            ),
            _appearance(),
          ],
        ),
      ),
      const SizedBox(height: 12),
      BackupSections(store: store),
    ],
  );

  /// The theme switch: the title with the theme in force beneath it, the way
  /// Reminders shows its state, and the switch labelled with what it does.
  Widget _appearance() => Row(
    spacing: 10,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            Eyebrow('Appearance', color: C.ink),
            Text(store.darkMode ? 'DARK' : 'LIGHT', style: T.count(C.ink)),
          ],
        ),
      ),
      Text('Dark mode', style: T.body),
      LabelledSwitch(
        label: 'Dark mode',
        value: store.darkMode,
        onChanged: store.setDarkMode,
      ),
    ],
  );
}
