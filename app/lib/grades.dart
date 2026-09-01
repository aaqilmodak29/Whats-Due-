import 'models.dart';

/// Where a subject's grade stands, rolled up from its weighted assignments.
///
/// A weight is a share of one unit's final grade, so every figure here is
/// per-subject. Summing across subjects would add percentages of different
/// wholes and produce a number that looks meaningful and is not.
class SubjectGrade {
  const SubjectGrade({
    required this.subjectId,
    required this.secured,
    required this.gradedWeight,
    required this.trackedWeight,
    required this.gradedCount,
  });

  /// Null for unfiled assignments, which are still rolled up together so the
  /// marks are not silently dropped.
  final String? subjectId;

  /// Percentage points of the final grade already banked.
  final double secured;

  /// Weight of the assignments that have come back.
  final double gradedWeight;

  /// Weight of every assignment carrying one, graded or not.
  final double trackedWeight;

  final int gradedCount;

  /// Weight still to be decided.
  double get remainingWeight => trackedWeight - gradedWeight;

  /// Average across what has been graded, 0..1. Null before anything is.
  ///
  /// This is the honest "how am I doing" number: [secured] alone reads as a
  /// failing grade all semester, because most of the unit has not happened yet.
  double? get average => gradedWeight <= 0 ? null : secured / gradedWeight;

  /// The unit is normally marked out of 100. Anything short of that means
  /// assessments have not been entered, and every projection below is only as
  /// complete as what has been.
  bool get isPartiallyTracked => trackedWeight < 99.5;

  /// Average needed across everything still outstanding to finish on [target]
  /// percent overall, as a fraction 0..1.
  ///
  /// Can exceed 1 when the target is already out of reach, and go below 0 when
  /// it is already secured; both are useful answers, so neither is clamped.
  /// Null when nothing is outstanding to score on.
  double? neededFor(double target) =>
      remainingWeight <= 0 ? null : (target - secured) / remainingWeight;
}

/// Rolls every weighted assignment up by subject.
///
/// Submitted and open work both count: an assignment carries a weight from the
/// day it is set, and its result arrives independently of whether it has been
/// ticked off. Only [Assignment.weight] decides whether it appears at all.
List<SubjectGrade> gradesBySubject(List<Assignment> items) {
  final byId = <String?, List<Assignment>>{};
  for (final a in items) {
    if (a.weight == null || a.weight! <= 0) continue;
    byId.putIfAbsent(a.subjectId, () => []).add(a);
  }

  final out = <SubjectGrade>[];
  byId.forEach((subjectId, list) {
    var secured = 0.0;
    var gradedWeight = 0.0;
    var trackedWeight = 0.0;
    var gradedCount = 0;
    for (final a in list) {
      trackedWeight += a.weight!;
      final c = a.contribution;
      if (c == null) continue;
      secured += c;
      gradedWeight += a.weight!;
      gradedCount++;
    }
    out.add(
      SubjectGrade(
        subjectId: subjectId,
        secured: secured,
        gradedWeight: gradedWeight,
        trackedWeight: trackedWeight,
        gradedCount: gradedCount,
      ),
    );
  });
  return out;
}

/// Trims the pointless decimal so a weight reads `20%`, not `20.0%`, while
/// still allowing `12.5`.
String trimNumber(double v) {
  final r = v.round();
  if ((v - r).abs() < 0.005) return '$r';
  return v.toStringAsFixed(1);
}

String formatPercent(double fraction) => '${trimNumber(fraction * 100)}%';
