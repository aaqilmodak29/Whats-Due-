import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'assignment_card.dart' show confirm;
import 'atoms.dart';

/// The subjects panel: recolour, rename, delete.
///
/// Deleting a subject unfiles its assignments rather than cascading a delete —
/// losing a subject should never lose work.
class ManageSubjects extends StatelessWidget {
  const ManageSubjects({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) => Surface(
    topBorder: C.ink,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Subjects'),
        const SizedBox(height: 6),
        if (store.subjects.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'No subjects yet. Add one from the + button when you create an '
              'assignment.',
              style: T.note,
            ),
          )
        else ...[
          for (final s in store.subjects) _SubjectRow(store: store, subject: s),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Tap a swatch to change its colour, or the name to rename it. '
              'Deleting a subject keeps its assignments.',
              style: T.note,
            ),
          ),
        ],
      ],
    ),
  );
}

class _SubjectRow extends StatefulWidget {
  const _SubjectRow({required this.store, required this.subject});

  final AppStore store;
  final Subject subject;

  @override
  State<_SubjectRow> createState() => _SubjectRowState();
}

class _SubjectRowState extends State<_SubjectRow> {
  late final TextEditingController _name = TextEditingController(
    text: widget.subject.name,
  );
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Commit the rename on blur, matching the web app's `onchange`.
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    final v = _name.text.trim();
    if (v.isEmpty) {
      // Refuse the empty name and put the old one back.
      _name.text = widget.subject.name;
      return;
    }
    if (v != widget.subject.name) widget.store.renameSubject(widget.subject, v);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.subject;
    final count = widget.store.countFor(s.id);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        spacing: 9,
        children: [
          Tap(
            onTap: () => widget.store.cycleSubjectColor(s),
            semanticLabel: 'Change colour for ${s.name}',
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: s.swatch,
                border: Border.all(color: C.ink, width: 1.5),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _name,
              focusNode: _focus,
              style: T.body,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _commit(),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                // Transparent until focused, so the row reads as a list rather
                // than a form.
                fillColor: _focus.hasFocus ? C.field : Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: Colors.transparent),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: Colors.transparent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: C.rule),
                ),
              ),
            ),
          ),
          Eyebrow('$count'),
          Tap(
            onTap: () {
              if (count == 0) {
                widget.store.deleteSubject(s);
                return;
              }
              confirm(
                context,
                title: 'Delete “${s.name}”?',
                body: 'Its $count assignment${count == 1 ? '' : 's'} '
                    'will become Unfiled. Nothing is lost.',
                confirmLabel: 'Delete subject',
                onConfirm: () => widget.store.deleteSubject(s),
              );
            },
            semanticLabel: 'Delete subject ${s.name}',
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: CloseGlyph(size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
