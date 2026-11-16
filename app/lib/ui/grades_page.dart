import 'package:flutter/material.dart';

import '../bands.dart';
import '../grades.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'atoms.dart';
import 'goal_sheet.dart';

/// Where each subject stands, what is still to come, and what it would take to
/// land on a given grade.
///
/// Its own destination rather than a strip on the list: grades are something
/// you go and check, not something you need while triaging deadlines.
class GradesPage extends StatefulWidget {
  const GradesPage({super.key, required this.store, required this.controller});

  final AppStore store;
  final ScrollController controller;

  @override
  State<GradesPage> createState() => _GradesPageState();
}

class _GradesPageState extends State<GradesPage> {
  /// Which subject has its detail showing. One at a time, so the page cannot
  /// grow into a wall of every mark ever recorded.
  String? _openId;

  AppStore get store => widget.store;
  List<GradeBand> get bands => store.bands;

  @override
  Widget build(BuildContext context) {
    final grades = gradesBySubject(store.items)
      ..sort((a, b) => _name(a.subjectId).compareTo(_name(b.subjectId)));
    final results = grades.fold<int>(0, (n, g) => n + g.gradedCount);

    return PageBody(
      controller: widget.controller,
      title: 'Grades',
      eyebrow: grades.isEmpty
          ? null
          : '${grades.length} ${grades.length == 1 ? 'subject' : 'subjects'}'
                ' · $results ${results == 1 ? 'result' : 'results'}',
      children: [
        if (grades.isEmpty)
          _empty()
        else ...[
          for (final g in grades) ...[
            _subjectCard(g),
            const SizedBox(height: 9),
          ],
          const SizedBox(height: 4),
          _legend(
            toCome: grades.any((g) => g.remainingOutOf > 0),
            goals: grades.any(
              (g) => _subjectOf(g.subjectId)?.goalPercent != null,
            ),
          ),
        ],
      ],
    );
  }

  String _name(String? subjectId) => _subjectOf(subjectId)?.name ?? 'Unfiled';

  Subject? _subjectOf(String? id) =>
      store.subjects.where((s) => s.id == id).firstOrNull;

  Color _swatch(String? id) => _subjectOf(id)?.swatch ?? C.muted;

  /// The band a fraction lands in, as a short label, or empty without bands.
  String _band(double fraction) =>
      bandFor(fraction * 100, bands)?.name.toUpperCase() ?? '';

  /// How a fraction should be coloured: red at the bottom, green at the top.
  Color _colour(double fraction) => gradeColour(fraction * 100, bands);

  // ------------------------------------------------------------------- card

  Widget _subjectCard(SubjectGrade g) {
    final average = g.average;
    final key = g.subjectId ?? '';
    final open = _openId == key;
    final subject = _subjectOf(g.subjectId);
    final goal = subject?.goalPercent;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: C.card),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tap(
            onTap: () => setState(() => _openId = open ? null : key),
            semanticLabel:
                '${_name(g.subjectId)}, '
                '${average == null ? 'nothing marked yet' : formatPercent(average)}, '
                '${trimNumber(g.earned)} of ${trimNumber(g.totalOutOf)} marks, '
                'tap to ${open ? 'hide' : 'show'} the detail',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  spacing: 6,
                  children: [
                    Dot(_swatch(g.subjectId)),
                    Expanded(child: Eyebrow(_name(g.subjectId), maxLines: 1)),
                    if (average != null && _band(average).isNotEmpty) ...[
                      Text(_band(average), style: T.eyebrow(_colour(average))),
                      const SizedBox(width: 2),
                    ],
                    Text(
                      average == null ? '—' : formatPercent(average),
                      style: T.count(
                        average == null ? C.muted : _colour(average),
                      ),
                    ),
                    Icon(
                      open ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: C.rule,
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                _bar(g, goal),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            spacing: 8,
            children: [
              // Already part of the header's label, so not announced twice.
              Expanded(
                child: ExcludeSemantics(
                  child: Text(_summary(g), style: T.frac),
                ),
              ),
              if (subject != null && goal == null) _setGoal(subject),
            ],
          ),
          if (subject != null && goal != null) ...[
            const SizedBox(height: 8),
            _goalRow(g, subject, goal),
          ],

          if (open) ...[
            if (g.results.isNotEmpty) ...[
              _heading('Results'),
              for (var i = 0; i < g.results.length; i++)
                _resultRow(g.results[i], first: i == 0),
            ],
            if (g.pending.isNotEmpty) ...[
              _heading('Still to come'),
              for (final a in g.pending) _pendingRow(a),
            ],
            if (bands.isNotEmpty && g.remainingOutOf > 0) ...[
              _heading('Marks needed'),
              for (final b in bands.reversed)
                _bandNeedRow(g, b, _focusBand(g, goal)),
            ],
          ],
        ],
      ),
    );
  }

  /// Two lengths in one bar: what is banked against the whole subject, and how
  /// much of the subject has been marked at all.
  ///
  /// Without the second, a single perfect quiz would fill the bar and read as a
  /// finished subject.
  ///
  /// Marked work is drawn full height (banked in colour, dropped in grey);
  /// work still to come is only a hairline, so a short bar under a high
  /// percentage reads as "early in the subject", not as a contradiction. A
  /// goal adds an ink tick where it sits on the same scale.
  Widget _bar(SubjectGrade g, double? goal) {
    final marked = g.totalOutOf <= 0
        ? 0.0
        : (g.markedOutOf / g.totalOutOf).clamp(0.0, 1.0);
    return SizedBox(
      height: 12,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Still to come.
              Positioned(
                left: 0,
                right: 0,
                top: 5.5,
                height: 1,
                child: ColoredBox(color: C.muted),
              ),
              // Marked: banked plus dropped.
              Positioned(
                left: 0,
                top: 3,
                height: 6,
                width: w * marked,
                child: ColoredBox(color: C.rule),
              ),
              Positioned(
                left: 0,
                top: 3,
                height: 6,
                width: w * g.securedFraction.clamp(0.0, 1.0),
                // Coloured by the average, not by how much is banked — a
                // subject one assignment in has banked very little of itself
                // and would read as a fail all semester.
                child: ColoredBox(
                  color: g.average == null
                      ? C.ink
                      : gradeBarColour(g.average! * 100, bands),
                ),
              ),
              if (goal != null)
                Positioned(
                  left: (w * (goal / 100).clamp(0.0, 1.0) - 1).clamp(0, w - 2),
                  top: 0,
                  width: 2,
                  height: 12,
                  child: ColoredBox(color: C.ink),
                ),
            ],
          );
        },
      ),
    );
  }

  /// One key for every bar on the page, under the last card.
  Widget _legend({required bool toCome, required bool goals}) {
    Widget swatch(Widget mark, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        SizedBox(width: 14, height: 12, child: Center(child: mark)),
        Text(label, style: T.count(C.ink)),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        children: [
          swatch(
            Container(width: 14, height: 6, color: C.green),
            'BANKED',
          ),
          swatch(
            Container(width: 14, height: 6, color: C.rule),
            'DROPPED',
          ),
          if (toCome)
            swatch(
              Container(width: 14, height: 1, color: C.muted),
              'TO COME',
            ),
          if (goals)
            swatch(Container(width: 2, height: 12, color: C.ink), 'GOAL'),
        ],
      ),
    );
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 2),
    child: Row(
      spacing: 8,
      children: [
        Text(text.toUpperCase(), style: T.count(C.ink)),
        Expanded(child: Container(height: 1, color: C.rule)),
      ],
    ),
  );

  String _summary(SubjectGrade g) {
    final marked =
        '${trimNumber(g.earned)} of ${trimNumber(g.markedOutOf)} marked';
    if (g.remainingOutOf <= 0) {
      return '$marked · ${g.gradedCount} '
          '${g.gradedCount == 1 ? 'result' : 'results'}';
    }
    return '$marked · ${trimNumber(g.remainingOutOf)} still to come';
  }

  // ------------------------------------------------------------------- goal

  // Unfiled work has no subject to hang a goal on, and inventing one would
  // mean inventing a subject — so both of these are only built for a subject.

  Future<void> _editGoal(Subject subject, double? goal) async {
    final picked = await showGoalSheet(
      context,
      subjectName: subject.name,
      bands: bands,
      current: goal,
    );
    if (picked != null) store.setSubjectGoal(subject, picked.percent);
  }

  /// A quiet text action beside the summary, not a box per card: most
  /// subjects never get a goal, and an empty box reads as a field to fill.
  Widget _setGoal(Subject subject) => Tap(
    onTap: () => _editGoal(subject, null),
    semanticLabel: 'Set a goal for ${subject.name}',
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 3,
        children: [
          Icon(Icons.add, size: 13, color: C.ink),
          Text('SET A GOAL', style: T.count(C.ink)),
        ],
      ),
    ),
  );

  Widget _goalRow(SubjectGrade g, Subject subject, double goal) => Tap(
    onTap: () => _editGoal(subject, goal),
    semanticLabel:
        'Goal for ${subject.name} is ${trimNumber(goal)} percent, '
        'tap to change it',
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: C.field,
        border: Border(left: BorderSide(color: C.ink, width: 2)),
      ),
      child: Row(
        spacing: 8,
        children: [
          Expanded(
            child: Text(
              _goalLine(g, goal),
              style: T.emptyBody.copyWith(color: C.ink),
            ),
          ),
          Text('${trimNumber(goal)}%', style: T.count(C.ink)),
          Icon(Icons.edit_outlined, size: 14, color: C.ink),
        ],
      ),
    ),
  );

  /// The one sentence the goal exists to produce.
  String _goalLine(SubjectGrade g, double goal) {
    final band = bandFor(goal, bands);
    final target = band == null
        ? 'Goal ${trimNumber(goal)}%'
        : 'Goal ${band.name}';

    if (g.secured(goal)) return '$target — already there';
    final need = g.neededFor(goal);
    if (!g.reachable(goal)) {
      return '$target — out of reach, ${trimNumber(need)} needed from '
          '${trimNumber(g.remainingOutOf)}';
    }
    return '$target — ${trimNumber(need)} more of the '
        '${trimNumber(g.remainingOutOf)} left';
  }

  // ----------------------------------------------------------------- detail

  Widget _resultRow(Assignment a, {required bool first}) {
    final met = a.metGoal;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: first
            ? null
            : Border(top: BorderSide(color: C.rule.withValues(alpha: .6))),
      ),
      child: Row(
        spacing: 8,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.title,
                  style: T.task(done: false).copyWith(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (a.due.isNotEmpty) longDate(a.due),
                    if (met != null)
                      met
                          ? 'goal ${trimNumber(a.goal!)} met'
                          : 'goal ${trimNumber(a.goal!)} missed',
                  ].join(' · '),
                  style: T.frac.copyWith(color: met == false ? C.red : null),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(a.markLabel, style: T.count(C.ink)),
              const SizedBox(height: 2),
              Text(
                [
                  if (_band(a.scored!).isNotEmpty) _band(a.scored!),
                  formatPercent(a.scored!),
                ].join(' · '),
                style: T.frac.copyWith(color: _colour(a.scored!)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pendingRow(Assignment a) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Row(
      spacing: 8,
      children: [
        Expanded(
          child: Text(
            a.title,
            style: T.task(done: false).copyWith(fontSize: 13, color: C.muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          a.goal == null
              ? 'out of ${trimNumber(a.outOf!)}'
              : 'goal ${trimNumber(a.goal!)}/${trimNumber(a.outOf!)}',
          style: T.frac,
        ),
      ],
    ),
  );

  /// What one band would take, in marks rather than percentages — because the
  /// marks are the thing you can actually go and earn.
  /// The one row of the table worth reading first: the goal's band when there
  /// is a goal, otherwise the band the subject sits in now.
  GradeBand? _focusBand(SubjectGrade g, double? goal) {
    if (goal != null) return bandFor(goal, bands);
    final average = g.average;
    return average == null ? null : bandFor(average * 100, bands);
  }

  Widget _bandNeedRow(SubjectGrade g, GradeBand b, GradeBand? focus) {
    final need = g.neededFor(b.min);
    final secured = g.secured(b.min);
    final reachable = g.reachable(b.min);
    final focused = identical(b, focus) ||
        (focus != null && b.name == focus.name && b.min == focus.min);

    // Plain information, not a verdict: a band already banked is "safe" in
    // ink, never green, so the bottom band does not read as a success.
    final text = secured
        ? 'Safe'
        : !reachable
        ? 'Out of reach'
        : '${trimNumber(need)} of ${trimNumber(g.remainingOutOf)}';
    final colour = focused || (!secured && reachable) ? C.ink : C.muted;

    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: EdgeInsets.fromLTRB(focused ? 8 : 0, 5, focused ? 8 : 0, 5),
      decoration: focused
          ? BoxDecoration(
              color: C.field,
              border: Border(left: BorderSide(color: C.ink, width: 2)),
            )
          : null,
      child: Row(
        spacing: 8,
        children: [
          Expanded(
            child: Text(
              '${b.name} · ${trimBound(b.min)}%'.toUpperCase(),
              style: focused ? T.count(C.ink) : T.eyebrow(colour),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            text.toUpperCase(),
            style: focused ? T.count(C.ink) : T.eyebrow(colour),
          ),
        ],
      ),
    );
  }

  /// No marks anywhere yet. Says where marks go in words — there is nothing to
  /// press here, because marks belong to an assignment.
  Widget _empty() => Container(
    color: C.card,
    padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nothing to total yet', style: T.emptyHead),
        const SizedBox(height: 6),
        Text(
          'Grades add up the marks on your assignments. To enter one:',
          style: T.emptyBody,
        ),
        const SizedBox(height: 12),
        for (final (i, step) in const [
          'Open the assignment on the Assignments tab.',
          'Tap Edit.',
          'Fill in what it is out of, and your score once it is back.',
        ].indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: C.ink, width: 1.5),
                  ),
                  child: Text('${i + 1}', style: T.count(C.ink)),
                ),
                Expanded(child: Text(step, style: T.body)),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Text(
          'Each subject then gets a card here with its running total, what is '
          'still to come and what each grade would take.',
          style: T.emptyBody,
        ),
      ],
    ),
  );
}
