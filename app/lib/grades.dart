import 'models.dart';

// trimNumber lives with the model it formats; re-exported so the several
// callers that reach for it through this file keep working.
export 'models.dart' show trimNumber;

/// Where a subject stands, totalled from the marks its assignments carry.
///
/// Deliberately unweighted. Weighting was removed pending a decision on how to
/// handle it, so this adds raw marks: 34/40 and 8/10 become 42 out of 50. That
/// is an honest answer to "how am I going" and needs nothing set up beyond the
/// marks themselves — but it is not the unit's final grade, because a quiz and
/// a major report count here in proportion to their marks rather than their
/// actual worth.
///
/// Two totals, not one. [markedOutOf] is what has come back, and drives
/// [average]; [totalOutOf] includes assignments that carry a marks total but no
/// score yet, and is what every projection divides by. Using one for both would
/// either report 100% for a single perfect quiz or refuse to answer "what do I
/// still need" at all.
class SubjectGrade {
  const SubjectGrade({
    required this.subjectId,
    required this.earned,
    required this.results,
    required this.pending,
  });

  /// Null for unfiled assignments, which are still rolled up together so the
  /// marks are not silently dropped.
  final String? subjectId;

  /// Marks scored across everything returned so far.
  final double earned;

  /// Assignments that have come back, soonest-due first.
  final List<Assignment> results;

  /// Assignments carrying a marks total but no score yet — what is still to
  /// play for.
  final List<Assignment> pending;

  int get gradedCount => results.length;

  /// Marks available across what has been returned.
  double get markedOutOf => results.fold<double>(0, (sum, a) => sum + a.outOf!);

  /// Marks still to come.
  double get remainingOutOf =>
      pending.fold<double>(0, (sum, a) => sum + a.outOf!);

  /// Every mark the subject is known to carry.
  double get totalOutOf => markedOutOf + remainingOutOf;

  /// 0..1 across what has been marked, or null when nothing has.
  double? get average => markedOutOf <= 0 ? null : earned / markedOutOf;

  /// Where the subject lands if nothing else is scored at all, 0..1.
  ///
  /// The floor rather than the forecast: it is what the marks already in the
  /// book are worth against everything the subject is out of.
  double get securedFraction => totalOutOf <= 0 ? 0 : earned / totalOutOf;

  /// Marks still needed to finish on [percent] of the subject.
  ///
  /// Negative once the target is already banked, which the caller reports as
  /// "already there" rather than clamping — a zero would read as "you need
  /// nothing more", which is true but says far less.
  double neededFor(double percent) => percent / 100 * totalOutOf - earned;

  /// Whether [percent] is still reachable with the marks left.
  bool reachable(double percent) => neededFor(percent) <= remainingOutOf + 1e-9;

  /// Whether [percent] is already secured whatever happens next.
  bool secured(double percent) => neededFor(percent) <= 1e-9;
}

/// Rolls every mark up by subject.
///
/// An assignment counts as soon as it carries a marks total, scored or not:
/// that is what makes "how much do I still need" answerable. Submitted and open
/// work both count, because a result arrives independently of whether the card
/// has been ticked off.
List<SubjectGrade> gradesBySubject(List<Assignment> items) {
  final byId = <String?, List<Assignment>>{};
  for (final a in items) {
    if ((a.outOf ?? 0) <= 0) continue;
    byId.putIfAbsent(a.subjectId, () => []).add(a);
  }

  final out = <SubjectGrade>[];
  byId.forEach((subjectId, list) {
    list.sort((x, y) => sortKey(x).compareTo(sortKey(y)));
    final results = list.where((a) => a.graded).toList();
    out.add(
      SubjectGrade(
        subjectId: subjectId,
        earned: results.fold<double>(0, (sum, a) => sum + a.earned!),
        results: results,
        pending: list.where((a) => !a.graded).toList(),
      ),
    );
  });
  return out;
}

String formatPercent(double fraction) => '${trimNumber(fraction * 100)}%';
