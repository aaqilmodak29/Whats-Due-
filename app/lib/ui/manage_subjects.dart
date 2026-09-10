import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'assignment_card.dart' show confirm;
import 'atoms.dart';

/// The subjects panel: add, recolour, rename, delete.
///
/// Deleting a subject unfiles its assignments rather than cascading a delete —
/// losing a subject should never lose work.
class ManageSubjects extends StatefulWidget {
  const ManageSubjects({super.key, required this.store});

  final AppStore store;

  @override
  State<ManageSubjects> createState() => _ManageSubjectsState();
}

class _ManageSubjectsState extends State<ManageSubjects> {
  final _name = TextEditingController();
  final _focus = FocusNode();

  /// Null until a swatch is tapped, so the default follows the palette as
  /// subjects are added rather than sticking on whatever was offered first.
  String? _picked;

  AppStore get store => widget.store;

  String get _colour => _picked ?? store.nextColor;

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _focus.requestFocus();
      return;
    }
    store.addSubject(name, _colour);
    setState(() {
      _name.clear();
      // Back to following the palette, so the next one differs again.
      _picked = null;
    });
    // Keep focus, so several subjects can be typed in a row.
    _focus.requestFocus();
  }

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
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              'No subjects yet. Name one below, or create it inline when you '
              'add an assignment.',
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

        // Adding lives here as well as in the add-assignment panel. Creating a
        // subject inline while adding an assignment only works when you happen
        // to be adding one; setting a semester up in advance is its own job.
        const SizedBox(height: 14),
        Container(height: 1, color: C.rule),
        const SizedBox(height: 12),
        Text('ADD A SUBJECT', style: T.flabel),
        const SizedBox(height: 5),
        Row(
          spacing: 6,
          children: [
            Expanded(
              child: TextField(
                controller: _name,
                focusNode: _focus,
                style: T.body,
                textInputAction: TextInputAction.done,
                decoration: fieldDecoration(hint: 'e.g. Organic Chemistry'),
                onSubmitted: (_) => _add(),
              ),
            ),
            Tap(
              onTap: _add,
              semanticLabel: 'Add subject',
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
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in kPalette)
              Tap(
                onTap: () => setState(() => _picked = c),
                semanticLabel: 'Use this colour for the new subject',
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: hexToColor(c),
                    border: Border.all(
                      color: c == _colour ? C.ink : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
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
