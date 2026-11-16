import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'atoms.dart';

/// School work or General work: the top-level choice of which list the
/// Assignments page shows, and where new work goes.
///
/// Two halves of one outlined bar, the chosen one filled ink like an active
/// chip, so it reads as a switch between two places rather than a filter.
class SectionSwitch extends StatelessWidget {
  const SectionSwitch({
    super.key,
    required this.current,
    required this.onSelect,
  });

  final WorkSection current;
  final ValueChanged<WorkSection> onSelect;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(border: Border.all(color: C.ink)),
    child: Row(
      children: [
        for (final s in WorkSection.values)
          Expanded(
            child: Semantics(
              selected: s == current,
              child: Tap(
                onTap: () => onSelect(s),
                semanticLabel: s == current
                    ? '${s.label}, showing'
                    : 'Show ${s.label}',
                child: Container(
                  color: s == current ? C.ink : C.card,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  child: Text(
                    s.label.toUpperCase(),
                    style: T.chip(s == current ? C.onInk : C.ink),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
