import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// The signature element: 14 columns for the next 14 days, one per day.
///
/// A day with deadlines gets a filled block whose height grows with the number
/// due and whose colour comes from [urgency]. Empty days get a hairline. It
/// exists so a crunch week is visible before it arrives.
///
/// It deliberately always shows **all** subjects, whatever the active filter is:
/// the filter narrows the list, not the early warning.
class HorizonStrip extends StatelessWidget {
  const HorizonStrip({super.key, required this.active});

  final List<Assignment> active;

  static const _days = 14;
  static const _height = 46.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Next 14 days'.toUpperCase(), style: T.eyebrow()),
            Text('Today → +14'.toUpperCase(), style: T.eyebrow()),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: _height,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: C.ink)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 3,
            children: [
              for (var day = 0; day < _days; day++)
                Expanded(child: _Column(day: day, bucket: _bucket(day))),
            ],
          ),
        ),
      ],
    );
  }

  List<Assignment> _bucket(int day) =>
      active.where((a) => daysUntil(a.due) == day).toList();
}

class _Column extends StatelessWidget {
  const _Column({required this.day, required this.bucket});

  final int day;
  final List<Assignment> bucket;

  @override
  Widget build(BuildContext context) {
    if (bucket.isEmpty) {
      return Opacity(
        opacity: .55,
        child: Container(height: 4, color: C.rule),
      );
    }
    return Tooltip(
      message:
          '${bucket.length} due ${longDate(bucket.first.due)}\n'
          '${bucket.map((a) => '· ${a.title}').join('\n')}',
      child: Container(
        // 12px for the first, 9px per additional, capped so a brutal week does
        // not blow out the strip's height.
        height: math.min(40, 12 + (bucket.length - 1) * 9).toDouble(),
        color: urgency(day),
      ),
    );
  }
}
