import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'add_panel.dart';
import 'assignment_card.dart';
import 'atoms.dart';
import 'manage_subjects.dart';
import 'today_view.dart';

/// Filter sentinels, matching the web app's `filter` values.
const filterAll = 'all';
const filterUnfiled = 'none';

/// Which list the tab strip is showing.
enum AssignmentTab { today, open, submitted }

/// Everything about how the Assignments page is currently being looked at.
///
/// Held by the shell rather than by the page, so Home can navigate *into* a
/// particular view of it — a day picked from the horizon strip, or the card
/// behind a planned task — and so that view survives switching tabs and coming
/// back. Immutable, with [copyWith], to keep those transitions explicit.
class AssignmentsView {
  const AssignmentsView({
    this.tab = AssignmentTab.open,
    this.filter = filterAll,
    this.selectedDue,
    this.openId,
    this.showManage = false,
    this.showAdd = false,
  });

  final AssignmentTab tab;
  final String filter;

  /// `YYYY-MM-DD` when a day in the horizon strip is being filtered on.
  final String? selectedDue;

  /// The expanded card, if any.
  final String? openId;

  final bool showManage;
  final bool showAdd;

  AssignmentsView copyWith({
    AssignmentTab? tab,
    String? filter,
    String? selectedDue,
    String? openId,
    bool? showManage,
    bool? showAdd,
    bool clearSelectedDue = false,
    bool clearOpenId = false,
  }) => AssignmentsView(
    tab: tab ?? this.tab,
    filter: filter ?? this.filter,
    selectedDue: clearSelectedDue ? null : (selectedDue ?? this.selectedDue),
    openId: clearOpenId ? null : (openId ?? this.openId),
    showManage: showManage ?? this.showManage,
    showAdd: showAdd ?? this.showAdd,
  );
}

/// The working surface: every assignment, filtered and grouped.
class AssignmentsPage extends StatelessWidget {
  const AssignmentsPage({
    super.key,
    required this.store,
    required this.view,
    required this.onView,
    required this.controller,
  });

  final AppStore store;
  final AssignmentsView view;
  final ScrollController controller;
  final ValueChanged<AssignmentsView> onView;

  bool get _showSubmitted => view.tab == AssignmentTab.submitted;

  @override
  Widget build(BuildContext context) {
    final active = store.active;
    final submitted = store.submitted;

    final shown = (_showSubmitted ? submitted : active).where((a) {
      if (view.selectedDue != null && a.due != view.selectedDue) return false;
      if (view.filter == filterAll) return true;
      if (view.filter == filterUnfiled) return a.subjectId == null;
      return a.subjectId == view.filter;
    }).toList();

    return PageBody(
      controller: controller,
      title: 'Assignments',
      eyebrow: '${active.length} open · ${submitted.length} submitted',
      action: IconSquare(
        icon: view.showAdd ? Icons.close : Icons.add,
        open: view.showAdd,
        semanticLabel: view.showAdd ? 'Close the add panel' : 'Add assignment',
        onPressed: () => onView(view.copyWith(showAdd: !view.showAdd)),
      ),
      children: [
        if (view.showAdd) ...[
          const SizedBox(height: 4),
          AddPanel(
            store: store,
            onCreated: (created) => onView(
              view.copyWith(
                showAdd: false,
                openId: created.id,
                tab: AssignmentTab.open,
                clearSelectedDue: true,
                // Landing on a filter that excludes the new card would look
                // like the add silently failing.
                filter:
                    view.filter != filterAll &&
                        view.filter != (created.subjectId ?? filterUnfiled)
                    ? filterAll
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // ---- subject filter chips ----
        if (store.subjects.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 6,
              children: [
                _Chip(
                  label: 'All',
                  count: active.length,
                  on: view.filter == filterAll,
                  onTap: () => _select(filterAll),
                ),
                for (final s in store.subjects)
                  _Chip(
                    label: s.name,
                    count: active.where((a) => a.subjectId == s.id).length,
                    dot: s.swatch,
                    on: view.filter == s.id,
                    onTap: () => _select(s.id),
                  ),
                if (active.any((a) => a.subjectId == null))
                  _Chip(
                    label: 'Unfiled',
                    count: active.where((a) => a.subjectId == null).length,
                    on: view.filter == filterUnfiled,
                    onTap: () => _select(filterUnfiled),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Sits with the chips it edits, above the tabs — subjects are a
        // property of the list, not one of the three views of it.
        Align(
          alignment: Alignment.centerLeft,
          child: EyebrowButton(
            label: view.showManage ? 'Hide subjects' : 'Manage subjects',
            onPressed: () =>
                onView(view.copyWith(showManage: !view.showManage)),
          ),
        ),
        if (view.showManage) ...[
          const SizedBox(height: 8),
          ManageSubjects(store: store),
        ],

        // ---- tabs ----
        const SizedBox(height: 14),
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: C.rule)),
          ),
          // Scrolls rather than wraps: three labels plus their counts no longer
          // fit a 360px phone, and the underline marking the active tab only
          // reads as one if they stay on a single line.
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 18,
              children: [
                _Tab(
                  label: 'Today',
                  on: view.tab == AssignmentTab.today,
                  onTap: () => _show(AssignmentTab.today),
                ),
                _Tab(
                  label: 'Open (${active.length})',
                  on: view.tab == AssignmentTab.open,
                  onTap: () => _show(AssignmentTab.open),
                ),
                _Tab(
                  label: 'Submitted (${submitted.length})',
                  on: _showSubmitted,
                  onTap: () => _show(AssignmentTab.submitted),
                ),
              ],
            ),
          ),
        ),

        if (view.selectedDue != null) _dayFilterBar(),

        // ---- list ----
        const SizedBox(height: 12),
        if (view.tab == AssignmentTab.today)
          TodayView(
            store: store,
            onOpen: (a) => onView(
              view.copyWith(
                tab: AssignmentTab.open,
                filter: filterAll,
                openId: a.id,
                clearSelectedDue: true,
              ),
            ),
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
                  expanded: view.openId == a.id,
                  onToggleExpanded: () => onView(
                    view.openId == a.id
                        ? view.copyWith(clearOpenId: true)
                        : view.copyWith(openId: a.id),
                  ),
                ),
            ],
          ),

        if (store.storageBlocked) ...[
          const SizedBox(height: 16),
          Text(
            'Storage is blocked here, so changes won\'t survive a restart.'
                .toUpperCase(),
            style: T.eyebrow(C.red),
          ),
        ],
      ],
    );
  }

  void _select(String filter) =>
      onView(view.copyWith(filter: filter, clearOpenId: true));

  void _show(AssignmentTab tab) => onView(
    view.copyWith(
      tab: tab,
      clearOpenId: true,
      // The horizon strip only charts unsubmitted, dated work, so a day filter
      // carried into either of the other two views would show an empty list.
      clearSelectedDue: tab != AssignmentTab.open,
    ),
  );

  /// Shows what the strip is filtering on, and how to get out of it. Without
  /// this a tap on a bar looks like most of the list vanishing for no reason.
  Widget _dayFilterBar() {
    final count = store.active.where((a) => a.due == view.selectedDue).length;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Tap(
        onTap: () => onView(view.copyWith(clearSelectedDue: true)),
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
                  '${longDate(view.selectedDue!)} · $count due'.toUpperCase(),
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

  Widget _empty() {
    final (head, body) = switch ((
      view.selectedDue != null,
      view.filter != filterAll,
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
        'Add an assignment and the 14-day strip on Home starts filling in.',
      ),
      (false, false, true) => (
        'Nothing submitted yet',
        'Finished work shows up here once you mark it submitted.',
      ),
    };
    return EmptyState(head: head, body: body);
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
