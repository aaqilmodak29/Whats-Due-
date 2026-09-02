import 'package:flutter/material.dart';

import '../store.dart';
import 'atoms.dart';
import 'backup_page.dart';
import 'sync_page.dart';

/// Everything that is configuration rather than coursework.
///
/// Sync and Backup were two separate pushed pages reached from footer links,
/// which meant the two halves of "where does my data live" were never visible
/// at once — and a sync conflict was only discoverable by going looking for it.
/// They are one scroll now, in the order the sections already had: sync first,
/// because it runs by itself and is the thing most likely to need attention,
/// then the version, reminders, export, import and erasing.
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
    eyebrow: 'Sync, reminders, backup and updates',
    children: [
      SyncSection(store: store),
      const SizedBox(height: 16),
      BackupSections(store: store),
    ],
  );
}
