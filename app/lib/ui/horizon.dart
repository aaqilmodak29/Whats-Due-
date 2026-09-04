import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'atoms.dart';

/// The signature element: 14 columns for the next 14 days, one per day.
///
/// A day with deadlines gets a filled block whose height grows with the number
/// due and whose colour comes from [urgency]. Empty days get a hairline. It
/// exists so a crunch week is visible before it arrives.
///
/// It deliberately always shows **all** subjects, whatever the active filter is:
/// the filter narrows the list, not the early warning.
///
/// Bars alone answered "something is due" but not "when" — every column looked
/// alike, so a block four along was somewhere in the fortnight and nowhere in
/// particular. Three things fix that without stealing height from the list: a
/// row of weekday initials, a tint behind weekends so weeks read at a glance,
/// and a count on any bar holding more than one. Tapping a bar filters the list
/// to that day.
class HorizonStrip extends StatelessWidget {
  const HorizonStrip({
    super.key,
    required this.active,
    required this.selectedDue,
    required this.onSelect,
  });

  final List<Assignment> active;

  /// `YYYY-MM-DD` of the day being filtered on, or null.
  final String? selectedDue;

  /// Called with a day's date, or null to clear. Only ever fires for days that
  /// actually have deadlines — an empty day is inert, because selecting one
  /// would filter the list down to nothing and read as a bug.
  final ValueChanged<String?> onSelect;

  static const _days = 14;
  static const _barsHeight = 46.0;
  static const _labelHeight = 16.0;

  @override
  Widget build(BuildContext context) {
    final start = midnight();
    final end = start.add(const Duration(days: _days - 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Flexible on both: a long month pair on a narrow phone would
        // otherwise overflow rather than shorten, and neither label is worth
        // an overflow stripe.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Next 14 days'.toUpperCase(),
                style: T.eyebrow(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // Real dates rather than "Today → +14", which named neither end.
            Flexible(
              child: Text(
                _range(start, end),
                style: T.eyebrow(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: _barsHeight + 1 + _labelHeight,
          child: Stack(
            children: [
              Row(children: _columns(start)),
              // Drawn over the columns so the baseline is continuous rather
              // than broken by the 3px gaps between them.
              Positioned(
                left: 0,
                right: 0,
                top: _barsHeight,
                child: Container(height: 1, color: C.ink),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static const _gap = 3.0;

  /// A week boundary gets a wider gap with a hairline through it.
  ///
  /// The gap does most of the work — grouping by spacing costs no ink at all —
  /// but at phone width seven narrow columns and eight are hard to tell apart,
  /// so the rule makes it unambiguous. One pixel wide, which nothing will
  /// mistake for a bar: an earlier attempt at a full-height *filled* band did
  /// read as one, which is why nothing solid goes in the chart area.
  static const _weekGap = 11.0;

  List<Widget> _columns(DateTime start) {
    final children = <Widget>[];
    for (var day = 0; day < _days; day++) {
      final date = start.add(Duration(days: day));

      if (day > 0) {
        // Monday starts a week. The first column never gets a divider, however
        // it falls — there is nothing to its left to separate it from.
        final startsWeek = date.weekday == DateTime.monday;
        children.add(
          SizedBox(
            // Keyed so a test can count boundaries; a divider is invisible to
            // both the semantics tree and a text finder.
            key: startsWeek
                ? ValueKey('week-start-${formatIsoDate(date)}')
                : null,
            width: startsWeek ? _weekGap : _gap,
            child: startsWeek
                ? Center(child: Container(width: 1, color: C.rule))
                : null,
          ),
        );
      }

      children.add(
        Expanded(
          child: _DayColumn(
            date: date,
            daysAway: day,
            bucket: _bucket(day),
            selected:
                selectedDue != null && selectedDue == formatIsoDate(date),
            onSelect: onSelect,
          ),
        ),
      );
    }
    return children;
  }

  List<Assignment> _bucket(int day) =>
      active.where((a) => daysUntil(a.due) == day).toList();

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// `8 → 21 AUG` within one month, `28 AUG → 10 SEP` across two. Naming the
  /// month once when it is the same both ends keeps the header short on a
  /// narrow phone without losing anything.
  String _range(DateTime start, DateTime end) {
    final endLabel = '${end.day} ${_months[end.month - 1]}';
    final startLabel = start.month == end.month
        ? '${start.day}'
        : '${start.day} ${_months[start.month - 1]}';
    return '$startLabel → $endLabel'.toUpperCase();
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.date,
    required this.daysAway,
    required this.bucket,
    required this.selected,
    required this.onSelect,
  });

  final DateTime date;
  final int daysAway;
  final List<Assignment> bucket;
  final bool selected;
  final ValueChanged<String?> onSelect;

  /// Sunday is 7 in Dart's numbering.
  bool get _isWeekend =>
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

  bool get _isToday => daysAway == 0;

  static const _initials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final iso = formatIsoDate(date);
    final hasWork = bucket.isNotEmpty;

    final column = Column(
      children: [
        SizedBox(
          height: HorizonStrip._barsHeight,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // No weekend tint in the chart area. A full-height band there
              // reads as a tall bar, which is the one thing this strip must
              // never say by accident — the tint lives under the baseline
              // instead, with the labels.
              if (hasWork) _bar() else _hairline(),
            ],
          ),
        ),
        const SizedBox(height: 1),
        SizedBox(
          height: HorizonStrip._labelHeight,
          child: Container(
            alignment: Alignment.center,
            color: selected
                ? C.mark
                // Weeks stay countable without a single extra label, and
                // without putting anything in the chart area.
                : _isWeekend
                ? C.rule.withValues(alpha: .55)
                : null,
            child: Text(
              _initials[date.weekday - 1],
              style: T.eyebrow(
                // A selected day's label sits on the highlighter.
                selected
                    ? C.onMark
                    : _isToday
                    ? C.ink
                    : C.muted,
              ).copyWith(
                fontSize: 9,
                letterSpacing: 0,
                fontWeight: _isToday ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ],
    );

    if (!hasWork) return column;

    return Tap(
      onTap: () => onSelect(selected ? null : iso),
      semanticLabel: selected
          ? 'Clear the filter on ${longDate(iso)}'
          : '${bucket.length} due ${longDate(iso)}, tap to show only these',
      child: Tooltip(
        message: '${bucket.length} due ${longDate(iso)}\n'
            '${bucket.map((a) => '· ${a.title}').join('\n')}',
        child: column,
      ),
    );
  }

  Widget _bar() {
    // 12px for the first, 9px per additional, capped so a brutal week does not
    // blow out the strip's height.
    final height = math.min(40, 12 + (bucket.length - 1) * 9).toDouble();
    final colour = urgency(daysAway);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colour,
        // The selected day gets a highlighter collar rather than a colour
        // change, so the urgency channel keeps meaning only urgency.
        border: selected
            ? Border(
                top: BorderSide(color: C.mark, width: 3),
                left: BorderSide(color: C.mark, width: 3),
                right: BorderSide(color: C.mark, width: 3),
              )
            : null,
      ),
      alignment: Alignment.center,
      // One is obvious from the bar existing; a numeral there would be noise.
      // Two or more is exactly where bar height stops being easy to judge.
      child: bucket.length > 1
          ? Text(
              '${bucket.length}',
              style: T.eyebrow(C.onInk).copyWith(
                fontSize: 9,
                letterSpacing: 0,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
    );
  }

  Widget _hairline() =>
      Opacity(opacity: .55, child: Container(height: 4, color: C.rule));
}
