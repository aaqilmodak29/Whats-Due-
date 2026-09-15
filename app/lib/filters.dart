import 'models.dart';

/// How far out to look, as a window rather than a band.
///
/// Cumulative on purpose: `month` includes everything `week` would have shown.
/// Bands would let a wider choice hide nearer work, which reads as a bug every
/// time — you widen the net and something disappears out of it.
///
/// [later] is the one exception, and unavoidably so: it is the tail past the
/// widest window rather than another window over the same ground.
enum DueWindow { week, fortnight, month, twoMonths, later }

extension DueWindowDetail on DueWindow {
  /// Calendar months are approximated as 30 and 60 days. The filter is a rough
  /// "how far out", and a real month boundary would make the same assignment
  /// fall in or out depending on which month it happened to be.
  int get days => switch (this) {
    DueWindow.week => 7,
    DueWindow.fortnight => 14,
    DueWindow.month => 30,
    DueWindow.twoMonths => 60,
    DueWindow.later => 60,
  };

  String get label => switch (this) {
    DueWindow.week => '7 days',
    DueWindow.fortnight => '14 days',
    DueWindow.month => '1 month',
    DueWindow.twoMonths => '2 months',
    DueWindow.later => 'Later',
  };

  /// What a screen reader announces, since `7 DAYS` on its own could be a
  /// countdown rather than a filter.
  String get semanticLabel => switch (this) {
    DueWindow.later => 'Show work due more than 2 months out',
    _ => 'Show work due within $label',
  };
}

/// Whether [a] falls inside [window].
///
/// Overdue work always passes, whatever the window. It is the most urgent thing
/// there is, and a filter that hides something already late is how it gets
/// forgotten — the windows narrow the future, not the past.
///
/// Undated work never passes. "Due within a month" is not a question that can
/// be asked of an assignment with no date, and quietly including it would make
/// the count wrong.
bool matchesWindow(Assignment a, DueWindow window) {
  final n = daysUntil(a.due);
  if (n == null) return false;
  if (n < 0) return true;
  return window == DueWindow.later ? n > window.days : n <= window.days;
}

/// Case-insensitive substring match on the title.
///
/// Titles only. Searching task text as well would surface a card whose own
/// name does not contain the term, which reads as the search being broken
/// rather than thorough.
bool matchesQuery(Assignment a, String query) {
  final q = query.trim().toLowerCase();
  return q.isEmpty || a.title.toLowerCase().contains(q);
}

/// Everything in [items] that survives both filters.
List<Assignment> applyFilters(
  List<Assignment> items, {
  String query = '',
  DueWindow? window,
}) => items
    .where((a) => matchesQuery(a, query))
    .where((a) => window == null || matchesWindow(a, window))
    .toList();
