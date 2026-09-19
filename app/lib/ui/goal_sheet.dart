import 'package:flutter/material.dart';

import '../bands.dart';
import '../models.dart';
import '../theme.dart';
import 'atoms.dart';

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

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: C.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    insetPadding: const EdgeInsets.all(20),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: C.mark, width: 3)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow('Goal for ${widget.subjectName}'),

            if (widget.bands.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  // Highest first: a goal is something to reach up to.
                  for (final b in widget.bands.reversed)
                    Tap(
                      onTap: () => _pick(b.min),
                      semanticLabel:
                          'Aim for ${b.name}, '
                          '${trimBound(b.min)} percent',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: _value == b.min ? C.mark : Colors.transparent,
                          border: Border.all(
                            color: _value == b.min ? C.ink : C.rule,
                          ),
                        ),
                        child: Text(
                          '${b.name} ${trimBound(b.min)}%'.toUpperCase(),
                          style: T.chip(_value == b.min ? C.onMark : C.muted),
                        ),
                      ),
                    ),
                ],
              ),
            ],

            const SizedBox(height: 12),
            SizedBox(
              width: 120,
              child: LabelledField(
                label: 'Target',
                child: NumberField(
                  controller: _field,
                  suffix: '%',
                  hint: '75',
                  semanticLabel: 'Target percentage',
                  onChanged: (v) => setState(() => _value = v),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: 8,
              children: [
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
                Opacity(
                  opacity: _value == null ? .4 : 1,
                  child: Tap(
                    onTap: _value == null
                        ? null
                        : () => Navigator.of(context).pop(GoalChoice(_value)),
                    semanticLabel: 'Save the goal',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
                      ),
                      color: C.ink,
                      child: Text('SAVE', style: T.ghost(C.onInk)),
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
