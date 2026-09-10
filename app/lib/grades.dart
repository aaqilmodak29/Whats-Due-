import 'models.dart';

/// Where a subject stands, totalled from the marks its assignments came back
/// with.
///
/// Deliberately unweighted. Weighting was removed pending a decision on how to
/// handle it, so this adds raw marks: 34/40 and 8/10 become 42 out of 50. That
/// is an honest answer to "how am I going" and needs nothing set up beyond the
/// marks themselves — but it is not the unit's final grade, because a quiz and
/// a major report count here in proportion to their marks rather than their
/// actual worth.
class SubjectGrade {
  const SubjectGrade({
    required this.subjectId,
    required this.earned,
    required this.outOf,
    required this.gradedCount,
  });

  /// Null for unfiled assignments, which are still rolled up together so the
  /// marks are not silently dropped.
  final String? subjectId;

  /// Marks scored, and marks available, across everything returned so far.
  final double earned;
  final double outOf;

  final int gradedCount;

  /// 0..1, or null when nothing has come back yet.
  double? get average => outOf <= 0 ? null : earned / outOf;
}

/// Rolls every returned mark up by subject.
///
/// Submitted and open work both count: a result arrives independently of
/// whether the assignment has been ticked off. Only [Assignment.graded] decides
/// whether it appears at all, so an assignment carrying a marks total but no
/// score yet stays out until it is marked.
List<SubjectGrade> gradesBySubject(List<Assignment> items) {
  final byId = <String?, List<Assignment>>{};
  for (final a in items) {
    if (!a.graded) continue;
    byId.putIfAbsent(a.subjectId, () => []).add(a);
  }

  final out = <SubjectGrade>[];
  byId.forEach((subjectId, list) {
    var earned = 0.0;
    var outOf = 0.0;
    for (final a in list) {
      earned += a.earned!;
      outOf += a.outOf!;
    }
    out.add(
      SubjectGrade(
        subjectId: subjectId,
        earned: earned,
        outOf: outOf,
        gradedCount: list.length,
      ),
    );
  });
  return out;
}

/// Trims the pointless decimal so a mark reads `20`, not `20.0`, while still
/// allowing `12.5`.
String trimNumber(double v) {
  final r = v.round();
  if ((v - r).abs() < 0.005) return '$r';
  return v.toStringAsFixed(1);
}

String formatPercent(double fraction) => '${trimNumber(fraction * 100)}%';
