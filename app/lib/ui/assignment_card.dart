import 'package:flutter/material.dart';

import '../bands.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'atoms.dart';
import 'edit_sheet.dart';

/// One assignment. Collapsed it shows subject, countdown, title and task
/// progress; expanded it reveals the tasks and the actions.
///
/// The left spine's colour is the urgency channel and the dot beside the
/// subject name is the subject channel. They carry different information and
/// must stay separate.
class AssignmentCard extends StatefulWidget {
  const AssignmentCard({
    super.key,
    required this.assignment,
    required this.store,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final Assignment assignment;
  final AppStore store;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  State<AssignmentCard> createState() => _AssignmentCardState();
}

class _AssignmentCardState extends State<AssignmentCard> {
  final _taskController = TextEditingController();
  final _taskFocus = FocusNode();
  final _subtaskController = TextEditingController();
  final _subtaskFocus = FocusNode();

  /// Marks fields, keyed by task id. See [_pointsControllerFor].
  final _pointsControllers = <String, TextEditingController>{};

  /// Which task has its steps showing. One at a time, so the card cannot grow
  /// unbounded while it is open.
  String? _openTaskId;

  @override
  void dispose() {
    _taskController.dispose();
    _taskFocus.dispose();
    _subtaskController.dispose();
    _subtaskFocus.dispose();
    for (final c in _pointsControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _pushTask() {
    final text = _taskController.text.trim();
    if (text.isEmpty) return;
    widget.store.addTask(widget.assignment, text);
    _taskController.clear();
    // Keep focus so several tasks can be typed in a row.
    _taskFocus.requestFocus();
  }

  /// One task, and its steps when it is open.
  ///
  /// Steps stay hidden until the task is tapped. The card is already the
  /// densest thing on a phone screen, and showing every step of every task at
  /// once turns a five-line list into thirty.
  Widget _taskRow(Assignment a, AppStore store, Task t) {
    final open = _openTaskId == t.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            spacing: 10,
            children: [
              CheckBoxSquare(done: t.done, onTap: () => store.toggleTask(a, t)),
              Expanded(
                child: Tap(
                  onTap: () => setState(() => _openTaskId = open ? null : t.id),
                  semanticLabel: t.hasSubtasks
                      ? '${t.text}, ${t.finishedSubtasks} of '
                            '${t.subtasks.length} steps done, tap to '
                            '${open ? 'collapse' : 'expand'}'
                      : '${t.text}, tap to add steps',
                  child: Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: Text(t.text, style: T.task(done: t.done)),
                      ),
                      // `pt`, not `m` — `5m` beside `45m` would read as two
                      // durations rather than marks and time.
                      if (t.points != null)
                        Text('${trimNumber(t.points!)}pt', style: T.frac),
                      if (t.minutes != null)
                        Text(formatMinutes(t.minutes!), style: T.frac),
                      if (t.hasSubtasks)
                        Text(
                          '${t.finishedSubtasks}/${t.subtasks.length}',
                          style: T.frac,
                        ),
                      Icon(
                        open ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: open ? C.ink : C.muted,
                      ),
                    ],
                  ),
                ),
              ),
              Tap(
                onTap: () => store.deleteTask(a, t),
                semanticLabel: 'Remove task ${t.text}',
                child: Padding(
                  padding: EdgeInsets.all(3),
                  child: CloseGlyph(color: C.rule, size: 16),
                ),
              ),
            ],
          ),
        ),
        if (open) _steps(store, t),
      ],
    );
  }

  /// Steps sit under their task, indented to the depth of its checkbox so the
  /// nesting is legible without a connecting line. The task's own marks and
  /// estimate live here too — opening a task is how you get at its detail,
  /// rather than putting six more controls on every collapsed row.
  ///
  /// The detail hangs off a rail dropped from the task's checkbox, so
  /// everything inside it, its own add row included, reads as one level down
  /// from the task rather than as more of the card.
  Widget _steps(AppStore store, Task t) => Container(
    margin: const EdgeInsets.only(left: 9, top: 2, bottom: 8),
    padding: const EdgeInsets.only(left: 19, top: 2, bottom: 2),
    decoration: BoxDecoration(
      border: Border(left: BorderSide(color: C.rule, width: 2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _taskMeta(store, t),
        for (final s in t.subtasks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              spacing: 10,
              children: [
                CheckBoxSquare(
                  done: s.done,
                  onTap: () => store.toggleSubtask(s),
                ),
                Expanded(
                  child: Text(
                    s.text,
                    style: T.task(done: s.done).copyWith(fontSize: 13),
                  ),
                ),
                Tap(
                  onTap: () => store.deleteSubtask(t, s),
                  semanticLabel: 'Remove step ${s.text}',
                  child: Padding(
                    padding: EdgeInsets.all(3),
                    child: CloseGlyph(color: C.rule, size: 14),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _AddRow(
            controller: _subtaskController,
            focusNode: _subtaskFocus,
            hint: 'Add a step',
            buttonLabel: 'Add step',
            small: true,
            onSubmit: () => _pushSubtask(t),
          ),
        ),
      ],
    ),
  );

  /// The open task's rubric marks and effort estimate.
  ///
  /// The estimate is a row of preset chips rather than a free number field: a
  /// student guessing to the minute is inventing precision, and the rough shape
  /// of the work is all this is for. One tap sets it, tapping the active one
  /// clears it.
  ///
  /// Label and control share a line, with the labels in one column, so the
  /// two read as a small form rather than four loose rows. The time chips are
  /// the list filter chips' language: hairline box, and the active one gets
  /// an ink edge with the highlighter underline.
  Widget _taskMeta(AppStore store, Task t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        Row(
          children: [
            SizedBox(width: 50, child: Text('MARKS', style: T.count(C.muted))),
            SizedBox(
              width: 62,
              child: NumberField(
                controller: _pointsControllerFor(t),
                hint: '5',
                semanticLabel: 'Marks for ${t.text}',
                onChanged: (v) => store.setTaskPoints(t, v),
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 50, child: Text('TIME', style: T.count(C.muted))),
            Expanded(
              child: Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (final m in kEstimateChoices)
                    _EstimateChip(
                      label: formatMinutes(m),
                      on: t.minutes == m,
                      semanticLabel: t.minutes == m
                          ? 'Clear the ${formatMinutes(m)} estimate'
                          : 'Estimate ${formatMinutes(m)}',
                      onTap: () =>
                          store.setTaskMinutes(t, t.minutes == m ? null : m),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );

  /// One controller per task, kept alive across rebuilds so typing a mark does
  /// not reset the cursor on every keystroke.
  TextEditingController _pointsControllerFor(Task t) =>
      _pointsControllers.putIfAbsent(
        t.id,
        () => TextEditingController(
          text: t.points == null ? '' : trimNumber(t.points!),
        ),
      );

  void _pushSubtask(Task t) {
    final text = _subtaskController.text.trim();
    if (text.isEmpty) return;
    widget.store.addSubtask(t, text);
    _subtaskController.clear();
    // Keep focus so several steps can be typed in a row, as with tasks.
    _subtaskFocus.requestFocus();
  }

  /// The letter for a score, or nothing at all when letter grading is off.
  Widget? _bandLabel(AppStore store, double fraction) {
    final band = bandFor(fraction * 100, store.bands);
    if (band == null) return null;
    return Text(band.name.toUpperCase(), style: T.eyebrow(C.ink));
  }

  Future<void> _confirmDelete() async {
    final a = widget.assignment;
    await showDialog<void>(
      context: context,
      builder: (context) => _Dialog(
        title: 'Delete this assignment?',
        body: '“${a.title}” and its tasks will be gone. This cannot be undone.',
        confirmLabel: 'Delete',
        destructive: true,
        onConfirm: () => widget.store.deleteAssignment(a),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assignment;
    final store = widget.store;
    final n = daysUntil(a.due);
    final spine = a.done ? C.green : urgency(n);
    final subject = store.subjectOf(a);
    final total = a.tasks.length;
    final finished = a.finishedTasks;

    // Submitted work used to be washed out to 62% and struck through, which
    // read as disabled or deleted. The green spine and the label say "done";
    // the title steps back to muted and stays readable.
    return Container(
      decoration: BoxDecoration(
        color: C.card,
        border: Border(left: BorderSide(color: spine, width: 6)),
        boxShadow: const [
          BoxShadow(color: Color(0x1A16202E), offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: widget.expanded,
            label:
                '${a.title}, ${subject?.name ?? 'unfiled'}, '
                '${a.done ? 'submitted' : countdown(n).toLowerCase()}',
            child: ExcludeSemantics(
              child: Tap(
                onTap: widget.onToggleExpanded,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              spacing: 6,
                              children: [
                                if (subject != null) Dot(subject.swatch),
                                Flexible(
                                  child: Eyebrow(
                                    subject?.name ?? 'Unfiled',
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (a.done)
                            Row(
                              spacing: 4,
                              children: [
                                Icon(Icons.check, size: 14, color: C.green),
                                Text('SUBMITTED', style: T.count(C.ink)),
                              ],
                            )
                          else
                            Text(countdown(n), style: T.count(spine)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        a.title,
                        style: a.done
                            ? T.title().copyWith(color: C.muted)
                            : T.title(),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        spacing: 9,
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 3,
                              child: Stack(
                                children: [
                                  Container(color: C.rule),
                                  FractionallySizedBox(
                                    widthFactor: total == 0
                                        ? 0
                                        : finished / total,
                                    child: Container(color: spine),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Text(
                            total == 0 ? 'no tasks' : '$finished/$total',
                            style: T.frac,
                          ),
                          // A hairline keeps the two fractions from reading
                          // as one: 1/2 is tasks done, 30/40 is marks.
                          Container(width: 1, height: 11, color: C.rule),
                          Text(
                            a.markLabel,
                            style: T.frac.copyWith(
                              // Ink once a real result is in, so a graded
                              // card is distinguishable at a glance from one
                              // still showing placeholders.
                              color: a.graded ? C.ink : C.muted,
                            ),
                          ),
                          // The band, when one is configured and there is a
                          // score for it to land in.
                          if (a.graded) ?_bandLabel(store, a.scored!),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.expanded) _body(a, store),
        ],
      ),
    );
  }

  Widget _body(Assignment a, AppStore store) => Padding(
    padding: const EdgeInsets.only(left: 14, right: 14, bottom: 13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The due date and the subject share one line. The subject is a
        // setting of the card, not a form to fill in, so it is an underlined
        // inline picker rather than a full-width boxed field.
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 6),
          child: Row(
            children: [
              Expanded(child: Eyebrow(longDate(a.due))),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  label: 'Change subject',
                  child: DropdownButtonFormField<String>(
                    initialValue: a.subjectId ?? '',
                    isExpanded: true,
                    isDense: true,
                    icon: Icon(Icons.arrow_drop_down, color: C.ink, size: 20),
                    dropdownColor: C.card,
                    borderRadius: BorderRadius.zero,
                    style: T.body.copyWith(color: C.ink),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.only(top: 4, bottom: 5),
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(color: C.rule),
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: C.rule),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: C.ink, width: 2),
                      ),
                    ),
                    onChanged: (v) => store.setSubject(
                      a,
                      (v == null || v.isEmpty) ? null : v,
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Unfiled')),
                      for (final s in store.subjects)
                        DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        for (final t in a.tasks) _taskRow(a, store, t),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: _AddRow(
            controller: _taskController,
            focusNode: _taskFocus,
            hint: 'Add a task',
            buttonLabel: 'Add task',
            onSubmit: _pushTask,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  GhostButton(
                    label: a.done ? 'Reopen' : 'Mark submitted',
                    filled: !a.done,
                    onPressed: () => store.toggleSubmitted(a),
                  ),
                  GhostButton(
                    label: 'Edit',
                    onPressed: () => showEditSheet(context, store, a),
                  ),
                ],
              ),
            ),
            Tap(
              onTap: _confirmDelete,
              semanticLabel: 'Delete assignment',
              child: Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.delete_outline, size: 19, color: C.muted),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// A text field with its add button, one per level: [small] for steps inside
/// an open task, full size for tasks on the card.
///
/// The button is outlined in ink, the ghost button's look, rather than a
/// filled ink block: filled ink turns into a pale slab after dark, and two of
/// them stacked read as two primary actions competing.
class _AddRow extends StatelessWidget {
  const _AddRow({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.buttonLabel,
    required this.onSubmit,
    this.small = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;

  /// Spoken label for the button.
  final String buttonLabel;
  final VoidCallback onSubmit;
  final bool small;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            style: T.body,
            decoration: fieldDecoration(hint: hint).copyWith(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: small ? 8 : 10,
              ),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        Tap(
          onTap: onSubmit,
          semanticLabel: buttonLabel,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: small ? 9 : 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: small ? C.muted : C.ink, width: 1.5),
            ),
            child: Text(
              small ? 'ADD STEP' : 'ADD',
              style: small ? T.chip(C.ink) : T.ghost(C.ink),
            ),
          ),
        ),
      ],
    ),
  );
}

/// An effort preset in an open task, drawn like the list's filter chips.
class _EstimateChip extends StatelessWidget {
  const _EstimateChip({
    required this.label,
    required this.on,
    required this.onTap,
    required this.semanticLabel,
  });

  final String label;
  final bool on;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Tap(
    onTap: onTap,
    semanticLabel: semanticLabel,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: C.card,
        border: Border.all(color: on ? C.ink : C.rule),
      ),
      child: Container(
        decoration: on
            ? BoxDecoration(
                border: Border(bottom: BorderSide(color: C.mark, width: 2)),
              )
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        // Not uppercased: 15M would read as months.
        child: Text(label, style: T.chip(on ? C.ink : C.muted)),
      ),
    ),
  );
}

/// A square-cornered confirm dialog, since Material's rounded default fights
/// the rest of the design.
class _Dialog extends StatelessWidget {
  const _Dialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.onConfirm,
    this.destructive = false,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final VoidCallback onConfirm;
  final bool destructive;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: C.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: T.emptyHead),
          const SizedBox(height: 8),
          Text(body, style: T.emptyBody),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: 8,
            children: [
              GhostButton(
                label: 'Cancel',
                onPressed: () => Navigator.of(context).pop(),
              ),
              Tap(
                onTap: () {
                  onConfirm();
                  Navigator.of(context).pop();
                },
                semanticLabel: confirmLabel,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 9,
                  ),
                  color: destructive ? C.red : C.ink,
                  child: Text(
                    confirmLabel.toUpperCase(),
                    style: T.ghost(C.onInk),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Shared confirm helper for destructive actions elsewhere in the app.
Future<void> confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required VoidCallback onConfirm,
  bool destructive = true,
}) => showDialog<void>(
  context: context,
  builder: (context) => _Dialog(
    title: title,
    body: body,
    confirmLabel: confirmLabel,
    destructive: destructive,
    onConfirm: onConfirm,
  ),
);
