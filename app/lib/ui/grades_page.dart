import 'package:flutter/material.dart';

import '../grades.dart';
import '../store.dart';
import '../theme.dart';
import 'atoms.dart';

/// Where each subject stands, from the marks that have come back.
///
/// Its own destination rather than a strip on the list: grades are something
/// you go and check, not something you need while triaging deadlines.
class GradesPage extends StatelessWidget {
  const GradesPage({
    super.key,
    required this.store,
    required this.controller,
  });

  final AppStore store;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final grades = gradesBySubject(store.items)
      ..sort((a, b) => _name(a.subjectId).compareTo(_name(b.subjectId)));
    final results = grades.fold<int>(0, (n, g) => n + g.gradedCount);

    return PageBody(
      controller: controller,
      title: 'Grades',
      eyebrow: grades.isEmpty
          ? 'Nothing marked yet'
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
          const SizedBox(height: 6),
          Text(
            'Marks are added up as they are — a quiz out of 10 and a report out '
            'of 100 count here in proportion to their marks, not to what each '
            'is actually worth towards the subject.',
            style: T.note,
          ),
        ],
      ],
    );
  }

  String _name(String? subjectId) =>
      store.subjects.where((s) => s.id == subjectId).firstOrNull?.name ??
      'Unfiled';

  Color _swatch(String? subjectId) =>
      store.subjects.where((s) => s.id == subjectId).firstOrNull?.swatch ??
      C.muted;

  Widget _subjectCard(SubjectGrade g) {
    final average = g.average!;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: C.card),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: 6,
            children: [
              Dot(_swatch(g.subjectId)),
              Expanded(child: Eyebrow(_name(g.subjectId), maxLines: 1)),
              Text(formatPercent(average), style: T.count(C.ink)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 6,
            child: Stack(
              children: [
                Container(color: C.rule),
                FractionallySizedBox(
                  widthFactor: average.clamp(0.0, 1.0),
                  child: Container(color: C.ink),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '${trimNumber(g.earned)} of ${trimNumber(g.outOf)} marks · '
            '${g.gradedCount} ${g.gradedCount == 1 ? 'result' : 'results'}',
            style: T.frac,
          ),
        ],
      ),
    );
  }

  Widget _empty() => const EmptyState(
    head: 'Nothing marked yet',
    body: 'Set what an assignment is marked out of when you add it, then put '
        'your score in from its EDIT button once it comes back. Subjects '
        'appear here as results arrive.',
  );
}
