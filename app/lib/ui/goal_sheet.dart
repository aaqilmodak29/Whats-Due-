import 'package:flutter/material.dart';

import '../bands.dart';
import '../models.dart';
import '../theme.dart';
import 'atoms.dart';
import 'band_colours.dart';

/// What [showGoalSheet] came back with. Null [percent] clears the goal.
class GoalChoice {
  const GoalChoice(this.percent);
  final double? percent;
}

/// Picks a target for a whole subject.
///
/// The goal is stored as a percentage even though it is usually set by tapping
/// a band — the bands are shortcuts onto the same field, which is what lets
/// this work at all for anyone who has not set letter grading up.
Future<GoalChoice?> showGoalSheet(
  BuildContext context, {
  required String subjectName,
  required List<GradeBand> bands,
  required double? current,
}) => showDialog<GoalChoice>(
  context: context,
  builder: (context) =>
      _GoalSheet(subjectName: subjectName, bands: bands, current: current),
);

class _GoalSheet extends StatefulWidget {
  const _GoalSheet({
    required this.subjectName,
    required this.bands,
    required this.current,
  });

  final String subjectName;
  final List<GradeBand> bands;
  final double? current;

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late final _field = TextEditingController(
    text: widget.current == null ? '' : trimNumber(widget.current!),
  );
  late double? _value = widget.current;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _pick(double percent) {
    setState(() {
      _value = percent;
      _field.text = trimNumber(percent);
    });
  }

  /// Nothing to save: no target yet, or the one already set.
  bool get _unchanged => _value == null || _value == widget.current;

  /// One band as a choice: its colour as a rule down the left edge, the same
  /// colour it has on Grades, then its name and floor. Filled ink with a tick
  /// when it is the target in the field. Fixed height, so a row of them lines
  /// up with the target field beside them.
  Widget _chip(GradeBand b) {
    // Display only: a chip is lit when the field holds exactly its bound,
    // whether it got there by a tap or by typing.
    final on = _value != null && (_value! - b.min).abs() < 1e-9;
    final ink = on ? C.onInk : C.ink;
    return Tap(
      onTap: () => _pick(b.min),
      semanticLabel: 'Aim for ${b.name}, ${trimBound(b.min)} percent',
      child: Container(
        height: _cell,
        padding: const EdgeInsets.only(left: 9, right: 10),
        decoration: BoxDecoration(
          color: on ? C.ink : C.field,
          border: Border(
            left: BorderSide(color: colourOfBand(b, widget.bands), width: 4),
            top: BorderSide(color: on ? C.ink : C.rule),
            right: BorderSide(color: on ? C.ink : C.rule),
            bottom: BorderSide(color: on ? C.ink : C.rule),
          ),
        ),
        child: Row(
          spacing: 6,
          children: [
            Expanded(
              child: Text(
                b.name.toUpperCase(),
                style: T.chip(ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (on) Icon(Icons.check, size: 14, color: ink),
            Text(bandFloor(b), style: T.chip(ink)),
          ],
        ),
      ),
    );
  }

  /// What the goal is right now, before anything is picked: a sentence, so
  /// it cannot be mistaken for a button.
  String get _currentLine {
    final now = widget.current;
    if (now == null) return 'No goal set yet.';
    final band = widget.bands.isEmpty ? null : bandFor(now, widget.bands);
    final exact = band != null && (band.min - now).abs() < 1e-9;
    return exact
        ? 'Current goal: ${band.name}, ${bandFloor(band)}.'
        : 'Current goal: ${trimNumber(now)}%.';
  }

  static const _cell = 40.0;

  /// Any percentage, typed: the last cell of the grid, so the bands and the
  /// free figure read as one set of choices for the same number.
  Widget _target() => SizedBox(
    height: _cell,
    child: NumberField(
      controller: _field,
      hint: 'Other %',
      suffix: '%',
      semanticLabel: 'Target percentage',
      onChanged: (v) => setState(() => _value = v),
    ),
  );

  /// Two even columns, highest band first: a goal is something to reach up
  /// to. The target field takes the next free cell.
  Widget _grid() {
    final cells = [
      for (final b in widget.bands.reversed) _chip(b),
      _target(),
    ];
    return Column(
      spacing: 6,
      children: [
        for (var i = 0; i < cells.length; i += 2)
          Row(
            spacing: 6,
            children: [
              Expanded(child: cells[i]),
              Expanded(
                child: i + 1 < cells.length
                    ? cells[i + 1]
                    : const SizedBox.shrink(),
              ),
            ],
          ),
      ],
    );
  }

  /// Anchored to the bottom edge, full width, like the edit sheet — not a
  /// box floating over the middle of the page. A [Dialog] rather than a modal
  /// bottom sheet so it keeps the dialog's keyboard handling: it rides up with
  /// the keyboard while the target is typed.
  @override
  Widget build(BuildContext context) => Dialog(
    alignment: Alignment.bottomCenter,
    insetPadding: EdgeInsets.zero,
    backgroundColor: C.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    child: SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: C.ink, width: 3)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow('Goal for ${widget.subjectName}', color: C.ink),
            const SizedBox(height: 6),
            Text(_currentLine, style: T.body),
            Text(
              widget.bands.isEmpty
                  ? 'Type the percentage you are aiming for across the subject.'
                  : 'Pick a band, or type any percentage.',
              style: T.body,
            ),

            const SizedBox(height: 14),
            _grid(),

            const SizedBox(height: 18),
            Row(
              spacing: 8,
              children: [
                // Says why Save is greyed, in place of a silent dead button.
                Expanded(
                  child: _unchanged
                      ? Text(
                          _value == null
                              ? 'Pick a goal to save.'
                              : 'Same as now.',
                          style: T.emptyBody.copyWith(color: C.ink),
                        )
                      : const SizedBox.shrink(),
                ),
                if (widget.current != null)
                  GhostButton(
                    label: 'Clear',
                    onPressed: () =>
                        Navigator.of(context).pop(const GoalChoice(null)),
                  ),
                GhostButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Tap(
                  onTap: _unchanged
                      ? null
                      : () => Navigator.of(context).pop(GoalChoice(_value)),
                  semanticLabel: 'Save the goal',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 9.5,
                    ),
                    color: _unchanged ? C.rule : C.ink,
                    child: Text(
                      'SAVE',
                      style: T.ghost(_unchanged ? C.muted : C.onInk),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
