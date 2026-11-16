import 'package:flutter/material.dart';

import '../bands.dart';
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

  late final _earned = _numberController(widget.assignment.earned);
  late final _goal = _numberController(widget.assignment.goal);
  late final _outOf = _numberController(widget.assignment.outOf);

  late double? _earnedValue = widget.assignment.earned;
  late double? _goalValue = widget.assignment.goal;
  late double? _outOfValue = widget.assignment.outOf;

  /// Seeded with the trimmed form, so an assignment worth 20% opens showing
  /// `20` rather than `20.0`.
  TextEditingController _numberController(double? v) =>
      TextEditingController(text: v == null ? '' : trimNumber(v));

  @override
  void dispose() {
    _title.dispose();
    _earned.dispose();
    _goal.dispose();
    _outOf.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    widget.store.editAssignment(widget.assignment, title: title, due: _due);
    widget.store.setMarks(
      widget.assignment,
      earned: _earnedValue,
      outOf: _outOfValue,
    );
    widget.store.setGoal(widget.assignment, _goalValue);
    Navigator.of(context).pop();
  }

  /// Says what the two numbers currently mean, so a half-filled pair does not
  /// look like a recorded result.
  String _marksNote() {
    final marks = _outOfValue;
    final score = _earnedValue;

    if (score != null && marks != null && score > marks) {
      return '${trimNumber(score)} is more than the ${trimNumber(marks)} marks '
          'available. It still counts; check the numbers.';
    }
    if (marks == null && score == null) {
      return 'Counts towards Grades once both marks and score are in.';
    }
    if (score == null) {
      return 'Out of ${trimNumber(marks!)}. Add your score when it comes back.';
    }
    if (marks == null) {
      return 'Add the marks it is out of to read the score as a percentage.';
    }
    final fraction = score / marks;
    final band = bandFor(fraction * 100, widget.store.bands);
    final goalNote = _goalValue == null
        ? ''
        : score + 1e-9 >= _goalValue!
        ? ' Goal of ${trimNumber(_goalValue!)} met.'
        : ' ${trimNumber(_goalValue! - score)} short of the '
              '${trimNumber(_goalValue!)} you wanted.';
    return 'Scored ${formatPercent(fraction)} — ${trimNumber(score)} out of '
        '${trimNumber(marks)}'
        '${band == null ? '' : ', a ${band.name}'}.$goalNote';
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assignment;
    final subject = widget.store.subjectOf(a);
    final unchanged =
        _title.text.trim() == a.title &&
        _due == a.due &&
        _earnedValue == a.earned &&
        _outOfValue == a.outOf &&
        _goalValue == a.goal;

    final blocked = _title.text.trim().isEmpty || unchanged;

    return SheetDialog(
      edge: C.mark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The subject rides in the heading: it is changed on the card
          // itself, so here it is context rather than a field.
          Row(
            spacing: 6,
            children: [
              const Eyebrow('Edit assignment'),
              const Spacer(),
              if (subject != null) Dot(subject.swatch),
              Flexible(
                child: Eyebrow(
                  subject?.name ?? 'Unfiled',
                  color: C.ink,
                  maxLines: 1,
                ),
              ),
            ],
          ),
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
          const SizedBox(height: kFormGap),
          // The add panel's row: the date, then the numbers. Marks then
          // score: "out of 40, I got 34". Weighting used to sit in front of
          // these and has been removed for now, so what an assignment is
          // worth towards the subject is not tracked.
          // Exactly the add panel's row: the date at twice the width of each
          // number, every box the same height. Then the one field only an
          // existing assignment has, the score, with what the numbers add up
          // to beside it. Marks before score: "out of 40, I got 34".
          // Weighting used to sit here too and has been removed for now.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 8,
            children: [
              Expanded(
                flex: 2,
                child: DueDateField(
                  value: _due,
                  onChanged: (v) => setState(() => _due = v),
                ),
              ),
              Expanded(
                child: LabelledField(
                  label: 'Marks',
                  child: FormNumberField(
                    controller: _outOf,
                    hint: 'e.g. 40',
                    semanticLabel: 'Marks the assignment is out of',
                    onChanged: (v) => setState(() => _outOfValue = v),
                  ),
                ),
              ),
              Expanded(
                child: LabelledField(
                  label: 'Goal',
                  child: FormNumberField(
                    controller: _goal,
                    hint: 'e.g. 30',
                    semanticLabel: 'Goal score',
                    onChanged: (v) => setState(() => _goalValue = v),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: kFormGap),
          LayoutBuilder(
            builder: (context, box) {
              // One number's width, so the score lines up under the marks
              // column's grid rather than stretching.
              final unit = (box.maxWidth - 3 * 8) / 4;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: 12,
                children: [
                  SizedBox(
                    width: unit,
                    child: LabelledField(
                      label: 'Your score',
                      child: FormNumberField(
                        controller: _earned,
                        hint: 'e.g. 34',
                        semanticLabel: 'Your score',
                        onChanged: (v) => setState(() => _earnedValue = v),
                      ),
                    ),
                  ),
                  // Prose, so sans: the mono data face made two sentences of
                  // advice read as a dense log line.
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(_marksNote(), style: T.emptyBody),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 18),
          Row(
            spacing: 8,
            children: [
              // Says why Save is greyed out, rather than leaving a
              // disabled-looking button to explain itself.
              Expanded(
                child: blocked
                    ? Text(
                        _title.text.trim().isEmpty
                            ? 'NEEDS A TITLE'
                            : 'NOTHING CHANGED YET',
                        style: T.eyebrow(C.ink),
                      )
                    : const SizedBox.shrink(),
              ),
              GhostButton(
                label: 'Cancel',
                onPressed: () => Navigator.of(context).pop(),
              ),
              Opacity(
                opacity: blocked ? .4 : 1,
                child: Tap(
                  onTap: blocked ? null : _save,
                  semanticLabel: 'Save changes',
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
    );
  }
}

/// A modal anchored to the bottom edge, full width, with a 3px coloured top
/// rule — a bottom sheet in look, but still a [Dialog], so focus, the barrier
/// and the back gesture behave as every other modal in the app does.
///
/// A box floating mid-screen over a dimmed card had no edge to belong to;
/// pinned to the bottom it reads as the panel it is.
class SheetDialog extends StatelessWidget {
  const SheetDialog({super.key, required this.child, this.edge});

  final Widget child;

  /// The top rule: highlighter for a form, red for a destructive confirm.
  final Color? edge;

  @override
  Widget build(BuildContext context) => Dialog(
    alignment: Alignment.bottomCenter,
    insetPadding: EdgeInsets.zero,
    backgroundColor: C.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    child: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: edge ?? C.ink, width: 3)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            // The page column's width, so on a tablet the form does not
            // stretch edge to edge.
            constraints: const BoxConstraints(maxWidth: 588),
            child: child,
          ),
        ),
      ),
    ),
  );
}

/// Vertical gap between rows of fields, shared by the add panel and the edit
/// sheet so the two forms keep one rhythm.
const double kFormGap = 12;

/// The due date, used by both the add panel and the edit sheet: the picker
/// field under a DUE label, with the day it falls on beside the label in the
/// app's own `FRI 7 AUG` form. One place for the readable date, on the
/// label's line, rather than a second line under the field.
class DueDateField extends StatelessWidget {
  const DueDateField({super.key, required this.value, required this.onChanged});

  /// `YYYY-MM-DD`, or empty.
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    // longDate's weekday, day and month, without the year.
    final day = parseIsoDate(value) == null
        ? null
        : longDate(value).split(' ').take(3).join(' ').toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            spacing: 8,
            children: [
              Text('DUE', style: T.flabel),
              if (day != null)
                Flexible(
                  child: Text(
                    day,
                    style: T.flabel.copyWith(color: C.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
        DateField(value: value, onChanged: onChanged),
      ],
    );
  }
}

/// A number field for the add and edit forms: [NumberField]'s behaviour and
/// look, padded to the [DateField]'s height so the date and the numbers in
/// one row are one height of box.
class FormNumberField extends StatelessWidget {
  const FormNumberField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.semanticLabel,
    this.hint,
  });

  final TextEditingController controller;
  final ValueChanged<double?> onChanged;
  final String semanticLabel;
  final String? hint;

  @override
  Widget build(BuildContext context) => Semantics(
    textField: true,
    label: semanticLabel,
    child: ExcludeSemantics(
      child: TextField(
        controller: controller,
        style: T.monoInput,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: fieldDecoration(hint: hint, mono: true).copyWith(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 12.5,
          ),
        ),
        // As NumberField: empty or unreadable is null, which the store reads
        // as untracked; a negative number is not a mark.
        onChanged: (raw) {
          final text = raw.trim();
          if (text.isEmpty) return onChanged(null);
          final v = double.tryParse(text);
          onChanged(v == null || v < 0 ? null : v);
        },
      ),
    ),
  );
}
