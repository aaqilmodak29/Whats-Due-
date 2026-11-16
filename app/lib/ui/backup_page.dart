import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backup_file.dart';
import '../reminders.dart';
import '../store.dart';
import '../theme.dart';
import 'assignment_card.dart' show confirm;
import 'atoms.dart';

/// Backup and reminder settings.
///
/// With nothing syncing anywhere, export is the only copy of the data that
/// survives uninstalling, a lost device, or deciding to stop using the app.
class BackupSections extends StatefulWidget {
  const BackupSections({super.key, required this.store});

  final AppStore store;

  @override
  State<BackupSections> createState() => _BackupSectionsState();
}

class _BackupSectionsState extends State<BackupSections> {
  final _paste = TextEditingController();
  int _pending = 0;
  bool? _notificationsAllowed;
  bool? _exactAlarmsAllowed;
  bool _remindersReady = true;

  @override
  void initState() {
    super.initState();
    _refreshPending();
  }

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  Future<void> _refreshPending() async {
    final d = await Reminders.diagnose();
    if (!mounted) return;
    setState(() {
      _pending = d.pending;
      _remindersReady = d.ready;
      _notificationsAllowed = d.notifications;
      _exactAlarmsAllowed = d.exactAlarms;
    });
  }

  /// Names whichever link in the chain is actually broken. Scheduling succeeds
  /// whether or not a notification will ever be shown, so without this the
  /// only symptom is silence.
  Widget? _remindersWarning() {
    if (!_remindersReady) {
      return _warn(
        'Notifications could not start on this device. Reminders '
        'will not fire.',
      );
    }
    if (_notificationsAllowed == false) {
      return _warn(
        'This app is not allowed to post notifications, so no '
        'reminder will ever appear. Turn the switch off and on to be asked '
        'again, or allow notifications for it in Android settings.',
      );
    }
    if (_exactAlarmsAllowed == false) {
      return _warn(
        'Alarms and reminders are not permitted, so reminders may '
        'arrive late — Android will batch them rather than firing at 9am. '
        'Allow "Alarms & reminders" for this app in Android settings.',
      );
    }
    return null;
  }

  Widget _warn(String message) => Padding(
    padding: const EdgeInsets.only(top: SettingsSection.blockGap),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: C.red)),
      child: Text(message, style: T.emptyBody.copyWith(color: C.red)),
    ),
  );

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: C.ink,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        content: Text(message, style: T.eyebrow(C.onInk)),
      ),
    );
  }

  void _runImport({required bool merge}) {
    final result = widget.store.importJson(_paste.text, merge: merge);
    if (!result.succeeded) {
      _toast(result.error!);
      return;
    }
    _paste.clear();
    setState(() {});
    _refreshPending();
    _toast(
      merge
          ? 'Merged ${result.items} assignment${result.items == 1 ? '' : 's'} '
                'and ${result.subjects} new subject${result.subjects == 1 ? '' : 's'}.'
          : 'Replaced everything with ${result.items} assignment'
                '${result.items == 1 ? '' : 's'} across ${result.subjects} subject'
                '${result.subjects == 1 ? '' : 's'}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;

    return Column(
      children: [
        SettingsSection(
          title: 'Reminders',
          // The state sits under the title and the switch beside both, the
          // way a settings row reads, rather than on a line of its own.
          status: Text(
            store.remindersEnabled
                ? (_notificationsAllowed == false
                      ? 'ON — BUT BLOCKED BY ANDROID'
                      : 'ON — $_pending queued')
                : 'OFF',
            style: T.count(
              store.remindersEnabled && _notificationsAllowed == false
                  ? C.red
                  : C.ink,
            ),
          ),
          trailing: LabelledSwitch(
            label: 'Reminders',
            value: store.remindersEnabled,
            onChanged: (v) async {
              if (v) await Reminders.requestPermission();
              store.setRemindersEnabled(v);
              await _refreshPending();
            },
          ),
          children: [
            Text(
              '9am two weeks, a week and three days ahead, the day before '
              'and on the day, plus 9pm the night before.',
              style: T.body,
            ),
            ?_remindersWarning(),
            const SizedBox(height: SettingsSection.blockGap),
            // Outlined, like every other section's actions on this page.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                GhostButton(
                  label: 'Send a test',
                  onPressed: () async {
                    final ok = await Reminders.sendTest();
                    if (!mounted) return;
                    await _refreshPending();
                    if (!mounted) return;
                    _toast(
                      ok
                          ? 'A test reminder will appear in 5 seconds.'
                          : 'Android is blocking notifications for this '
                                'app, so nothing would appear.',
                    );
                  },
                ),
                GhostButton(
                  label: 'Recount',
                  onPressed: _refreshPending,
                ),
              ],
            ),
          ],
        ),
        // Reminders is a group of its own; the backup cards are the next.
        const SizedBox(height: SettingsSection.groupGap),

        SettingsSection(
          title: 'Export',
          children: [
            Text(
              '${store.items.length} assignment'
              '${store.items.length == 1 ? '' : 's'} across '
              '${store.subjects.length} subject'
              '${store.subjects.length == 1 ? '' : 's'}. '
              // Worth the one line: the data lives nowhere else.
              'The only copy that survives a lost phone.',
              style: T.body,
            ),
            const SizedBox(height: SettingsSection.blockGap),
            // Two ways to take the same copy out, so one style for both.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                GhostButton(
                  label: 'Save .json file',
                  onPressed: () async {
                    try {
                      final where = await saveBackup(store.exportJson());
                      if (!mounted) return;
                      _toast(
                        where == null || where.isEmpty
                            ? 'Backup saved.'
                            : 'Backup saved to $where',
                      );
                    } catch (e) {
                      if (!mounted) return;
                      _toast('Could not save the backup — $e');
                    }
                  },
                ),
                GhostButton(
                  label: 'Copy to clipboard',
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: store.exportJson()),
                    );
                    if (!mounted) return;
                    _toast('JSON copied.');
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: SettingsSection.cardGap),

        SettingsSection(
          title: 'Import',
          children: [
            // Merge and Replace only appear once there is something to import,
            // so the copy follows the screen rather than naming buttons that
            // are not there yet.
            Text(
              _paste.text.trim().isEmpty
                  ? 'Paste a backup below to merge it in or replace '
                        'everything with it.'
                  : 'MERGE adds what is new. REPLACE overwrites everything.',
              style: T.body,
            ),
            const SizedBox(height: SettingsSection.blockGap),
            TextField(
              controller: _paste,
              style: T.monoInput,
              minLines: 2,
              maxLines: 10,
              decoration: fieldDecoration(
                hint: '{ "subjects": [...], "items": [...] }',
                mono: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: SettingsSection.blockGap),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                GhostButton(
                  label: 'Paste from clipboard',
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text == null) {
                      if (mounted) _toast('Clipboard is empty.');
                      return;
                    }
                    setState(() => _paste.text = data!.text!);
                  },
                ),
                if (_paste.text.trim().isNotEmpty) ...[
                  // Outlined, not the highlighter: Update now keeps the page's
                  // one lime button.
                  GhostButton(
                    label: 'Merge',
                    onPressed: () => _runImport(merge: true),
                  ),
                  GhostButton(
                    label: 'Replace',
                    onPressed: () => confirm(
                      context,
                      title: 'Replace everything?',
                      body:
                          'Your current ${store.items.length} '
                          'assignment${store.items.length == 1 ? '' : 's'} '
                          'will be discarded and swapped for the pasted '
                          'backup. Save a backup first if you are unsure.',
                      confirmLabel: 'Replace',
                      onConfirm: () => _runImport(merge: false),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: SettingsSection.cardGap),

        SettingsSection(
          accent: C.red,
          title: 'Danger',
          children: [
            Text(
              'Deletes every assignment, task and subject on this phone.',
              style: T.body,
            ),
            const SizedBox(height: SettingsSection.blockGap),
            GhostButton(
              label: 'Clear all data',
              color: C.red,
              icon: Icons.delete_outline,
              onPressed: () => confirm(
                context,
                title: 'Erase everything?',
                body:
                    'Every assignment, task and subject will be deleted. '
                    'This cannot be undone.',
                confirmLabel: 'Erase',
                onConfirm: () {
                  store.clearAll();
                  _refreshPending();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A Settings section. Plain by default; only Danger carries a coloured
/// rule, so a coloured rule on this page always means the same thing.
///
/// Actions follow one rule across the page: the highlighter for the page's
/// one primary (Update now) and an outlined ink box for every other action a
/// card offers, checks included, so a row of actions never mixes a box with
/// a bare link. Red outline only for the one destructive action.
///
/// A section with a switch puts it beside the title, with the state it is in
/// ([status]) underneath, so a toggle reads as one settings row.
///
/// Every card on the page shares the spacing below, so the page has one
/// rhythm: the same inset on every side, the same step from a title to what
/// it heads and from one block to the next, a narrow gap between related
/// cards and a wider one between groups of them.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.accent,
    this.status,
    this.trailing,
  });

  /// The inset of every Settings card.
  static const padding = EdgeInsets.all(16);

  /// From a card's title (and status) to its content.
  static const titleGap = 10.0;

  /// Between blocks inside a card: prose, a field, a row of actions.
  static const blockGap = 12.0;

  /// Between cards in one group.
  static const cardGap = 12.0;

  /// Between groups of cards. Wide enough that a card at the head of a group,
  /// scrolled to the top of the screen, has only paper above it rather than a
  /// strip of the card before.
  static const groupGap = 28.0;

  final String title;
  final List<Widget> children;
  final Color? accent;
  final Widget? status;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Surface(
    topBorder: accent,
    padding: padding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow(title, color: C.ink),
                  if (status != null) ...[
                    const SizedBox(height: 4),
                    status!,
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
        if (children.isNotEmpty) ...[
          const SizedBox(height: titleGap),
          ...children,
        ],
      ],
    ),
  );
}
