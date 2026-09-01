import 'package:flutter/material.dart';

import '../grades.dart';
import '../store.dart';
import '../theme.dart';
import 'atoms.dart';

/// Australian grade bands. The "what do I need" table is only useful against
/// the thresholds actually being chased.
const _bands = <(String, double)>[
  ('P', 50),
  ('C', 60),
  ('D', 70),
  ('HD', 80),
];

/// Where each subject stands, and what is still needed.
///
/// A page rather than a strip on the home screen: grades are a thing you go and
/// check, not a thing you need while triaging deadlines, and the home screen is
/// already the densest surface in the app.
class GradesPage extends StatelessWidget {
  const GradesPage({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final grades = gradesBySubject(store.items)
      ..sort((a, b) => _name(a.subjectId).compareTo(_name(b.subjectId)));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: C.ink),
        title: Text('Grades', style: T.title()),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
              children: [
                if (grades.isEmpty)
                  _empty()
                else ...[
                  for (final g in grades) ...[
                    _subjectCard(g),
                    const SizedBox(height: 9),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'A weight is a share of one unit, so subjects are never '
                    'added together. Set one on an assignment from its EDIT '
                    'button.',
                    style: T.note,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _name(String? subjectId) =>
      store.subjects.where((s) => s.id == subjectId).firstOrNull?.name ??
      'Unfiled';

  Color _swatch(String? subjectId) =>
      store.subjects.where((s) => s.id == subjectId).firstOrNull?.swatch ??
      C.muted;

  Widget _subjectCard(SubjectGrade g) {
    final average = g.average;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: C.card),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: 6,
            children: [
              Dot(_swatch(g.subjectId)),
              Expanded(child: Eyebrow(_name(g.subjectId), maxLines: 1)),
              if (average != null)
                Text(formatPercent(average), style: T.count(C.ink)),
            ],
          ),
          const SizedBox(height: 8),

          // Two bars in one: what is banked, and how much of the unit has been
          // decided at all. Without the second, 40/100 mid-semester reads as a
          // fail rather than as "half the unit has not happened yet".
          SizedBox(
            height: 6,
            child: Stack(
              children: [
                Container(color: C.rule),
                FractionallySizedBox(
                  widthFactor: (g.gradedWeight / 100).clamp(0.0, 1.0),
                  child: Container(color: C.rule),
                ),
                FractionallySizedBox(
                  widthFactor: (g.secured / 100).clamp(0.0, 1.0),
                  child: Container(color: C.ink),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Text(
            average == null
                ? 'Nothing marked yet · ${trimNumber(g.trackedWeight)}% of the unit tracked'
                : '${trimNumber(g.secured)} of 100 secured · '
                      '${trimNumber(g.gradedWeight)}% marked · '
                      '${g.gradedCount} ${g.gradedCount == 1 ? 'result' : 'results'}',
            style: T.frac,
          ),

          // The projection is only meaningful against a whole unit. With 25%
          // of one entered, every target reads as already lost — arithmetically
          // right, and a lie about what actually happened, which is that the
          // other assessments have not been entered yet.
          if (g.isPartiallyTracked) ...[
            const SizedBox(height: 6),
            Text(
              'Only ${trimNumber(g.trackedWeight)}% of this unit has a weight '
              'set, so there is no honest projection to make yet. Add what the '
              'remaining assessments are worth.',
              style: T.note,
            ),
          ] else if (g.remainingWeight > 0) ...[
            const SizedBox(height: 12),
            Text('TO FINISH ON', style: T.flabel),
            const SizedBox(height: 5),
            _needTable(g),
          ],
        ],
      ),
    );
  }

  /// What the remaining assessments have to average for each grade band.
  Widget _needTable(SubjectGrade g) => Row(
    spacing: 6,
    children: [
      for (final (label, target) in _bands)
        Expanded(child: _needCell(label, g.neededFor(target))),
    ],
  );

  Widget _needCell(String label, double? needed) {
    // Out of reach and already banked are both real answers, and both more
    // useful than a clamped number that implies the target is still live.
    final unreachable = needed != null && needed > 1;
    final secured = needed != null && needed <= 0;
    final text = needed == null
        ? '—'
        : secured
        ? 'SAFE'
        : unreachable
        ? 'GONE'
        : formatPercent(needed);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      decoration: BoxDecoration(
        color: secured ? C.mark : Colors.transparent,
        border: Border.all(color: unreachable ? C.rule : C.ink),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: T.flabel.copyWith(color: unreachable ? C.muted : C.ink),
          ),
          const SizedBox(height: 3),
          Text(
            text,
            style: T.count(unreachable ? C.muted : C.ink),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _empty() => Container(
    color: C.card,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
    child: Column(
      children: [
        Text('No weights set', style: T.emptyHead, textAlign: TextAlign.center),
        const SizedBox(height: 5),
        Text(
          'Open an assignment, tap EDIT, and set what it is worth. Once a '
          'result comes back, this page works out where the unit stands and '
          'what the rest has to average.',
          style: T.emptyBody,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
