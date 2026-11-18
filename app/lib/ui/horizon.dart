import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'atoms.dart';

/// The signature element: a fortnight of columns, one per day.
///
/// A day with deadlines gets a filled block whose height grows with the number
/// due and whose colour comes from [urgency]. Empty days get a hairline. It
/// exists so a crunch week is visible before it arrives.
///
/// It deliberately always charts **all** subjects, whatever the active filter
/// is: the filter narrows the list, not the early warning. With a subject
/// chosen, days with nothing in it fade ([focus]) but keep their bar, count
/// and tap.
///
/// The legend (which fortnight, which dates) sits in a column to the left of
/// the chart rather than on a row above it, so the strip costs one band of
/// height instead of two.
///
/// Bars alone answered "something is due" but not "when" — every column looked
/// alike, so a block four along was somewhere in the fortnight and nowhere in
/// particular. Three things fix that without stealing height from the list: a
/// row of weekday initials, a tint behind weekends so weeks read at a glance,
/// and a count on any bar holding more than one. Tapping a bar filters the list
/// to that day.
///
/// **Paged by the fortnight, aligned to Monday.** It used to start at today and
/// run fourteen days forward, so the Monday just gone was invisible, every page
/// began on a different weekday, and the weekend tints never sat in the same
/// place twice. Each page is two whole weeks now, Monday to Sunday twice, and a
/// swipe moves a full fortnight.
class HorizonStrip extends StatefulWidget {
  const HorizonStrip({
    super.key,
    required this.active,
    required this.selectedDue,
    required this.onSelect,
    this.focus,
  });

  final List<Assignment> active;

  /// When the list is narrowed to one subject, which work belongs to it. A
  /// day with deadlines but none in focus stays charted (and tappable, with
  /// the same count), only faded, so the strip still warns about the whole
  /// fortnight while showing which bars the list below is about.
  final bool Function(Assignment)? focus;

  /// `YYYY-MM-DD` of the day being filtered on, or null.
  final String? selectedDue;

  /// Called with a day's date, or null to clear. Only ever fires for days that
  /// actually have deadlines — an empty day is inert, because selecting one
  /// would filter the list down to nothing and read as a bug.
  final ValueChanged<String?> onSelect;

  static const _days = 14;
  static const _barsHeight = 28.0;
  static const _labelHeight = 16.0;

  /// The legend's column: room for `28 AUG → 10 SEP` on one line.
  static const _legendWidth = 112.0;

  /// Pages either side of the current fortnight — about seven years each way.
  /// Unbounded in every sense that matters for coursework, without an infinite
  /// builder that can never say how far it goes.
  static const reach = 180;

  @override
  State<HorizonStrip> createState() => _HorizonStripState();
}

class _HorizonStripState extends State<HorizonStrip> {
  late final _pages = PageController(initialPage: HorizonStrip.reach);
  int _page = HorizonStrip.reach;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// The Monday page [i] starts on.
  DateTime _startOf(int i) => mondayOf(
    midnight(),
  ).add(Duration(days: (i - HorizonStrip.reach) * HorizonStrip._days));

  bool get _onCurrent => _page == HorizonStrip.reach;

  @override
  Widget build(BuildContext context) {
    final start = _startOf(_page);
    final end = start.add(const Duration(days: HorizonStrip._days - 1));

    // The legend sits beside the chart rather than on a row above it: the
    // same two facts, a line of height less, so the list starts sooner.
    return SizedBox(
      height: HorizonStrip._barsHeight + 2 + HorizonStrip._labelHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: HorizonStrip._legendWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Nothing above the dates on the current fortnight: the bars
                // are today's by default, so a label saying so is one more
                // line to read every time. The way back appears only once you
                // have moved off it.
                if (!_onCurrent)
                  Tap(
                    onTap: () => _pages.animateToPage(
                      HorizonStrip.reach,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                    ),
                    semanticLabel: 'Back to this fortnight',
                    child: Text(
                      'Back to today'.toUpperCase(),
                      style: T
                          .eyebrow(C.ink)
                          .copyWith(decoration: TextDecoration.underline),
                      maxLines: 1,
                    ),
                  ),
                // Real dates rather than "Today → +14", which named neither
                // end.
                // Ink: the grey dates read as faint beside the ink chart.
                Text(
                  _range(start, end),
                  style: T.eyebrow(C.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: HorizonStrip.reach * 2 + 1,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => Stack(
                children: [
                  Row(children: _columns(_startOf(i))),
                  // Drawn over the columns so the baseline is continuous
                  // rather than broken by the 3px gaps between them.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: HorizonStrip._barsHeight,
                    child: Container(height: 1, color: C.ink),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
    for (var day = 0; day < HorizonStrip._days; day++) {
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
            // Measured against today, not against the page: a column in a
            // fortnight already gone has to colour as overdue, and the one
            // that is today has to know it.
            daysAway: daysUntil(formatIsoDate(date)) ?? 0,
            bucket: _bucket(date),
            faded: widget.focus != null && !_bucket(date).any(widget.focus!),
            selected:
                widget.selectedDue != null &&
                widget.selectedDue == formatIsoDate(date),
            onSelect: widget.onSelect,
          ),
        ),
      );
    }
    return children;
  }

  List<Assignment> _bucket(DateTime date) {
    final iso = formatIsoDate(date);
    return widget.active.where((a) => a.due == iso).toList();
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
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
    this.faded = false,
  });

  final DateTime date;

  /// Deadlines that day, none of them in the subject the list is showing.
  final bool faded;
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
              if (!hasWork)
                _hairline()
              else if (faded)
                _bar(faded: true)
              else
                _bar(),
            ],
          ),
        ),
        const SizedBox(height: 2),
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
              // Ink on every day: the muted grey failed contrast at this size
              // on the paper and on the weekend tint. Today is the bold one.
              style: T
                  .chip(selected ? C.onMark : C.ink)
                  .copyWith(
                    letterSpacing: 0,
                    fontWeight: _isToday ? FontWeight.w700 : FontWeight.w400,
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
        message:
            '${bucket.length} due ${longDate(iso)}\n'
            '${bucket.map((a) => '· ${a.title}').join('\n')}',
        child: column,
      ),
    );
  }

  /// [faded] knocks the fill back rather than the whole bar, so a count on
  /// it can switch to ink and stay readable on the paler block.
  Widget _bar({bool faded = false}) {
    // 10px for the first, 7px per additional, capped so a brutal week does
    // not blow out the strip's height. Steps big enough to read as one, two
    // and three at a glance, and a short bar still leaves air above it.
    final height = math.min(26, 10 + (bucket.length - 1) * 7).toDouble();
    final full = urgency(daysAway);
    final colour = faded ? full.withValues(alpha: .3) : full;

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
              style: T.flabel.copyWith(
                color: faded ? C.ink : C.onInk,
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
