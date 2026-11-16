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
    // The version, a wider gap, then the settings cards at one even step:
    // grading, appearance, reminders, export, import and erasing.
    children: [
      UpdateSection(updater: store.updater),
      const SizedBox(height: SettingsSection.groupGap),
      // Grading has a card to itself: opened, its switch and band list are
      // one group, and Appearance sharing the card made three unrelated
      // groups at one weight.
      // 4px less inset top and bottom than the other cards: Grading's header
      // row carries 4px of tap padding of its own, so this puts its title
      // the same 16px in from the card's edge as every other title. Its card
      // also starts 4px lower when scrolled to the top of the screen.
      Surface(
        padding: SettingsSection.padding.copyWith(top: 12, bottom: 12),
        child: GradingSection(store: store),
      ),
      const SizedBox(height: SettingsSection.cardGap),
      _appearance(),
      const SizedBox(height: SettingsSection.cardGap),
      BackupSections(store: store),
    ],
  );

  /// The theme switch, laid out like Reminders and Grading: the title, the
  /// state in mono beneath it ("DARK MODE OFF", as Grading says "LETTER
  /// GRADES ON"), and the switch beside both, so off is said in words as
  /// well as by the empty track.
  Widget _appearance() => SettingsSection(
    title: 'Appearance',
    status: Text(
      store.darkMode ? 'DARK MODE ON' : 'DARK MODE OFF',
      style: T.count(C.ink),
    ),
    trailing: LabelledSwitch(
      label: 'Dark mode',
      value: store.darkMode,
      onChanged: store.setDarkMode,
    ),
    children: const [],
  );
}
