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
      // Grading has a card to itself: opened, its switch and band list are
      // one group, and Appearance sharing the card made three unrelated
      // groups at one weight.
      Surface(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: GradingSection(store: store),
      ),
      const SizedBox(height: 12),
      _appearance(),
      const SizedBox(height: 12),
      BackupSections(store: store),
    ],
  );

  /// The theme switch, laid out like Reminders: the title, what the switch
  /// does beneath it, and the switch beside both. The switch alone says
  /// which theme is in force, so the page says it once.
  Widget _appearance() => SettingsSection(
    title: 'Appearance',
    status: Text('Dark mode', style: T.body),
    trailing: LabelledSwitch(
      label: 'Dark mode',
      value: store.darkMode,
      onChanged: store.setDarkMode,
    ),
    children: const [],
  );
}
