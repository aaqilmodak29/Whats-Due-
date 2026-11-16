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
  ///
  /// [index] is its place in the reorderable list, or null when it is the
  /// only task and there is nothing to reorder (and so no handle).
  Widget _taskRow(Assignment a, AppStore store, Task t, int? index) {
    final open = _openTaskId == t.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            spacing: 10,
            children: [
              if (index != null) _DragHandle(index: index, label: t.text),
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
                  // Muted, not rule: a hairline-grey X read as disabled.
                  child: CloseGlyph(size: 15),
                ),
              ),
            ],
          ),
        ),
        if (open) _steps(store, t, handled: index != null),
      ],
    );
  }

  /// Steps sit under their task, hung off a rail dropped from its checkbox, so
  /// everything inside — the task's marks and estimate, its steps, the inline
  /// field for another — reads as one level down from the task rather than as
  /// more of the card.
  ///
  /// The step field is deliberately not a second copy of the task field: no
  /// box and no word button, just a `+` where a checkbox would be, so the two
  /// adds read as two different levels.
  Widget _steps(AppStore store, Task t, {required bool handled}) => Container(
    // Under the checkbox, which sits past the drag handle when there is one.
    margin: EdgeInsets.only(left: handled ? 35 : 9, top: 2, bottom: 8),
    padding: const EdgeInsets.only(left: 14, top: 2, bottom: 2),
    decoration: BoxDecoration(
      border: Border(left: BorderSide(color: C.rule, width: 2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _taskMeta(store, t),
        _Reorderable(
          onReorder: (from, to) => store.moveSubtask(t, from, to),
          children: [
            for (final (i, s) in t.subtasks.indexed)
              Padding(
                key: ValueKey(s.id),
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  spacing: 10,
                  children: [
                    if (t.subtasks.length > 1)
                      _DragHandle(index: i, label: 'step ${s.text}'),
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
                        child: CloseGlyph(size: 14),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        _StepField(
          controller: _subtaskController,
          focusNode: _subtaskFocus,
          indent: t.subtasks.length > 1,
          onSubmit: () => _pushSubtask(t),
        ),
      ],
    ),
  );

  /// The open task's rubric marks and effort estimate, on one line where the
  /// width allows.
  ///
  /// The estimate is a row of preset chips rather than a free number field: a
  /// student guessing to the minute is inventing precision, and the rough shape
  /// of the work is all this is for. One tap sets it, tapping the active one
  /// clears it.
  Widget _taskMeta(AppStore store, Task t) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    // Labelled like every other form in the app: the label above, the
    // standard field under MARKS and the list's own plain-word choices under
    // TIME, so neither reads as a one-off control.
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        SizedBox(
          width: 60,
          child: LabelledField(
            label: 'Marks',
            child: NumberField(
              controller: _pointsControllerFor(t),
              hint: '–',
              semanticLabel: 'Marks for ${t.text}',
              onChanged: (v) => store.setTaskPoints(t, v),
            ),
          ),
        ),
        Expanded(
          child: LabelledField(
            label: 'Time',
            child: ConstrainedBox(
              // The field's height, so the choices sit level with it.
              constraints: const BoxConstraints(minHeight: 40),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 2,
                  runSpacing: 2,
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
            ),
          ),
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

  /// The letter for a score, or null when letter grading is off.
  String? _band(AppStore store, double fraction) =>
      bandFor(fraction * 100, store.bands)?.name;

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
    final open = widget.expanded;

    // Submitted work used to be washed out and struck through, then muted,
    // which still read as disabled. The green spine and the SUBMITTED label
    // say "done"; the title stays ink and fully readable.
    //
    // An open card takes an ink outline on its other three sides, so it reads
    // as the one thing being worked on rather than one more card in the list.
    return Container(
      decoration: BoxDecoration(
        color: C.card,
        border: Border(
          left: BorderSide(color: spine, width: 6),
          top: BorderSide(color: open ? C.ink : Colors.transparent),
          right: BorderSide(color: open ? C.ink : Colors.transparent),
          bottom: BorderSide(color: open ? C.ink : Colors.transparent),
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x1A16202E), offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: open,
            label:
                '${a.title}, ${subject?.name ?? 'unfiled'}, '
                '${a.done ? 'submitted' : countdown(n).toLowerCase()}',
            child: ExcludeSemantics(
              child: Tap(
                onTap: widget.onToggleExpanded,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
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
                      const SizedBox(height: 3),
                      // The mark rides beside the title rather than on a line
                      // of its own: a card is three short lines, not four, and
                      // the list shows a whole card more. It carries its own
                      // label, so -/- reads as a mark not yet in rather than
                      // as code. Task progress is the bar on the bottom edge;
                      // its count is in the open card, beside the tasks.
                      Row(
                        spacing: 12,
                        children: [
                          Expanded(child: Text(a.title, style: T.title())),
                          _Stat(
                            value: a.markLabel,
                            label: 'Mark',
                            // Ink once a real result is in, so a graded card
                            // is distinguishable at a glance from one still
                            // showing placeholders.
                            strong: a.graded,
                            // The band, when one is configured and there is a
                            // score for it to land in.
                            band: a.graded ? _band(store, a.scored!) : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Task progress as the card's bottom edge, in the urgency colour.
          // Only when there are tasks: an empty track says nothing.
          if (total > 0)
            SizedBox(
              height: 3,
              child: Stack(
                children: [
                  Container(color: C.rule),
                  FractionallySizedBox(
                    widthFactor: finished / total,
                    child: Container(color: spine),
                  ),
                ],
              ),
            ),
          if (open) _body(a, store),
        ],
      ),
    );
  }

  /// The open card: when and what subject, the tasks, one add field, and one
  /// row of actions with a single primary. Everything but the primary is a
  /// word or an icon, not another box.
  Widget _body(Assignment a, AppStore store) => Padding(
    padding: const EdgeInsets.only(left: 14, right: 14, bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (a.tasks.isEmpty) Container(height: 1, color: C.rule),
        // The due date and the subject share one line, each under its own
        // label so the pair reads as two facts about the card. The subject is
        // a setting of the card, not a form to fill in, so it is an underlined
        // inline picker rather than a full-width boxed field.
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 8),
          // Top-aligned, so the three labels share one line whatever the
          // height of what sits under them.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Expanded(
                flex: 5,
                child: LabelledField(
                  label: 'Due',
                  child: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    // Semibold: thin 10px mono fails contrast even in ink.
                    child: Text(
                      longDate(a.due).toUpperCase(),
                      style: T.count(C.ink),
                    ),
                  ),
                ),
              ),
              if (a.tasks.isNotEmpty)
                LabelledField(
                  label: 'Tasks',
                  child: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      '${a.finishedTasks}/${a.tasks.length}',
                      style: T.count(C.ink),
                    ),
                  ),
                ),
              Expanded(
                flex: 6,
                child: LabelledField(
                  label: 'Subject',
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
                        contentPadding: const EdgeInsets.only(top: 2, bottom: 5),
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
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Unfiled'),
                        ),
                        for (final s in store.subjects)
                          DropdownMenuItem(value: s.id, child: Text(s.name)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _Reorderable(
          onReorder: (from, to) => store.moveTask(a, from, to),
          children: [
            for (final (i, t) in a.tasks.indexed)
              KeyedSubtree(
                key: ValueKey(t.id),
                child: _taskRow(a, store, t, a.tasks.length > 1 ? i : null),
              ),
          ],
        ),
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
          children: [
            GhostButton(
              label: a.done ? 'Reopen' : 'Mark submitted',
              filled: !a.done,
              onPressed: () => store.toggleSubmitted(a),
            ),
            const Spacer(),
            Tap(
              onTap: () => showEditSheet(context, store, a),
              semanticLabel: 'Edit',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Text('EDIT', style: T.ghost(C.ink)),
              ),
            ),
            Tap(
              onTap: _confirmDelete,
              semanticLabel: 'Delete assignment',
              child: Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.delete_outline, size: 19, color: C.ink),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// The mark on a collapsed card, led by the small word for what it is —
/// `MARK -/-` rather than a bare `-/-` — or, once it is graded, followed by
/// the band it lands in.
class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    this.strong = false,
    this.band,
  });

  final String value;
  final String label;

  /// Ink for a real figure, muted for a placeholder still waiting on one.
  final bool strong;

  /// The grade band a mark lands in, named in place of the plain label.
  final String? band;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    spacing: 5,
    children: [
      if (band == null) Text(label.toUpperCase(), style: T.flabel),
      Text(value, style: strong ? T.count(C.ink) : T.frac),
      if (band != null) Text(band!.toUpperCase(), style: T.eyebrow(C.ink)),
    ],
  );
}

/// A short list whose items can be dragged into a new order by a
/// [_DragHandle]. Sized to its content inside the page's own scroll view.
///
/// [onReorder] gets the index the item ends up at, not Flutter's
/// before-removal index, so the store never has to know about that quirk.
class _Reorderable extends StatelessWidget {
  const _Reorderable({required this.onReorder, required this.children});

  final void Function(int from, int to) onReorder;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ReorderableListView(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: EdgeInsets.zero,
    // The handle starts a drag, not a long press anywhere on the row: rows
    // are full of tap targets already.
    buildDefaultDragHandles: false,
    onReorder: (from, to) => onReorder(from, to > from ? to - 1 : to),
    // Lifted on the card colour with a hairline, rather than Material's
    // default elevation slab.
    proxyDecorator: (child, _, _) => Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: C.card,
          border: Border.all(color: C.ink),
        ),
        child: child,
      ),
    ),
    children: children,
  );
}

/// The grip that starts a drag. Quiet — muted, and only there when there are
/// at least two things to put in order — but always visible, and named for
/// screen readers, which also get the list's move up and down actions.
class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.index, required this.label});

  final int index;
  final String label;

  @override
  Widget build(BuildContext context) => ReorderableDragStartListener(
    index: index,
    child: Semantics(
      container: true,
      label: 'Drag to reorder $label',
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: SizedBox(
          width: 16,
          height: 24,
          child: Icon(Icons.drag_indicator, size: 16, color: C.muted),
        ),
      ),
    ),
  );
}

/// The task field and its add button. The button is a word, not a box: the
/// card's one boxed button is its primary action.
class _AddRow extends StatelessWidget {
  const _AddRow({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.buttonLabel,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;

  /// Spoken label for the button.
  final String buttonLabel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 4,
    children: [
      Expanded(
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          style: T.body,
          decoration: fieldDecoration(hint: hint).copyWith(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 9,
            ),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
        ),
      ),
      Tap(
        onTap: onSubmit,
        semanticLabel: buttonLabel,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Text('ADD', style: T.ghost(C.ink)),
        ),
      ),
    ],
  );
}

/// The step field, inline in the open task: a `+` in the checkbox column and
/// an unboxed field that only shows its underline while it has focus.
class _StepField extends StatelessWidget {
  const _StepField({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.indent,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  /// Lines the `+` up with the checkboxes when the steps carry handles.
  final bool indent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: indent ? 26 : 0, top: 2),
    child: Row(
      spacing: 10,
      children: [
        Tap(
          onTap: onSubmit,
          semanticLabel: 'Add step',
          child: SizedBox(
            width: 19,
            height: 19,
            child: Icon(Icons.add, size: 17, color: C.ink),
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            style: T.body.copyWith(height: 1.2),
            decoration: InputDecoration(
              hintText: 'Add a step',
              hintStyle: T.body.copyWith(color: C.muted, height: 1.2),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: C.ink),
              ),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
          ),
        ),
      ],
    ),
  );
}

/// An effort preset in an open task. Off is a plain word; on is filled ink —
/// exactly the list's due-window filters, so the chosen estimate is
/// unmistakable and nothing here is a style of its own.
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
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      color: on ? C.ink : null,
      // Not uppercased: 15M would read as months.
      child: Text(label, style: T.chip(on ? C.onInk : C.ink)),
    ),
  );
}

/// A square-cornered confirm, anchored to the bottom like the edit sheet,
/// since Material's rounded, floating default fights the rest of the design.
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
  Widget build(BuildContext context) => SheetDialog(
    // Red for a confirm that destroys something, so the edge says what kind
    // of question this is before the words do.
    edge: destructive ? C.red : C.ink,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The card's title type: a question about one assignment reads in the
        // same voice as the assignment itself.
        Text(title, style: T.title()),
        const SizedBox(height: 6),
        Text(body, style: T.emptyBody.copyWith(color: C.ink)),
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
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
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
