import 'package:flutter/material.dart';

import '../grades.dart';
import '../models.dart';
import '../planner.dart';
import '../store.dart';
import '../sync/sync_engine.dart';
import '../theme.dart';
import 'add_panel.dart';
import 'atoms.dart';
import 'horizon.dart';
import 'update_section.dart';

/// The landing page: what you need to know without doing anything.
///
/// Everything here is either a fact that changes daily or a warning. Nothing
/// on it exists purely to navigate — that is the nav bar's job — so each block
/// earns its space by answering a question rather than offering a door.
class HomeLanding extends StatefulWidget {
  const HomeLanding({
    super.key,
    required this.store,
    required this.controller,
    required this.onOpenAssignment,
    required this.onPickDay,
    required this.onOpenToday,
    required this.onOpenGrades,
    required this.onOpenSettings,
  });

  final AppStore store;
  final ScrollController controller;

  /// Jumps to a card in Assignments.
  final ValueChanged<Assignment> onOpenAssignment;

  /// A day from the horizon strip: Assignments, filtered to it.
  final ValueChanged<String> onPickDay;

  final VoidCallback onOpenToday;
  final VoidCallback onOpenGrades;
  final VoidCallback onOpenSettings;

  @override
  State<HomeLanding> createState() => _HomeLandingState();
}

class _HomeLandingState extends State<HomeLanding> {
  bool _showAdd = false;

  AppStore get store => widget.store;

  /// How many deadlines the "next up" block shows. Three is what fits without
  /// turning a glance into a list — the full one is a tab away.
  static const _nextUp = 3;

  @override
  Widget build(BuildContext context) {
    final active = store.active;
    final overdue = active.where((a) {
      final n = daysUntil(a.due);
      return n != null && n < 0;
    }).length;
    final thisWeek = active.where((a) {
      final n = daysUntil(a.due);
      return n != null && n >= 0 && n <= 7;
    }).length;

    return PageBody(
      controller: widget.controller,
      title: "What's due",
      eyebrow: [
        if (overdue > 0) '$overdue overdue',
        '$thisWeek due within 7 days',
        '${active.length} open',
      ].join(' · '),
      eyebrowColor: overdue > 0 ? C.red : C.muted,
      action: IconSquare(
        icon: _showAdd ? Icons.close : Icons.add,
        open: _showAdd,
        semanticLabel: _showAdd ? 'Close the add panel' : 'Add assignment',
        onPressed: () => setState(() => _showAdd = !_showAdd),
      ),
      children: [
        UpdateBanner(updater: store.updater, onTap: widget.onOpenSettings),

        if (_showAdd) ...[
          AddPanel(
            store: store,
            onCreated: (created) {
              setState(() => _showAdd = false);
              // Show the result rather than dropping it into a list the user
              // cannot see from here.
              widget.onOpenAssignment(created);
            },
          ),
          const SizedBox(height: 18),
        ],

        // The strip is a glance artifact, so it lives on the glance page. It
        // stays interactive: a day taps through to Assignments filtered to it,
        // rather than being duplicated there.
        HorizonStrip(
          active: active,
          selectedDue: null,
          onSelect: (due) {
            if (due != null) widget.onPickDay(due);
          },
        ),

        const SizedBox(height: 20),
        _nextUpBlock(active),

        const SizedBox(height: 14),
        _todayBlock(),

        _gradesBlock(),
        _syncNotice(),
      ],
    );
  }

  // ------------------------------------------------------------- next up

  Widget _nextUpBlock(List<Assignment> active) {
    // Undated work sorts last and cannot be counted down, so it is not a
    // "next submission" however long it has been sitting there.
    final dated = active.where((a) => a.due.isNotEmpty).take(_nextUp).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Next up'),
        const SizedBox(height: 8),
        if (dated.isEmpty)
          const EmptyState(
            head: 'Nothing with a deadline',
            body: 'Add an assignment with a due date and it appears here, '
                'counting down.',
          )
        else
          Column(
            spacing: 9,
            children: [for (final a in dated) _deadlineRow(a)],
          ),
      ],
    );
  }

  Widget _deadlineRow(Assignment a) {
    final n = daysUntil(a.due);
    final spine = urgency(n);
    final subject = store.subjectOf(a);
    final total = a.tasks.length;

    return Container(
      decoration: BoxDecoration(
        color: C.card,
        border: Border(left: BorderSide(color: spine, width: 6)),
        boxShadow: const [
          BoxShadow(color: Color(0x1A16202E), offset: Offset(0, 1)),
        ],
      ),
      child: Tap(
        onTap: () => widget.onOpenAssignment(a),
        semanticLabel:
            '${a.title}, ${subject?.name ?? 'unfiled'}, '
            '${countdown(n).toLowerCase()}, ${longDate(a.due)}'
            '${total == 0 ? '' : ', ${a.finishedTasks} of $total tasks done'}'
            ', tap to open',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      spacing: 6,
                      children: [
                        if (subject != null) Dot(subject.swatch),
                        Flexible(
                          child: Eyebrow(
                            subject?.name ?? 'Unfiled',
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(countdown(n), style: T.count(spine)),
                ],
              ),
              const SizedBox(height: 5),
              Text(a.title, style: T.title()),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: Text(longDate(a.due), style: T.frac)),
                  // Deadline plus progress is the pairing that matters: "two
                  // days, nothing done" is the alarming case, and a date on its
                  // own hides it.
                  Text(
                    total == 0
                        ? 'no tasks'
                        : '${a.finishedTasks}/$total tasks',
                    style: T.frac,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- today

  /// The day's headline and its single next action.
  ///
  /// A summary, not the plan: the full paced list is the Today tab. Repeating
  /// it here would be the same screen twice.
  Widget _todayBlock() {
    final plan = todayPlan(store.items);
    final next = plan.tasks.firstOrNull;

    return Tap(
      onTap: widget.onOpenToday,
      semanticLabel: plan.isEmpty
          ? 'Nothing to pick up today, tap to open Today'
          : '${_todayHeadline(plan)}, next up ${next!.label}, '
                'tap to open Today',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
        decoration: const BoxDecoration(
          color: C.card,
          border: Border(top: BorderSide(color: C.mark, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Eyebrow('Today')),
                Text('OPEN', style: T.ghost(C.muted)),
              ],
            ),
            const SizedBox(height: 4),
            Text(_todayHeadline(plan), style: T.title()),
            if (next != null) ...[
              const SizedBox(height: 6),
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: Text(
                      'NEXT · ${next.label}'.toUpperCase(),
                      style: T.eyebrow(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (next.minutes != null)
                    Text(formatMinutes(next.minutes!), style: T.frac),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _todayHeadline(DayPlan plan) {
    if (plan.isEmpty) return 'Nothing to pick up';
    if (plan.estimatedMinutes > 0) {
      return 'About ${formatMinutes(plan.estimatedMinutes)} today';
    }
    final n = plan.tasks.length;
    return '$n ${n == 1 ? 'thing' : 'things'} to pick up';
  }

  // -------------------------------------------------------------- grades

  /// One line, not a table. Grades move slowly, so this is reassurance rather
  /// than information, and it stays hidden until a weight exists at all.
  Widget _gradesBlock() {
    final grades = gradesBySubject(store.items)
        .where((g) => g.average != null)
        .toList();
    if (grades.isEmpty) return const SizedBox.shrink();

    // A plain mean of the per-unit averages. Weighting it by anything would
    // imply units are commensurable, which is the mistake the Grades page
    // exists to avoid.
    final mean =
        grades.fold<double>(0, (sum, g) => sum + g.average!) / grades.length;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Tap(
        onTap: widget.onOpenGrades,
        semanticLabel:
            '${grades.length} units tracked, averaging '
            '${formatPercent(mean)}, tap to open Grades',
        child: Container(
          width: double.infinity,
          color: C.card,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${grades.length} '
                          '${grades.length == 1 ? 'unit' : 'units'} tracked · '
                          'averaging ${formatPercent(mean)}'
                      .toUpperCase(),
                  style: T.eyebrow(C.ink),
                ),
              ),
              Text('GRADES', style: T.ghost(C.muted)),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- sync

  /// Only appears when sync needs a decision or has failed.
  ///
  /// A working sync says nothing: a permanent status line trains you to ignore
  /// the spot where the failure will eventually appear.
  Widget _syncNotice() {
    final status = store.sync?.status;
    if (status != SyncStatus.conflict && status != SyncStatus.error) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Tap(
        onTap: widget.onOpenSettings,
        semanticLabel: status == SyncStatus.conflict
            ? 'Sync needs a decision, tap to open Settings'
            : 'Sync failed, tap to open Settings',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: C.card,
            border: Border.all(color: C.red),
          ),
          child: Text(
            status == SyncStatus.conflict
                ? 'SYNC NEEDS A DECISION'
                : 'SYNC FAILED',
            style: T.count(C.red),
          ),
        ),
      ),
    );
  }
}
