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
      return 'Counts in Grades once marked.';
    }
    if (score == null) {
      return 'Out of ${trimNumber(marks!)}. Add your score when it is back.';
    }
    if (marks == null) {
      return 'Add the marks it is out of for a percentage.';
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
          // Exactly the add panel's row: the date at twice the width of each
          // number, every box the shared field height. Then the one field
          // only an existing assignment has, the score, with what the numbers
          // add up to beside it. Marks before score: "out of 40, I got 34".
          // Weighting used to sit here too and has been removed for now.
          // The labels name the numbers, so the boxes carry no hint text.
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
                  child: NumberField(
                    controller: _outOf,
                    semanticLabel: 'Marks the assignment is out of',
                    onChanged: (v) => setState(() => _outOfValue = v),
                  ),
                ),
              ),
              Expanded(
                child: LabelledField(
                  label: 'Goal',
                  child: NumberField(
                    controller: _goal,
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
                      child: NumberField(
                        controller: _earned,
                        semanticLabel: 'Your score',
                        onChanged: (v) => setState(() => _earnedValue = v),
                      ),
                    ),
                  ),
                  // Prose, so sans: the mono data face made two sentences of
                  // advice read as a dense log line. Ink, short, and level
                  // with the box it explains.
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _marksNote(),
                        style: T.emptyBody.copyWith(color: C.ink),
                      ),
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
              // Greyed by its ground, not by fading it: a rule-grey slab with
              // the word still in ink, so it reads as unavailable and still
              // reads.
              Tap(
                onTap: blocked ? null : _save,
                semanticLabel: 'Save changes',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 9,
                  ),
                  color: blocked ? C.rule : C.ink,
                  child: Text('SAVE', style: T.ghost(blocked ? C.ink : C.onInk)),
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

/// The due date, used by both the add panel and the edit sheet: the shared
/// picker field under a plain DUE label. The field itself shows the date in
/// the app's `FRI 7 AUG` form, so the date appears once.
class DueDateField extends StatelessWidget {
  const DueDateField({super.key, required this.value, required this.onChanged});

  /// `YYYY-MM-DD`, or empty.
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => LabelledField(
    label: 'Due',
    child: DateField(value: value, onChanged: onChanged),
  );
}
