import 'package:flutter/material.dart';

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

  @override
  void dispose() {
    _taskController.dispose();
    _taskFocus.dispose();
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

    return Opacity(
      opacity: a.done ? .62 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: C.card,
          border: Border(left: BorderSide(color: spine, width: 6)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A16202E),
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              expanded: widget.expanded,
              label: '${a.title}, ${subject?.name ?? 'unfiled'}, '
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
                                  Expanded(
                                    child: Eyebrow(
                                      subject?.name ?? 'Unfiled',
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              a.done ? 'SUBMITTED' : countdown(n),
                              style: T.count(spine),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(a.title, style: T.title(struck: a.done)),
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
      ),
    );
  }

  Widget _body(Assignment a, AppStore store) => Padding(
    padding: const EdgeInsets.only(left: 14, right: 14, bottom: 13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Eyebrow(longDate(a.due)),
        ),
        SubjectDropdown<String>(
          value: a.subjectId ?? '',
          semanticLabel: 'Change subject',
          fontSize: 13,
          onChanged: (v) =>
              store.setSubject(a, (v == null || v.isEmpty) ? null : v),
          items: [
            const DropdownMenuItem(value: '', child: Text('Unfiled')),
            for (final s in store.subjects)
              DropdownMenuItem(value: s.id, child: Text(s.name)),
          ],
        ),
        const SizedBox(height: 10),
        for (final t in a.tasks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              spacing: 10,
              children: [
                CheckBoxSquare(
                  done: t.done,
                  onTap: () => store.toggleTask(a, t),
                ),
                Expanded(
                  child: Text(t.text, style: T.task(done: t.done)),
                ),
                Tap(
                  onTap: () => store.deleteTask(a, t),
                  semanticLabel: 'Remove task ${t.text}',
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: CloseGlyph(color: C.rule, size: 16),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            spacing: 6,
            children: [
              Expanded(
                child: TextField(
                  controller: _taskController,
                  focusNode: _taskFocus,
                  style: T.body,
                  decoration: fieldDecoration(hint: 'Add a task'),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _pushTask(),
                ),
              ),
              Tap(
                onTap: _pushTask,
                semanticLabel: 'Add task',
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  color: C.ink,
                  alignment: Alignment.center,
                  child: Text('ADD', style: T.primary.copyWith(fontSize: 11)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),
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
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.delete_outline,
                  size: 19,
                  color: C.muted,
                ),
              ),
            ),
          ],
        ),
      ],
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
                    style: T.ghost(Colors.white),
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
