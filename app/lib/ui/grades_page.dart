import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../bands.dart';
import '../grades.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'atoms.dart';
import 'band_colours.dart';
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
    // School work only: general work is not graded.
    final grades = gradesBySubject(store.schoolItems)
      ..sort((a, b) => _name(a.subjectId).compareTo(_name(b.subjectId)));
    final results = grades.fold<int>(0, (n, g) => n + g.gradedCount);

    return LayoutBuilder(
      builder: (context, box) => _page(grades, results, box.maxHeight),
    );
  }

  Widget _page(List<SubjectGrade> grades, int results, double height) {
    return PageBody(
      controller: widget.controller,
      title: 'Grades',
      children: [
        if (grades.isEmpty)
          _empty(height)
        else ...[
          // The count heads the list it counts, in the semibold mono the
          // cards' figures use: the page's thin grey eyebrow fails contrast.
          Text(
            '${grades.length} ${grades.length == 1 ? 'subject' : 'subjects'}'
                    ' · $results ${results == 1 ? 'result' : 'results'}'
                .toUpperCase(),
            style: T.count(C.ink),
          ),
          const SizedBox(height: 10),
          for (final g in grades) ...[
            _subjectCard(g),
            const SizedBox(height: 12),
          ],
          // Room to scroll the last card clear of the bottom nav.
          const SizedBox(height: 72),
        ],
      ],
    );
  }

  SubjectGrade? _gradeOf(Subject subject) => gradesBySubject(
    store.schoolItems,
  ).where((g) => g.subjectId == subject.id).firstOrNull;

  String _name(String? subjectId) => _subjectOf(subjectId)?.name ?? 'Unfiled';

  Subject? _subjectOf(String? id) =>
      store.subjects.where((s) => s.id == id).firstOrNull;

  Color _swatch(String? id) => _subjectOf(id)?.swatch ?? C.muted;

  /// The band a fraction lands in, as a short label, or empty without bands.
  String _band(double fraction) =>
      bandFor(fraction * 100, bands)?.name.toUpperCase() ?? '';

  /// How a fraction should be coloured: the app's one band scale, see
  /// [bandColour]. The band's word and its bar take it; the percentage beside
  /// the word stays ink, so the colour is read once, on the word.
  Color _colour(double fraction) => bandColour(fraction * 100, bands);

  /// The percentage carries the colour only when there is no band word to
  /// carry it.
  Color _percentColour(double fraction) =>
      _band(fraction).isEmpty ? _colour(fraction) : C.ink;

  /// Secondary lines under a title or a bar: sentences, so sans, one size,
  /// in ink so they read on both grounds.
  TextStyle get _meta => T.emptyBody.copyWith(color: C.ink);

  // ------------------------------------------------------------------- card

  Widget _subjectCard(SubjectGrade g) {
    final average = g.average;
    final key = g.subjectId ?? '';
    final open = _openId == key;
    final subject = _subjectOf(g.subjectId);
    final goal = subject?.goalPercent;
    final tone = average == null ? C.ink : _colour(average);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: C.card),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
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
                    Expanded(
                      child: Eyebrow(
                        _name(g.subjectId),
                        color: C.ink,
                        maxLines: 1,
                      ),
                    ),
                    if (average != null && _band(average).isNotEmpty) ...[
                      Text(_band(average), style: T.count(tone)),
                      const SizedBox(width: 2),
                    ],
                    // Plain figures, not spaced caps: the band word is the
                    // label, the percentage is the number behind it.
                    Text(
                      average == null ? '—' : formatPercent(average),
                      style: T.monoInput.copyWith(
                        color: average == null
                            ? C.ink
                            : _percentColour(average),
                      ),
                    ),
                    Icon(
                      open ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: C.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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
                child: ExcludeSemantics(child: Text(_summary(g), style: _meta)),
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
  ///
  /// Three segments, left to right, each with a hairline of card between it
  /// and the next so they read apart: banked in the grade's colour, dropped
  /// in solid grey, and work still to come as an empty outline, a box not
  /// filled in yet. A goal is an ink tick standing proud of the bar, named
  /// above it with room to spare.
  Widget _bar(SubjectGrade g, double? goal) {
    final total = g.totalOutOf;
    final banked = total <= 0 ? 0.0 : g.securedFraction.clamp(0.0, 1.0);
    final marked = total <= 0 ? 0.0 : (g.markedOutOf / total).clamp(0.0, 1.0);
    final at = goal == null ? null : (goal / 100).clamp(0.0, 1.0);
    // Coloured by the average, not by how much is banked — a subject one
    // assignment in has banked very little of itself and would read as a
    // fail all semester.
    final tone = g.average == null ? C.ink : _colour(g.average!);
    final bar = SizedBox(
      height: _barBox,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              ..._segments(w, banked, marked, tone),
              if (at != null)
                Positioned(
                  left: (w * at - 1).clamp(0, w - 2),
                  top: 0,
                  width: 2,
                  height: _barBox,
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
        // The caption the tick needs, over the tick itself and clear of the
        // bar: the tick rises into the gap to meet it.
        Align(
          alignment: Alignment(at * 2 - 1, 0),
          child: ExcludeSemantics(child: Text('GOAL', style: T.chip(C.ink))),
        ),
        const SizedBox(height: 3),
        bar,
      ],
    );
  }

  /// The bar's height, and the box round it the goal tick fills.
  static const _barHeight = 10.0;
  static const _barBox = _barHeight + 8;

  /// Banked, dropped and to come as three blocks with a 2px gap between
  /// neighbours. A segment too thin to see is left out with its gap.
  List<Widget> _segments(double w, double banked, double marked, Color tone) {
    const gap = 2.0;
    final parts = <(double, Widget)>[
      (w * banked, ColoredBox(color: tone)),
      (w * (marked - banked), ColoredBox(color: C.rule)),
      (
        w * (1 - marked),
        DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: C.muted)),
        ),
      ),
    ].where((p) => p.$1 >= 1).toList();
    final out = <Widget>[];
    var edge = 0.0;
    for (var i = 0; i < parts.length; i++) {
      final end = i == parts.length - 1 ? w : edge + parts[i].$1;
      final left = i == 0 ? edge : edge + gap / 2;
      final right = i == parts.length - 1 ? end : end - gap / 2;
      out.add(
        Positioned(
          left: left,
          top: (_barBox - _barHeight) / 2,
          height: _barHeight,
          width: math.max(1, right - left),
          child: parts[i].$2,
        ),
      );
      edge = end;
    }
    return out;
  }

  /// Splits the open card into its sections. A full-width ink rule above the
  /// name, not a grey hairline trailing off it: with three lists of rows under
  /// one another, the break between them has to be the strongest line there.
  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(height: 1, color: C.ink),
        const SizedBox(height: 8),
        Text(text.toUpperCase(), style: T.count(C.ink)),
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
      average: _gradeOf(subject)?.average,
      standing: switch (_gradeOf(subject)) {
        final g? => _summary(g),
        null => null,
      },
    );
    if (picked != null) store.setSubjectGoal(subject, picked.percent);
  }

  /// A text link beside the summary, not a box per card: most subjects
  /// never get a goal, and an empty box reads as a field to fill. The app's
  /// one style for an inline action: underlined mono.
  Widget _setGoal(Subject subject) => Tap(
    onTap: () => _editGoal(subject, null),
    semanticLabel: 'Set a goal for ${subject.name}',
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text('SET A GOAL', style: T.link),
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

  /// The one sentence the goal exists to produce. Reached or not first, then
  /// what it would still take. Which grade is being aimed at is the tick on
  /// the bar above it, so the line does not name it again.
  String _goalLine(SubjectGrade g, double goal) {
    if (g.secured(goal)) return 'Goal reached';
    final need =
        '${trimNumber(g.neededFor(goal))} of '
        '${trimNumber(g.remainingOutOf)} left';
    return g.reachable(goal)
        ? 'Goal not reached, $need'
        : 'Goal out of reach, $need';
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
      // The same rule as the card's header: the band word in its colour,
      // the percentage plain.
      note: Text.rich(
        TextSpan(
          children: [
            if (band.isNotEmpty)
              TextSpan(text: '$band · ', style: T.count(_colour(a.scored!))),
            TextSpan(
              text: formatPercent(a.scored!),
              style: T.count(_percentColour(a.scored!)),
            ),
          ],
        ),
      ),
    );
  }

  /// Still to come, laid out like a result so the two lists line up: the
  /// title in ink, and in the mark's place the same `-/5` the cards use for a
  /// mark not back yet, muted so the real marks above it come first.
  Widget _pendingRow(Assignment a, {required bool first}) => _detailRow(
    first: first,
    title: a.title,
    meta: a.due.isEmpty ? '' : longDate(a.due),
    value: Text(a.markLabel, style: T.count(C.muted)),
    note: a.goal == null
        ? null
        : Text('GOAL ${trimNumber(a.goal!)}', style: T.chip(C.muted)),
  );

  Widget _detailRow({
    required bool first,
    required String title,
    required String meta,
    required Widget value,
    Widget? note,
    Color? metaColour,
  }) => Container(
    padding: const EdgeInsets.symmetric(vertical: 7),
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
                const SizedBox(height: 3),
                // Dates read the app's one way: upper-case mono. A size down
                // and muted here, where eight rows of them sit under one
                // another and the titles are what you read first.
                Text(meta.toUpperCase(), style: T.chip(metaColour ?? C.muted)),
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
  ///
  /// Every row the same: the band's colour as a rule on the left, the figure
  /// flush with the right edge the rows above use. A goal is already named
  /// once on the card, so the table does not highlight it a second time.
  Widget _bandNeedRow(SubjectGrade g, GradeBand b) {
    final need = g.neededFor(b.min);
    final secured = g.secured(b.min);
    final reachable = g.reachable(b.min);

    // Plain information, not a verdict: a band already banked is "safe" in
    // ink, never green, so the bottom band does not read as a success.
    final text = secured
        ? 'Safe'
        : !reachable
        ? 'Out of reach'
        : '${trimNumber(need)} of ${trimNumber(g.remainingOutOf)}';
    final colour = !secured && reachable ? C.ink : C.muted;

    // Drawn like the bands in the key under the cards: the name as a word in
    // sans, the floor and the figure as data in mono, so the block reads as
    // a list of bands rather than a wall of capitals.
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.fromLTRB(10, 4, 0, 4),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: colourOfBand(b, bands), width: 4),
        ),
      ),
      child: Row(
        spacing: 8,
        children: [
          Expanded(
            child: Text(
              b.name,
              style: _meta.copyWith(color: colour),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              bandFloor(b),
              style: T.count(colour),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 96,
            child: Text(
              text.toUpperCase(),
              style: T.count(colour),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  /// No marks anywhere yet. The app's one empty-state shape, the same
  /// [EmptyState] the Assignments list uses: an icon on the page, what
  /// happened, one sentence and the one place to go about it. Marks belong to
  /// an assignment, so that place is the Assignments tab.
  Widget _empty(double height) {
    // PageBody's own chrome above and below the list: its padding, the
    // "Coursework" eyebrow, the title and the gap under it.
    const chrome = 20 + 14 + 3 + 33.6 + 18 + 32;
    // The Assignments page spends about this much more on its tab strip, so
    // leaving it out of the centring puts the block at the same height as
    // that page's empty state.
    const tabs = 80;
    final free = height - MediaQuery.paddingOf(context).vertical - chrome;
    return EmptyState(
      icon: Icons.insights_outlined,
      head: 'Nothing to total yet',
      body:
          'Each subject gets a card here. To start, open an assignment, '
          'tap Edit and fill in what it is out of.',
      action: 'Open Assignments',
      primary: true,
      onAction: _openAssignments,
      minHeight: free - tabs < 0 ? 0 : free - tabs,
    );
  }

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
