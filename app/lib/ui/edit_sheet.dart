import 'package:flutter/material.dart';

import '../grades.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'atoms.dart';

/// Editing an assignment's title and due date after creation.
///
/// The web app could reassign an assignment's subject from its card but had no
/// way to change the title or the date — the most obvious gap in it. Subject
/// reassignment stays on the card where it already was; this covers the rest.
Future<void> showEditSheet(
  BuildContext context,
  AppStore store,
  Assignment assignment,
) => showDialog<void>(
  context: context,
  builder: (context) => _EditSheet(store: store, assignment: assignment),
);

class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.store, required this.assignment});

  final AppStore store;
  final Assignment assignment;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.assignment.title,
  );
  late String _due = widget.assignment.due;

  late final _weight = _numberController(widget.assignment.weight);
  late final _earned = _numberController(widget.assignment.earned);
  late final _outOf = _numberController(widget.assignment.outOf);

  late double? _weightValue = widget.assignment.weight;
  late double? _earnedValue = widget.assignment.earned;
  late double? _outOfValue = widget.assignment.outOf;

  /// Seeded with the trimmed form, so an assignment worth 20% opens showing
  /// `20` rather than `20.0`.
  TextEditingController _numberController(double? v) =>
      TextEditingController(text: v == null ? '' : trimNumber(v));

  @override
  void dispose() {
    _title.dispose();
    _weight.dispose();
    _earned.dispose();
    _outOf.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    widget.store.editAssignment(widget.assignment, title: title, due: _due);
    widget.store.setMarks(
      widget.assignment,
      weight: _weightValue,
      earned: _earnedValue,
      outOf: _outOfValue,
    );
    Navigator.of(context).pop();
  }

  /// Says what the three numbers currently add up to, so the difference between
  /// "worth 20% of the unit" and "scored 34 out of 40" stays obvious while they
  /// are being typed.
  String _marksNote() {
    final w = _weightValue;
    final marks = _outOfValue;
    final score = _earnedValue;

    if (score != null && marks != null && score > marks) {
      return 'A score of ${trimNumber(score)} is more than the '
          '${trimNumber(marks)} marks available. Grades will still count it, '
          'but check the numbers.';
    }

    final scored = (score != null && (marks ?? 0) > 0) ? score / marks! : null;
    if (w == null && scored == null) {
      return "Worth is this assignment's share of the whole subject. Leave it "
          'empty to keep the assignment out of Grades.';
    }
    if (scored == null) {
      return 'Worth ${trimNumber(w!)}% of the subject. Add your score when it '
          'comes back.';
    }
    if (w == null) {
      return 'Scored ${formatPercent(scored)}. Add a worth to count it towards '
          'the subject.';
    }
    return 'Scored ${formatPercent(scored)} — '
        '${trimNumber(w * scored)} of the ${trimNumber(w)}% it is worth.';
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assignment;
    final unchanged =
        _title.text.trim() == a.title &&
        _due == a.due &&
        _weightValue == a.weight &&
        _earnedValue == a.earned &&
        _outOfValue == a.outOf;

    return Dialog(
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
              const Eyebrow('Edit assignment'),
              const SizedBox(height: 12),
              LabelledField(
                label: 'Assignment',
                child: TextField(
                  controller: _title,
                  style: T.input,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: fieldDecoration(hint: 'e.g. Comparative essay'),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(height: 12),
              DateField(
                label: 'Due date',
                value: _due,
                onChanged: (v) => setState(() => _due = v),
              ),
              const SizedBox(height: 8),
              Text(
                _due.isEmpty
                    ? 'Leaving the date empty keeps this off the 14-day strip.'
                    : longDate(_due),
                style: T.note,
              ),

              const SizedBox(height: 14),
              // Worth, then marks, then score: the order you would say it out
              // loud — "worth 20% of the unit, out of 40, I got 34". The
              // previous labels were "Mark" and "Out of", which read as a pair
              // but gave no clue which box was which.
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: 10,
                children: [
                  Expanded(
                    child: LabelledField(
                      label: 'Worth',
                      child: NumberField(
                        controller: _weight,
                        suffix: '%',
                        hint: '20',
                        semanticLabel: 'Worth, as a percent of the unit',
                        onChanged: (v) => setState(() => _weightValue = v),
                      ),
                    ),
                  ),
                  Expanded(
                    child: LabelledField(
                      label: 'Marks',
                      child: NumberField(
                        controller: _outOf,
                        hint: '40',
                        semanticLabel: 'Marks the assignment is out of',
                        onChanged: (v) => setState(() => _outOfValue = v),
                      ),
                    ),
                  ),
                  Expanded(
                    child: LabelledField(
                      label: 'Your score',
                      child: NumberField(
                        controller: _earned,
                        hint: '34',
                        semanticLabel: 'Your score',
                        onChanged: (v) => setState(() => _earnedValue = v),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(_marksNote(), style: T.note),

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: 8,
                children: [
                  GhostButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Opacity(
                    opacity: _title.text.trim().isEmpty || unchanged ? .4 : 1,
                    child: Tap(
                      onTap: _title.text.trim().isEmpty || unchanged
                          ? null
                          : _save,
                      semanticLabel: 'Save changes',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 9,
                        ),
                        color: C.ink,
                        child: Text(
                          'SAVE',
                          style: T.ghost(C.onInk),
                        ),
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
}
