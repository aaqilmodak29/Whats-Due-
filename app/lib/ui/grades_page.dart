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
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          _key(
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

  /// How a fraction should be coloured. See [_tone].
  Color _colour(double fraction) => _tone(fraction * 100);

  /// The one colour rule on this page: a band's word, its percentage and its
  /// bar all take the same colour, so a grade never reads two ways at once.
  ///
  /// Below the pass mark is red. The passing bands climb one scale from a
  /// quiet slate through ink to the full green at the top, so each band is
  /// its own step and the top one is the only "done" green. The middle band of
  /// the default four sits exactly on ink, the same as [gradeColour] puts it.
  /// Without bands there are no steps to show, so it keeps [gradeColour]'s
  /// three.
  Color _tone(double percent) {
    if (bands.length < 2) return gradeColour(percent, bands);
    if (percent + 1e-9 < bands[1].min) return C.red;
    final passing = bands.length - 1;
    if (passing <= 1) return C.green;
    final band = bandFor(percent, bands);
    final rank = band == null ? 0 : bands.indexOf(band) - 1;
    final t = rank / (passing - 1);
    const pivot = 1 / 3;
    if (t >= 1 - 1e-9) return C.green;
    if ((t - pivot).abs() < 1e-9) return C.ink;
    if (t > pivot) return Color.lerp(C.ink, C.green, (t - pivot) / (1 - pivot))!;
    return Color.lerp(C.muted, C.ink, .4 + .6 * t / pivot)!;
  }

  /// Secondary lines under a title or a bar: sentences, so sans, one size.
  TextStyle get _meta => T.emptyBody;

  // ------------------------------------------------------------------- card

  Widget _subjectCard(SubjectGrade g) {
    final average = g.average;
    final key = g.subjectId ?? '';
    final open = _openId == key;
    final subject = _subjectOf(g.subjectId);
    final goal = subject?.goalPercent;
    final tone = average == null ? C.muted : _colour(average);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: C.card),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
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
                      Text(_band(average), style: T.count(tone)),
                      const SizedBox(width: 2),
                    ],
                    Text(
                      average == null ? '—' : formatPercent(average),
                      style: T.count(tone),
                    ),
                    Icon(
                      open ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: C.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _bar(g, goal),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            spacing: 8,
            children: [
              // Already part of the header's label, so not announced twice.
              Expanded(
                child: ExcludeSemantics(
                  child: Text(_summary(g), style: _meta),
                ),
              ),
              if (subject != null && goal == null) _setGoal(subject),
            ],
          ),
          if (subject != null && goal != null) ...[
            const SizedBox(height: 10),
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
              for (var i = 0; i < g.pending.length; i++)
                _pendingRow(g.pending[i], first: i == 0),
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
  /// Marked work is solid (banked in the grade's colour, dropped in grey);
  /// work still to come is an empty outline, a box not filled in yet. A goal
  /// is an ink tick on the same scale, named right above it.
  Widget _bar(SubjectGrade g, double? goal) {
    final marked = g.totalOutOf <= 0
        ? 0.0
        : (g.markedOutOf / g.totalOutOf).clamp(0.0, 1.0);
    final at = goal == null ? null : (goal / 100).clamp(0.0, 1.0);
    final bar = SizedBox(
      height: 14,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Still to come: the whole subject, outlined.
              Positioned(
                left: 0,
                right: 0,
                top: 4,
                height: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: C.rule),
                  ),
                ),
              ),
              // Marked: banked plus dropped.
              Positioned(
                left: 0,
                top: 4,
                height: 6,
                width: w * marked,
                child: ColoredBox(color: C.rule),
              ),
              Positioned(
                left: 0,
                top: 4,
                height: 6,
                width: w * g.securedFraction.clamp(0.0, 1.0),
                // Coloured by the average, not by how much is banked — a
                // subject one assignment in has banked very little of itself
                // and would read as a fail all semester.
                child: ColoredBox(
                  color: g.average == null ? C.ink : _colour(g.average!),
                ),
              ),
              if (at != null)
                Positioned(
                  left: (w * at - 1).clamp(0, w - 2),
                  top: 0,
                  width: 2,
                  height: 14,
                  child: ColoredBox(color: C.ink),
                ),
            ],
          );
        },
      ),
    );
    if (at == null) return bar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The caption the tick needs: one word, over the tick itself.
        Align(
          alignment: Alignment(at * 2 - 1, 0),
          child: ExcludeSemantics(
            child: Text('GOAL', style: T.chip(C.ink)),
          ),
        ),
        const SizedBox(height: 2),
        bar,
      ],
    );
  }

  /// The colours and marks every card uses, explained once under the last
  /// card: the grading bands in their colours, then what the bar's parts mean.
  Widget _key({required bool toCome, required bool goals}) {
    Widget row(Widget mark, String label) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          SizedBox(width: 18, height: 14, child: Center(child: mark)),
          Text(label, style: T.chip(C.ink)),
        ],
      ),
    );
    Widget block(Color colour) =>
        Container(width: 18, height: 6, color: colour);

    final ordered = bands.reversed.toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ordered.length >= 2) ...[
            Text('BANDS', style: T.eyebrow(C.ink)),
            const SizedBox(height: 6),
            for (final (i, b) in ordered.indexed)
              row(
                block(_tone(b.min)),
                i == ordered.length - 1
                    ? '${b.name} · below ${trimBound(ordered[i - 1].min)}%'
                          .toUpperCase()
                    : '${b.name} · from ${trimBound(b.min)}%'.toUpperCase(),
              ),
            const SizedBox(height: 14),
          ],
          Text('THE BAR', style: T.eyebrow(C.ink)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 18,
            runSpacing: 2,
            children: [
              // Banked takes whichever band colour the subject is in.
              row(
                ordered.length < 2
                    ? block(C.ink)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final b in ordered.reversed)
                            Container(
                              width: 18 / ordered.length,
                              height: 6,
                              color: _tone(b.min),
                            ),
                        ],
                      ),
                'BANKED',
              ),
              row(block(C.rule), 'DROPPED'),
              if (toCome)
                row(
                  Container(
                    width: 18,
                    height: 6,
                    decoration: BoxDecoration(
                      border: Border.all(color: C.rule),
                    ),
                  ),
                  'TO COME',
                ),
              if (goals)
                row(Container(width: 2, height: 14, color: C.ink), 'GOAL'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 4),
    child: Row(
      spacing: 8,
      children: [
        Text(text.toUpperCase(), style: T.eyebrow(C.ink)),
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
  /// Muted, so the grade stays the loudest thing on the card.
  Widget _setGoal(Subject subject) => Tap(
    onTap: () => _editGoal(subject, null),
    semanticLabel: 'Set a goal for ${subject.name}',
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 3,
        children: [
          Icon(Icons.add, size: 12, color: C.muted),
          Text('SET A GOAL', style: T.count(C.muted)),
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
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: C.paper.withValues(alpha: .55),
        border: Border(left: BorderSide(color: C.ink, width: 2)),
      ),
      child: Row(
        spacing: 8,
        children: [
          // The percentage is already in the band's name or the sentence, and
          // the header carries the average, so the line does not repeat it.
          Expanded(
            child: Text(
              _goalLine(g, goal),
              style: T.emptyBody.copyWith(color: C.ink),
            ),
          ),
          Icon(Icons.edit_outlined, size: 15, color: C.ink),
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
    final band = _band(a.scored!);
    return _detailRow(
      first: first,
      title: a.title,
      meta: [
        if (a.due.isNotEmpty) longDate(a.due),
        if (met != null)
          met
              ? 'goal ${trimNumber(a.goal!)} met'
              : 'goal ${trimNumber(a.goal!)} missed',
      ].join(' · '),
      metaColour: met == false ? C.red : null,
      value: Text(a.markLabel, style: T.count(C.ink)),
      note: Text(
        [if (band.isNotEmpty) band, formatPercent(a.scored!)].join(' · '),
        style: T.count(_colour(a.scored!)),
      ),
    );
  }

  /// Still to come, laid out like a result so the two lists line up: the
  /// title in ink, what it is out of where the mark will go.
  Widget _pendingRow(Assignment a, {required bool first}) => _detailRow(
    first: first,
    title: a.title,
    meta: a.due.isEmpty ? '' : longDate(a.due),
    value: Text('OUT OF ${trimNumber(a.outOf!)}', style: T.count(C.ink)),
    note: a.goal == null
        ? null
        : Text('GOAL ${trimNumber(a.goal!)}', style: T.count(C.muted)),
  );

  Widget _detailRow({
    required bool first,
    required String title,
    required String meta,
    required Widget value,
    Widget? note,
    Color? metaColour,
  }) => Container(
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
                title,
                style: T.task(done: false),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: metaColour == null
                      ? _meta
                      : _meta.copyWith(color: metaColour),
                ),
              ],
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            value,
            if (note != null) ...[const SizedBox(height: 3), note],
          ],
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
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: focused
          ? BoxDecoration(
              color: C.paper.withValues(alpha: .55),
              border: Border(left: BorderSide(color: C.ink, width: 2)),
            )
          : BoxDecoration(
              border: Border(left: BorderSide(color: _tone(b.min), width: 2)),
            ),
      child: Row(
        spacing: 8,
        children: [
          Expanded(
            child: Text(
              '${b.name} · ${trimBound(b.min)}%'.toUpperCase(),
              style: T.count(colour),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(text.toUpperCase(), style: T.count(colour)),
        ],
      ),
    );
  }

  /// No marks anywhere yet. The same shape as an empty Assignments list:
  /// an icon, what happened, and the one place to go about it. Marks belong
  /// to an assignment, so that place is the Assignments tab.
  Widget _empty() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
    child: Column(
      children: [
        Icon(Icons.insights_outlined, size: 40, color: C.ink),
        const SizedBox(height: 14),
        Text(
          'Nothing to total yet',
          style: T.emptyHead,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        Text(
          'Open an assignment, tap Edit and fill in what it is out of. '
          'Once your score is back, its subject gets a card here.',
          style: T.emptyBody.copyWith(color: C.ink),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        GhostButton(
          label: 'Open Assignments',
          filled: true,
          onPressed: _openAssignments,
        ),
      ],
    ),
  );

  /// Exactly what the Assignments tab in the nav bar does: the pages sit in
  /// one [PageView], so this turns it to the first page the same way, and the
  /// shell follows the page change.
  void _openAssignments() {
    final pages = context.findAncestorWidgetOfExactType<PageView>()?.controller;
    if (pages == null || !pages.hasClients) return;
    pages.animateToPage(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }
}
