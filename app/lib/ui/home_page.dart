import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'add_panel.dart';
import 'assignment_card.dart';
import 'atoms.dart';
import 'backup_page.dart';
import 'horizon.dart';
import 'manage_subjects.dart';

/// Filter sentinels, matching the web app's `filter` values.
const _filterAll = 'all';
const _filterUnfiled = 'none';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.store});

  final AppStore store;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _showAdd = false;
  bool _showManage = false;
  bool _showSubmitted = false;
  String _filter = _filterAll;
  String? _openId;

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

                const SizedBox(height: 18),
                HorizonStrip(active: active),

                if (_showAdd) ...[
                  const SizedBox(height: 18),
                  AddPanel(
                    store: store,
                    onCreated: (created) => setState(() {
                      _showAdd = false;
                      _openId = created.id;
                      _showSubmitted = false;
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
                  child: Row(
                    spacing: 18,
                    children: [
                      _Tab(
                        label: 'Open (${active.length})',
                        on: !_showSubmitted,
                        onTap: () => setState(() {
                          _showSubmitted = false;
                          _openId = null;
                        }),
                      ),
                      _Tab(
                        label: 'Submitted (${submitted.length})',
                        on: _showSubmitted,
                        onTap: () => setState(() {
                          _showSubmitted = true;
                          _openId = null;
                        }),
                      ),
                    ],
                  ),
                ),

                // ---- list ----
                const SizedBox(height: 12),
                if (shown.isEmpty)
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
                      label: 'Backup & reminders',
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BackupPage(store: store),
                          ),
                        );
                        if (!mounted) return;
                        // The backup screen can delete the item we had open.
                        setState(() {
                          if (!store.items.any((a) => a.id == _openId)) {
                            _openId = null;
                          }
                          if (_filter != _filterAll &&
                              _filter != _filterUnfiled &&
                              !store.subjects.any((s) => s.id == _filter)) {
                            _filter = _filterAll;
                          }
                        });
                      },
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

  void _select(String filter) => setState(() {
    _filter = filter;
    _openId = null;
  });

  Widget _empty() {
    final (head, body) = switch ((
      _filter != _filterAll,
      _showSubmitted,
    )) {
      (true, _) => (
        'Nothing here',
        'No assignments in this subject yet. Tap All to see everything.',
      ),
      (false, false) => (
        'Nothing tracked yet',
        'Add an assignment and the 14-day strip above will start filling in.',
      ),
      (false, true) => (
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
