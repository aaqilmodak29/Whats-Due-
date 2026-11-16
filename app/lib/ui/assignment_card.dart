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
  ///
  /// Task rows keep their handle and remove whether or not a task is open:
  /// one rule for the row on every screen. The open task's steps are the
  /// lighter level under it (see [_steps]).
  Widget _taskRow(Assignment a, AppStore store, Task t, int? index) {
    final open = _openTaskId == t.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            spacing: _kRowGap,
            children: [
              if (index != null) _DragHandle(index: index, label: t.text),
              _Check(done: t.done, onTap: () => store.toggleTask(a, t)),
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
                        child: Text(t.text, style: _taskStyle(t.done)),
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
                          style: open ? T.count(C.ink) : T.frac,
                        ),
                    ],
                  ),
                ),
              ),
              _RowRemove(
                onTap: () => store.deleteTask(a, t),
                semanticLabel: 'Remove task ${t.text}',
              ),
            ],
          ),
        ),
        if (open) _steps(store, t, handled: index != null),
      ],
    );
  }

  /// Steps sit one level down from their task: hung off a hairline dropped
  /// from its checkbox, with a smaller box and tighter rows, but the task's
  /// grip and remove, so the card has one size of icon. No box around any of
  /// it.
  ///
  /// [handled] is whether the task rows carry grips, so the rail drops from
  /// the checkbox wherever it sits.
  ///
  /// The step field is deliberately not a second copy of the task field: no
  /// box and no word button, just a `+` where a checkbox would be, so the two
  /// adds read as two different levels.
  Widget _steps(AppStore store, Task t, {required bool handled}) {
    final stepHandles = t.subtasks.length > 1;
    return Container(
      // The rail drops from the task's checkbox centre; the steps start just
      // inside it.
      margin: EdgeInsets.only(
        left: (handled ? _kGrip + _kRowGap : 0) + _kCheck / 2,
        top: 2,
        bottom: 8,
      ),
      padding: const EdgeInsets.only(left: _kStepGap, bottom: 2),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: C.rule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 8),
            child: _taskMeta(store, t),
          ),
          _Reorderable(
            onReorder: (from, to) => store.moveSubtask(t, from, to),
            children: [
              for (final (i, s) in t.subtasks.indexed)
                Padding(
                  key: ValueKey(s.id),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    spacing: _kStepGap,
                    children: [
                      if (stepHandles)
                        _DragHandle(
                          index: i,
                          label: 'step ${s.text}',
                          size: _kStepGrip,
                        ),
                      _Check(
                        done: s.done,
                        size: _kStepCheck,
                        onTap: () => store.toggleSubtask(s),
                      ),
                      Expanded(
                        child: Text(s.text, style: _taskStyle(s.done)),
                      ),
                      _RowRemove(
                        onTap: () => store.deleteSubtask(t, s),
                        semanticLabel: 'Remove step ${s.text}',
                      ),
                    ],
                  ),
                ),
            ],
          ),
          _StepField(
            controller: _subtaskController,
            focusNode: _subtaskFocus,
            indent: stepHandles ? _kStepGrip + _kStepGap : 0,
            onSubmit: () => _pushSubtask(t),
          ),
        ],
      ),
    );
  }

  /// The open task's rubric marks and effort estimate: two small labelled
  /// boxes of one height side by side, so the pair reads as one row of a form
  /// and leaves the rail room to breathe.
  ///
  /// The estimate is a choice of presets rather than a free number field: a
  /// student guessing to the minute is inventing precision, and the rough shape
  /// of the work is all this is for. Its box opens the presets as a menu, like
  /// the list's due window; picking one sets it, picking the active one clears
  /// it.
  Widget _taskMeta(AppStore store, Task t) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 10,
    children: [
      SizedBox(
        width: _kMarksField,
        child: LabelledField(
          label: 'Marks',
          child: NumberField(
            controller: _pointsControllerFor(t),
            hint: 'e.g. 5',
            dense: true,
            semanticLabel: 'Marks for ${t.text}',
            onChanged: (v) => store.setTaskPoints(t, v),
          ),
        ),
      ),
      SizedBox(
        width: _kTimeField,
        child: LabelledField(
          label: 'Time',
          child: _EstimatePicker(
            minutes: t.minutes,
            task: t.text,
            onPick: (m) => store.setTaskMinutes(t, m),
          ),
        ),
      ),
    ],
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

  /// The mark slot's value: `30/40` once scored, `—/40` while only the marks
  /// available are known, and a lone `—` before either.
  String _markValue(Assignment a) {
    if (a.earned == null && a.outOf == null) return '—';
    String half(double? v) => v == null ? '—' : trimNumber(v);
    return '${half(a.earned)}/${half(a.outOf)}';
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
                  // Roomy enough that a short list reads as a few solid
                  // cards rather than thin strips on bare paper.
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                                  // Ink: muted letter-spaced caps this small
                                  // read as faint on the card.
                                  child: Eyebrow(
                                    subject?.name ?? 'Unfiled',
                                    color: C.ink,
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
                      // The mark rides beside the title rather than on a line
                      // of its own: a card is three short lines, not four.
                      // Every card, on every screen, has the same mark slot,
                      // so cards never differ by screen; a dash says "not
                      // in yet" plainly. Task progress is the bar on the
                      // bottom edge; its count is in the open card.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        spacing: 12,
                        children: [
                          Expanded(child: Text(a.title, style: T.title())),
                          _Stat(
                            value: _markValue(a),
                            label: 'Mark',
                            // Ink once a real result is in, so a graded card
                            // is distinguishable at a glance from one still
                            // waiting on it.
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
        // Three facts about the card on one line, each a label over a value
        // in the same mono data face, in three even columns with one rule
        // under the lot. Labels share a line and values share a baseline:
        // every value sits in the same fixed-height slot, the subject's
        // picker arrow included. The subject is the one that can change, so
        // it alone carries the arrow; it is not a boxed field of its own.
        Container(
          padding: const EdgeInsets.only(top: 10, bottom: 9),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: C.rule)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Expanded(
                flex: 4,
                child: _Fact(
                  label: 'Due',
                  // Semibold: thin 10px mono fails contrast even in ink.
                  // The app's date form, FRI 7 AUG, as on every other screen.
                  child: Text(
                    parseIsoDate(a.due) == null
                        ? longDate(a.due).toUpperCase()
                        : longDate(a.due).split(' ').take(3).join(' ')
                              .toUpperCase(),
                    style: T.count(C.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (a.tasks.isNotEmpty)
                Expanded(
                  flex: 2,
                  child: _Fact(
                    label: 'Tasks',
                    child: Text(
                      '${a.finishedTasks}/${a.tasks.length}',
                      style: T.count(C.ink),
                    ),
                  ),
                ),
              Expanded(
                flex: 6,
                child: _Fact(
                  label: 'Subject',
                  child: Semantics(
                    label: 'Change subject',
                    child: DropdownButtonFormField<String>(
                      initialValue: a.subjectId ?? '',
                      isExpanded: true,
                      isDense: true,
                      // No taller than the value's line, so the name sits on
                      // the same baseline as the date and the count.
                      iconSize: _kFactHeight,
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: C.ink,
                        size: _kFactHeight,
                      ),
                      dropdownColor: C.card,
                      borderRadius: BorderRadius.zero,
                      style: T.body.copyWith(color: C.ink),
                      // The chosen subject in the row's data face; the open
                      // menu keeps the names as written.
                      selectedItemBuilder: (context) => [
                        for (final name in [
                          'Unfiled',
                          for (final s in store.subjects) s.name,
                        ])
                          // The button sets its value a pixel lower than a
                          // plain line; lifted back onto the row's baseline.
                          Transform.translate(
                            offset: const Offset(0, -1),
                            child: Text(
                              name.toUpperCase(),
                              style: T.count(C.ink),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      decoration: const InputDecoration(
                        isDense: true,
                        isCollapsed: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
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
            if (a.done)
              GhostButton(
                label: 'Reopen',
                onPressed: () => store.toggleSubmitted(a),
              )
            else
              _SubmitButton(onPressed: () => store.toggleSubmitted(a)),
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

/// The open card's one primary, Mark submitted: the highlighter, but toned
/// down to sit inside a card full of quiet controls, with a 1px ink outline
/// and a little less padding than a page-level button. The lime still says
/// "this is the one to press"; it no longer shouts over the tasks above it.
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tap(
    onTap: onPressed,
    semanticLabel: 'Mark submitted',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        // Mixed into the card: paler on the day card, and nearer full
        // strength on the night one, where a mix turns to olive.
        color: Color.lerp(
          C.card,
          C.mark,
          Theme.of(context).brightness == Brightness.dark ? .85 : .6,
        ),
        border: Border.all(color: C.ink),
      ),
      child: Text('MARK SUBMITTED', style: T.ghost(C.onMark)),
    ),
  );
}

/// The mark on a collapsed card, led by the small word for what it is —
/// `MARK —` or `MARK —/40` rather than a bare placeholder — or, once it is
/// graded, followed by the band it lands in.
class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    this.strong = false,
    this.band,
  });

  final String value;
  final String label;

  /// Semibold for a real figure, regular for a placeholder still waiting.
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
      // Ink throughout: the grey 9px label read as faint. A real figure is
      // still told apart from a placeholder by its weight.
      if (band == null) Text(label.toUpperCase(), style: T.eyebrow(C.ink)),
      Text(
        value,
        style: strong ? T.count(C.ink) : T.frac.copyWith(color: C.ink),
      ),
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
  const _DragHandle({
    required this.index,
    required this.label,
    this.size = _kGrip,
  });

  final int index;
  final String label;

  /// The glyph's size; a task's and a step's are the same.
  final double size;

  @override
  Widget build(BuildContext context) => ReorderableDragStartListener(
    index: index,
    child: Semantics(
      container: true,
      label: 'Drag to reorder $label',
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: SizedBox(
          width: size,
          height: 24,
          child: Icon(Icons.drag_indicator, size: size, color: C.muted),
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

  /// Lines the `+` up with the step checkboxes when the steps carry handles.
  final double indent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: indent, top: 2),
    child: Row(
      spacing: _kStepGap,
      children: [
        Tap(
          onTap: onSubmit,
          semanticLabel: 'Add step',
          child: SizedBox(
            width: _kStepCheck,
            height: _kStepCheck,
            child: Icon(Icons.add, size: _kStepCheck, color: C.ink),
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

/// The open task's TIME box: the estimate in force (or a dash), with the
/// chevron that says it opens. The presets open as a menu anchored under it,
/// the active one filled ink as in the list's due-window menu. Picking a
/// preset sets it; picking the active one clears it.
class _EstimatePicker extends StatelessWidget {
  const _EstimatePicker({
    required this.minutes,
    required this.task,
    required this.onPick,
  });

  final int? minutes;
  final String task;
  final ValueChanged<int?> onPick;

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final topLeft = box.localToGlobal(
      Offset(0, box.size.height + 4),
      ancestor: overlay,
    );
    final picked = await showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(
        topLeft & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      color: C.card,
      elevation: 0,
      shape: RoundedRectangleBorder(side: BorderSide(color: C.ink, width: 1.5)),
      menuPadding: const EdgeInsets.symmetric(vertical: 4),
      constraints: const BoxConstraints(minWidth: _kTimeField),
      items: [
        for (final m in kEstimateChoices) _item(m, minutes == m),
      ],
    );
    if (picked == null) return;
    onPick(picked == minutes ? null : picked);
  }

  PopupMenuItem<int> _item(int m, bool on) => PopupMenuItem<int>(
    value: m,
    height: 34,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Semantics(
      label: on
          ? 'Clear the ${formatMinutes(m)} estimate'
          : 'Estimate ${formatMinutes(m)}',
      selected: on,
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          color: on ? C.ink : null,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          // Not uppercased: 15M would read as months.
          child: Text(formatMinutes(m), style: T.chip(on ? C.onInk : C.ink)),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final set = minutes != null;
    return Builder(
      builder: (context) => Tap(
        onTap: () => _open(context),
        semanticLabel: set
            ? 'Time for $task, ${formatMinutes(minutes!)}, change it'
            : 'Time for $task, not set, set it',
        child: Container(
          height: _kMetaHeight,
          padding: const EdgeInsets.only(left: 10, right: 6),
          decoration: BoxDecoration(
            color: C.field,
            border: Border.all(color: C.rule),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  set ? formatMinutes(minutes!) : 'e.g. 1h',
                  style: set ? T.monoInput : T.monoInput.copyWith(color: C.muted),
                ),
              ),
              Icon(Icons.expand_more, size: 16, color: C.ink),
            ],
          ),
        ),
      ),
    );
  }
}

/// Task rows: grip, gap, checkbox. A step's box and gap are a size down;
/// its grip and remove are the task's, so every icon in the card is one size.
const double _kGrip = 16;
const double _kRowGap = 10;
const double _kCheck = 19;
const double _kStepGrip = _kGrip;
const double _kStepGap = 8;
const double _kStepCheck = 15;

/// The open task's MARKS box and TIME control: one width for the number,
/// one height for both, so the pair is a single row of a form.
const double _kMarksField = 76;
const double _kTimeField = 96;
const double _kMetaHeight = 36;

/// The open card's DUE, TASKS and SUBJECT values each sit in a slot this
/// tall, so the three share one baseline.
const double _kFactHeight = 16;

/// A task's or step's text. Ticked work is struck through but stays ink, so
/// it is still readable on the night card; the strike itself is a thin muted
/// hairline, so a done row reads as crossed off rather than blacked out.
TextStyle _taskStyle(bool done) => T.task(done: done).copyWith(
  color: C.ink,
  decorationColor: C.muted,
  decorationThickness: done ? 0.5 : null,
);

/// One of the open card's facts: a label over a value in a fixed-height slot.
class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => LabelledField(
    label: label,
    child: SizedBox(
      height: _kFactHeight,
      child: Align(alignment: Alignment.centerLeft, child: child),
    ),
  );
}

/// A task's or a step's tick box. Ticked is filled ink with a card-coloured
/// tick: lime is kept for the card's one primary, Mark submitted. Unticked
/// is outlined in muted, which still reads on the night card.
///
/// The same semantics as the shared [CheckBoxSquare], which this stands in
/// for until that atom takes the ink fill (see the round report).
class _Check extends StatelessWidget {
  const _Check({required this.done, required this.onTap, this.size = _kCheck});

  final bool done;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) => Tap(
    onTap: onTap,
    semanticLabel: done ? 'Mark task unfinished' : 'Mark task finished',
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: done ? C.ink : Colors.transparent,
        border: Border.all(color: done ? C.ink : C.muted, width: 1.5),
      ),
      child: done
          ? Icon(Icons.check, size: size - 5, color: C.onInk)
          : null,
    ),
  );
}

/// Remove, for a task or a step: one quiet glyph, one size at both levels,
/// in the same 24px box as the drag handle opposite it, so a row carries one weight of control at
/// each end rather than a mix.
class _RowRemove extends StatelessWidget {
  const _RowRemove({
    required this.onTap,
    required this.semanticLabel,
  });

  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Tap(
    onTap: onTap,
    semanticLabel: semanticLabel,
    child: SizedBox(
      width: 24,
      height: 24,
      child: const Center(child: CloseGlyph()),
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
