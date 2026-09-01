import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../sync/sync_engine.dart';
import '../theme.dart';
import 'add_panel.dart';
import 'assignment_card.dart';
import 'atoms.dart';
import 'backup_page.dart';
import 'grades_page.dart';
import 'horizon.dart';
import 'manage_subjects.dart';
import 'sync_page.dart';
import 'today_view.dart';
import 'update_section.dart';

/// Filter sentinels, matching the web app's `filter` values.
const _filterAll = 'all';
const _filterUnfiled = 'none';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.store});

  final AppStore store;

  @override
  State<HomePage> createState() => _HomePageState();
}

/// Which list the tab strip is showing.
enum _View { today, open, submitted }

class _HomePageState extends State<HomePage> {
  bool _showAdd = false;
  bool _showManage = false;
  _View _view = _View.open;
  String _filter = _filterAll;
  String? _openId;

  bool get _showSubmitted => _view == _View.submitted;

  /// `YYYY-MM-DD` when a day in the horizon strip is being filtered on.
  String? _selectedDue;

  AppStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    final active = store.active;
    final submitted = store.submitted;

    final overdue = active.where((a) {
      final n = daysUntil(a.due);
      return n != null && n < 0;
    }).length;
    final thisWeek = active.where((a) {
      final n = daysUntil(a.due);
      return n != null && n >= 0 && n <= 7;
    }).length;

    final shown = (_showSubmitted ? submitted : active).where((a) {
      if (_selectedDue != null && a.due != _selectedDue) return false;
      if (_filter == _filterAll) return true;
      if (_filter == _filterUnfiled) return a.subjectId == null;
      return a.subjectId == _filter;
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
              children: [
                // ---- header ----
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Eyebrow('Coursework'),
                          const SizedBox(height: 3),
                          Text("What's due", style: T.h1),
                        ],
                      ),
                    ),
                    IconSquare(
                      icon: _showAdd ? Icons.close : Icons.add,
                      open: _showAdd,
                      semanticLabel: _showAdd
                          ? 'Close the add panel'
                          : 'Add assignment',
                      onPressed: () => setState(() => _showAdd = !_showAdd),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                Text(
                  [
                    if (overdue > 0) '$overdue overdue',
                    '$thisWeek due within 7 days',
                    '${active.length} open',
                  ].join(' · ').toUpperCase(),
                  style: T.eyebrow(overdue > 0 ? C.red : C.muted),
                ),

                UpdateBanner(
                  updater: store.updater,
                  onTap: () => _openBackup(context),
                ),

                const SizedBox(height: 18),
                HorizonStrip(
                  active: active,
                  selectedDue: _selectedDue,
                  onSelect: (due) => setState(() {
                    _selectedDue = due;
                    _openId = null;
                    // The strip only ever charts unsubmitted work, so a day
                    // picked from Today or Submitted has to land on the list
                    // that can actually show it.
                    if (due != null) _view = _View.open;
                  }),
                ),
                if (_selectedDue != null) _dayFilterBar(),

                if (_showAdd) ...[
                  const SizedBox(height: 18),
                  AddPanel(
                    store: store,
                    onCreated: (created) => setState(() {
                      _showAdd = false;
                      _openId = created.id;
                      // Show the card that was just created, which neither
                      // Today nor Submitted would list.
                      _view = _View.open;
                      if (_filter != _filterAll &&
                          _filter != (created.subjectId ?? _filterUnfiled)) {
                        _filter = _filterAll;
                      }
                    }),
                  ),
                ],

                // ---- subject filter chips ----
                if (store.subjects.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      spacing: 6,
                      children: [
                        _Chip(
                          label: 'All',
                          count: active.length,
                          on: _filter == _filterAll,
                          onTap: () => _select(_filterAll),
                        ),
                        for (final s in store.subjects)
                          _Chip(
                            label: s.name,
                            count: active
                                .where((a) => a.subjectId == s.id)
                                .length,
                            dot: s.swatch,
                            on: _filter == s.id,
                            onTap: () => _select(s.id),
                          ),
                        if (active.any((a) => a.subjectId == null))
                          _Chip(
                            label: 'Unfiled',
                            count: active
                                .where((a) => a.subjectId == null)
                                .length,
                            on: _filter == _filterUnfiled,
                            onTap: () => _select(_filterUnfiled),
                          ),
                      ],
                    ),
                  ),
                ],

                // ---- tabs ----
                const SizedBox(height: 16),
                Container(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: C.rule)),
                  ),
                  // Scrolls rather than wraps, matching the filter chips above.
                  // Three labels plus their counts no longer fit a 360px phone,
                  // and the underline that marks the active tab only reads as
                  // one if they stay on a single line.
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      spacing: 18,
                      children: [
                        _Tab(
                          label: 'Today',
                          on: _view == _View.today,
                          onTap: () => _show(_View.today),
                        ),
                        _Tab(
                          label: 'Open (${active.length})',
                          on: _view == _View.open,
                          onTap: () => _show(_View.open),
                        ),
                        _Tab(
                          label: 'Submitted (${submitted.length})',
                          on: _showSubmitted,
                          onTap: () => _show(_View.submitted),
                        ),
                      ],
                    ),
                  ),
                ),

                // ---- list ----
                const SizedBox(height: 12),
                if (_view == _View.today)
                  TodayView(
                    store: store,
                    onOpen: (a) => setState(() {
                      // Jumping to a card means leaving Today, or the card it
                      // opened would not be on screen.
                      _view = _View.open;
                      _filter = _filterAll;
                      _selectedDue = null;
                      _openId = a.id;
                    }),
                  )
                else if (shown.isEmpty)
                  _empty()
                else
                  Column(
                    spacing: 9,
                    children: [
                      for (final a in shown)
                        AssignmentCard(
                          key: ValueKey(a.id),
                          assignment: a,
                          store: store,
                          expanded: _openId == a.id,
                          onToggleExpanded: () => setState(
                            () => _openId = _openId == a.id ? null : a.id,
                          ),
                        ),
                    ],
                  ),

                if (store.storageBlocked) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Storage is blocked here, so changes won\'t survive a '
                            'restart.'
                        .toUpperCase(),
                    style: T.eyebrow(C.red),
                  ),
                ],

                if (_showManage) ...[
                  const SizedBox(height: 14),
                  ManageSubjects(store: store),
                ],

                // ---- footer ----
                const SizedBox(height: 26),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    EyebrowButton(
                      label: _showManage ? 'Hide subjects' : 'Manage subjects',
                      onPressed: () =>
                          setState(() => _showManage = !_showManage),
                    ),
                    EyebrowButton(
                      label: 'Grades',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => GradesPage(store: store),
                        ),
                      ),
                    ),
                    if (store.sync?.isConfigured ?? false)
                      EyebrowButton(
                        label: _syncLabel(),
                        color: store.sync?.status == SyncStatus.conflict ||
                                store.sync?.status == SyncStatus.error
                            ? C.red
                            : C.muted,
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => SyncPage(store: store),
                            ),
                          );
                          if (mounted) setState(() {});
                        },
                      ),
                    EyebrowButton(
                      label: 'Backup & reminders',
                      onPressed: () => _openBackup(context),
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

  Future<void> _openBackup(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => BackupPage(store: store)),
    );
    if (!mounted) return;
    // The backup screen can clear everything, which may delete the item that
    // was open or the subject being filtered on.
    setState(() {
      if (!store.items.any((a) => a.id == _openId)) _openId = null;
      if (_filter != _filterAll &&
          _filter != _filterUnfiled &&
          !store.subjects.any((s) => s.id == _filter)) {
        _filter = _filterAll;
      }
    });
  }

  void _select(String filter) => setState(() {
    _filter = filter;
    _openId = null;
  });

  void _show(_View v) => setState(() {
    _view = v;
    _openId = null;
    // The horizon strip only charts unsubmitted, dated work, so a day filter
    // carried into either of the other two views would show an empty list.
    if (v != _View.open) _selectedDue = null;
  });

  /// Shows what the strip is filtering on, and how to get out of it. Without
  /// this a tap on a bar looks like most of the list vanishing for no reason.
  Widget _dayFilterBar() {
    final count = store.active.where((a) => a.due == _selectedDue).length;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Tap(
        onTap: () => setState(() => _selectedDue = null),
        semanticLabel: 'Clear the day filter',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: C.card,
            border: Border.all(color: C.ink),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${longDate(_selectedDue!)} · $count due'.toUpperCase(),
                  style: T.count(C.ink),
                ),
              ),
              const SizedBox(width: 8),
              Text('SHOW ALL', style: T.ghost(C.muted)),
            ],
          ),
        ),
      ),
    );
  }

  /// The footer link doubles as the sync indicator, so a conflict or a failure
  /// is visible from the main screen rather than only once you go looking.
  String _syncLabel() => switch (store.sync?.status) {
    SyncStatus.conflict => 'Sync — needs a decision',
    SyncStatus.error => 'Sync — failed',
    SyncStatus.syncing => 'Syncing…',
    SyncStatus.signedOut => 'Sync — sign in',
    _ => store.sync?.hasPendingChanges ?? false ? 'Sync — pending' : 'Synced',
  };

  Widget _empty() {
    final (head, body) = switch ((
      _selectedDue != null,
      _filter != _filterAll,
      _showSubmitted,
    )) {
      // A day filter is the most recent thing the user did, so name it first.
      (true, true, _) => (
        'Nothing here',
        'Nothing in this subject is due on that day. Tap SHOW ALL to widen it.',
      ),
      (true, false, _) => (
        'Nothing here',
        'Nothing is due on that day any more. Tap SHOW ALL to widen it.',
      ),
      (false, true, _) => (
        'Nothing here',
        'No assignments in this subject yet. Tap All to see everything.',
      ),
      (false, false, false) => (
        'Nothing tracked yet',
        'Add an assignment and the 14-day strip above will start filling in.',
      ),
      (false, false, true) => (
        'Nothing submitted yet',
        'Finished work shows up here once you mark it submitted.',
      ),
    };
    return Container(
      color: C.card,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
      child: Column(
        children: [
          Text(head, style: T.emptyHead, textAlign: TextAlign.center),
          const SizedBox(height: 5),
          Text(body, style: T.emptyBody, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// CSS `.chip` — the active one carries an inset highlighter underline.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.count,
    required this.on,
    required this.onTap,
    this.dot,
  });

  final String label;
  final int count;
  final bool on;
  final VoidCallback onTap;
  final Color? dot;

  @override
  Widget build(BuildContext context) => Tap(
    onTap: onTap,
    semanticLabel: 'Filter by $label, $count open',
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: C.card,
        border: Border.all(color: on ? C.ink : C.rule),
      ),
      child: Container(
        decoration: on
            ? const BoxDecoration(
                border: Border(bottom: BorderSide(color: C.mark, width: 2)),
              )
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          spacing: 6,
          children: [
            if (dot != null) Dot(dot!),
            Text(
              '${label.toUpperCase()} $count',
              style: T.chip(on ? C.ink : C.muted),
            ),
          ],
        ),
      ),
    ),
  );
}

/// CSS `.tab`.
class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tap(
    onTap: onTap,
    semanticLabel: label,
    child: Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: on ? C.ink : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: Text(label.toUpperCase(), style: T.tab(on ? C.ink : C.muted)),
    ),
  );
}
