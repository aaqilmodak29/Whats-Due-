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
          ? 'Nothing to total yet'
          : '${grades.length} ${grades.length == 1 ? 'subject' : 'subjects'}'
                ' · $results ${results == 1 ? 'result' : 'results'}',
      children: [
        if (grades.isEmpty)
          _empty()
        else
          for (final g in grades) ...[
            _subjectCard(g),
            const SizedBox(height: 9),
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
                const SizedBox(height: 8),
                _bar(g),
                const SizedBox(height: 7),
                Text(_summary(g), style: T.frac),
              ],
            ),
          ),

          const SizedBox(height: 10),
          _goalRow(g, subject, goal),

          if (open) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: C.rule),
            for (final a in g.results) _resultRow(a),
            if (g.pending.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('STILL TO COME', style: T.flabel),
              for (final a in g.pending) _pendingRow(a),
            ],
            if (bands.isNotEmpty && g.remainingOutOf > 0) ...[
              const SizedBox(height: 14),
              Text('MARKS NEEDED', style: T.flabel),
              const SizedBox(height: 6),
              for (final b in bands.reversed) _bandNeedRow(g, b),
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
  Widget _bar(SubjectGrade g) => SizedBox(
    height: 6,
    child: Stack(
      children: [
        Container(color: C.rule),
        FractionallySizedBox(
          widthFactor: g.totalOutOf <= 0
              ? 0
              : (g.markedOutOf / g.totalOutOf).clamp(0.0, 1.0),
          child: Container(color: C.rule),
        ),
        FractionallySizedBox(
          widthFactor: g.securedFraction.clamp(0.0, 1.0),
          // Coloured by the average, not by how much is banked — a subject one
          // assignment in has banked very little of itself and would read as a
          // fail all semester.
          child: Container(
            color: g.average == null ? C.ink : _colour(g.average!),
          ),
        ),
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

  Widget _goalRow(SubjectGrade g, Subject? subject, double? goal) {
    // Unfiled work has no subject to hang a goal on, and inventing one would
    // mean inventing a subject.
    if (subject == null) return const SizedBox.shrink();

    return Tap(
      onTap: () async {
        final picked = await showGoalSheet(
          context,
          subjectName: subject.name,
          bands: bands,
          current: goal,
        );
        if (picked != null) store.setSubjectGoal(subject, picked.percent);
      },
      semanticLabel: goal == null
          ? 'Set a goal for ${subject.name}'
          : 'Goal for ${subject.name} is ${trimNumber(goal)} percent, '
                'tap to change it',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: C.field,
          border: Border.all(color: goal == null ? C.rule : C.ink),
        ),
        child: Row(
          children: [
            Expanded(
              child: goal == null
                  ? Text('SET A GOAL', style: T.ghost(C.muted))
                  : Text(
                      _goalLine(g, goal),
                      style: T.frac.copyWith(color: C.ink),
                    ),
            ),
            const SizedBox(width: 8),
            Text(
              goal == null ? '' : '${trimNumber(goal)}%',
              style: T.count(C.ink),
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _resultRow(Assignment a) {
    final met = a.metGoal;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
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
    padding: const EdgeInsets.only(top: 8),
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
  Widget _bandNeedRow(SubjectGrade g, GradeBand b) {
    final need = g.neededFor(b.min);
    final secured = g.secured(b.min);
    final reachable = g.reachable(b.min);

    final (text, colour) = secured
        ? ('Safe', C.green)
        : !reachable
        ? ('Out of reach', C.muted)
        : ('${trimNumber(need)} of ${trimNumber(g.remainingOutOf)}', C.ink);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        spacing: 8,
        children: [
          Expanded(
            child: Text(
              '${b.name} · ${trimBound(b.min)}%'.toUpperCase(),
              style: T.eyebrow(secured ? C.green : C.muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(text.toUpperCase(), style: T.eyebrow(colour)),
        ],
      ),
    );
  }

  Widget _empty() => const EmptyState(
    head: 'Nothing to total yet',
    body: 'Set what an assignment is marked out of and it shows up here.',
  );
}
