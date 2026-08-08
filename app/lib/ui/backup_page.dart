import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backup_file.dart';
import '../reminders.dart';
import '../store.dart';
import '../theme.dart';
import 'assignment_card.dart' show confirm;
import 'atoms.dart';
import 'update_section.dart';

/// Backup and reminder settings.
///
/// Sync keeps the devices in step, so import and export are no longer how data
/// travels between them. They remain the escape hatch: a copy that survives
/// signing out, uninstalling, or deciding to stop using the app.
class BackupPage extends StatefulWidget {
  const BackupPage({super.key, required this.store});

  final AppStore store;

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
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
      return _warn('Notifications could not start on this device. Reminders '
          'will not fire.');
    }
    if (_notificationsAllowed == false) {
      return _warn('This app is not allowed to post notifications, so no '
          'reminder will ever appear. Turn the switch off and on to be asked '
          'again, or allow notifications for it in Android settings.');
    }
    if (_exactAlarmsAllowed == false) {
      return _warn('Alarms and reminders are not permitted, so reminders may '
          'arrive late — Android will batch them rather than firing at 9am. '
          'Allow "Alarms & reminders" for this app in Android settings.');
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
        content: Text(message, style: T.eyebrow(Colors.white)),
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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Eyebrow('Coursework'),
                          const SizedBox(height: 3),
                          Text('Backup', style: T.h1),
                        ],
                      ),
                    ),
                    IconSquare(
                      icon: Icons.close,
                      open: true,
                      semanticLabel: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                UpdateSection(updater: store.updater),
                const SizedBox(height: 16),

                _Section(
                  accent: C.mark,
                  title: 'Reminders',
                  children: [
                    Text(
                      'Six notifications per deadline, scheduled on this '
                      'device. At 9am two weeks out, one week out, three days '
                      'out, the day before and the morning it is due — then a '
                      'last one at 9pm, about three hours before a midnight '
                      'cut-off.\n\n'
                      'Assignments due at the same moment arrive as one '
                      'notification rather than several.',
                      style: T.note,
                    ),
                    const SizedBox(height: 12),
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
                        Switch(
                          value: store.remindersEnabled,
                          activeThumbColor: C.ink,
                          activeTrackColor: C.mark,
                          onChanged: (v) async {
                            if (v) await Reminders.requestPermission();
                            store.setRemindersEnabled(v);
                            await _refreshPending();
                          },
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
                        GhostButton(
                          label: 'Recount',
                          onPressed: _refreshPending,
                        ),
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
                      'Sync already keeps your devices in step; a saved backup '
                      'is what survives signing out or uninstalling.',
                      style: T.note,
                    ),
                    const SizedBox(height: 12),
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
                      'Paste a backup below. Accepts this app\'s JSON and the '
                      'older bare-array format, so an old backup still works.'
                      '\n\n'
                      'MERGE keeps what you have and adds anything new, '
                      'matching subjects by name and skipping assignments you '
                      'already have. REPLACE overwrites everything.',
                      style: T.note,
                    ),
                    const SizedBox(height: 12),
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
                    Text(
                      'Erasing is immediate and cannot be undone. Uninstalling '
                      'the app has the same effect on its data.',
                      style: T.note,
                    ),
                    const SizedBox(height: 12),
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
            ),
          ),
        ),
      ),
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
