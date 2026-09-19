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
    padding: const EdgeInsets.only(top: 10),
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
        _Section(
          accent: C.mark,
          title: 'Reminders',
          children: [
            Text(
              '9am at two weeks, one week, three days, the day before and '
              'the morning it is due, plus 9pm the night before.',
              style: T.note,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    store.remindersEnabled
                        ? (_notificationsAllowed == false
                              ? 'ON — BUT BLOCKED BY ANDROID'
                              : 'ON — $_pending queued')
                        : 'OFF',
                    style: T.count(
                      !store.remindersEnabled
                          ? C.muted
                          : _notificationsAllowed == false
                          ? C.red
                          : C.ink,
                    ),
                  ),
                ),
                Semantics(
                  // container: true, or the label merges into the Switch's own
                  // node and never reaches the semantics tree as its own entry.
                  container: true,
                  label: 'Reminders',
                  toggled: store.remindersEnabled,
                  child: Switch(
                    value: store.remindersEnabled,
                    activeThumbColor: C.onMark,
                    activeTrackColor: C.mark,
                    onChanged: (v) async {
                      if (v) await Reminders.requestPermission();
                      store.setRemindersEnabled(v);
                      await _refreshPending();
                    },
                  ),
                ),
              ],
            ),
            ?_remindersWarning(),
            const SizedBox(height: 4),
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
                GhostButton(label: 'Recount', onPressed: _refreshPending),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        _Section(
          accent: C.ink,
          title: 'Export',
          children: [
            Text(
              '${store.items.length} assignment'
              '${store.items.length == 1 ? '' : 's'} across '
              '${store.subjects.length} subject'
              '${store.subjects.length == 1 ? '' : 's'}. '
              // Worth the one line: the data lives nowhere else.
              'The only copy that survives a lost phone.',
              style: T.note,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
        const SizedBox(height: 16),

        _Section(
          accent: C.ink,
          title: 'Import',
          children: [
            Text(
              'MERGE adds what is new. REPLACE overwrites everything.',
              style: T.note,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _paste,
              style: T.monoInput,
              minLines: 5,
              maxLines: 10,
              decoration: fieldDecoration(
                hint: '{ "subjects": [...], "items": [...] }',
                mono: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
                  GhostButton(
                    label: 'Merge',
                    filled: true,
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
        const SizedBox(height: 16),

        _Section(
          accent: C.red,
          title: 'Danger',
          children: [
            GhostButton(
              label: 'Clear all data',
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

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    required this.accent,
  });

  final String title;
  final List<Widget> children;
  final Color accent;

  @override
  Widget build(BuildContext context) => Surface(
    topBorder: accent,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(title, color: C.ink),
        const SizedBox(height: 10),
        ...children,
      ],
    ),
  );
}
