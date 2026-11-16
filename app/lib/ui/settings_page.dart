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
      const SizedBox(height: 16),
      GradingSection(store: store),
      const SizedBox(height: 16),
      _appearance(),
      const SizedBox(height: 16),
      BackupSections(store: store),
    ],
  );

  /// The theme switch. The header names the theme in force, the same way
  /// Grading's header names its state; the row says what the switch does.
  Widget _appearance() => Surface(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Eyebrow('Appearance', color: C.ink)),
            Text(store.darkMode ? 'DARK' : 'LIGHT', style: T.eyebrow(C.muted)),
          ],
        ),
        Row(
          children: [
            Expanded(child: Text('Dark mode', style: T.body)),
            LabelledSwitch(
              label: 'Dark mode',
              value: store.darkMode,
              onChanged: store.setDarkMode,
            ),
          ],
        ),
      ],
    ),
  );
}
