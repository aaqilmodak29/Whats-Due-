import 'package:flutter/material.dart';

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

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    widget.store.editAssignment(widget.assignment, title: title, due: _due);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final unchanged =
        _title.text.trim() == widget.assignment.title &&
        _due == widget.assignment.due;

    return Dialog(
      backgroundColor: C.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          decoration: const BoxDecoration(
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
                          style: T.ghost(Colors.white),
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
