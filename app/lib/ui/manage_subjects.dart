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

  /// A panel of its own rather than one more band in the list: an ink
  /// outline all round (the open card's language for "the thing being worked
  /// on") under a heading that names it, the subjects as a list, and adding
  /// as a labelled form at the foot.
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: C.card,
      border: Border.all(color: C.ink),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The counts are a table: one right-aligned column for open work and
        // one for submitted, headed once here, so every row's numbers line up
        // however long the subject's name is. A rule closes the heading and
        // a hairline sits between rows, so the panel reads as one list.
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: C.rule)),
          ),
          child: Row(
            spacing: _kRowGap,
            children: [
              const Expanded(child: Eyebrow('Subjects')),
              if (store.subjects.isNotEmpty) ...[
                _CountCell(width: _kOpenCol, child: Text('OPEN', style: T.flabel)),
                _CountCell(
                  width: _kDoneCol,
                  child: Text('SUBMITTED', style: T.flabel),
                ),
                const SizedBox(width: _kDeleteCol),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: store.subjects.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'No subjects yet. Name one below.',
                    style: T.emptyBody,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, s) in store.subjects.indexed)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: i == 0
                              ? null
                              : Border(top: BorderSide(color: C.rule)),
                        ),
                        child: _SubjectRow(store: store, subject: s),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Tap a colour to change it. Deleting keeps its work.',
                        style: T.emptyBody,
                      ),
                    ),
                  ],
                ),
        ),

        // Adding lives here as well as in the add-assignment panel. Creating a
        // subject inline while adding an assignment only works when you happen
        // to be adding one; setting a semester up in advance is its own job.
        // Below a rule, so the form reads as apart from the list.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: C.rule)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              LabelledField(
                label: 'New subject',
                child: Row(
                  spacing: 6,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _name,
                        focusNode: _focus,
                        style: T.input,
                        textInputAction: TextInputAction.done,
                        decoration: fieldDecoration(
                          hint: 'e.g. Organic Chemistry',
                        ),
                        onSubmitted: (_) => _add(),
                      ),
                    ),
                    Tap(
                      onTap: _add,
                      semanticLabel: 'Add subject',
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        color: C.ink,
                        alignment: Alignment.center,
                        child: Text('ADD', style: T.ghost(C.onInk)),
                      ),
                    ),
                  ],
                ),
              ),
              // The palette spread across the panel's width rather than
              // bunched at the left with a gap at the end.
              LabelledField(
                label: 'Colour',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final c in kPalette)
                      Tap(
                        onTap: () => setState(() => _picked = c),
                        semanticLabel: 'Use this colour for the new subject',
                        child: Swatch(colour: hexToColor(c), on: c == _colour),
                      ),
                  ],
                ),
              ),
            ],
          ),
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
    // Split the way the list splits them, so this agrees with the subject's
    // chip (open work) instead of showing a bigger number beside it.
    final open = widget.store.active.where((a) => a.subjectId == s.id).length;
    final submitted = count - open;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        spacing: _kRowGap,
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
          _CountCell(
            width: _kOpenCol,
            child: Text('$open', style: T.count(C.ink)),
          ),
          _CountCell(
            width: _kDoneCol,
            child: Text('$submitted', style: T.count(C.ink)),
          ),
          Tap(
            onTap: () {
              if (count == 0) {
                widget.store.deleteSubject(s);
                return;
              }
              confirm(
                context,
                title: 'Delete “${s.name}”?',
                body:
                    'Its $count assignment${count == 1 ? '' : 's'} '
                    'will become Unfiled. Nothing is lost.',
                confirmLabel: 'Delete subject',
                onConfirm: () => widget.store.deleteSubject(s),
              );
            },
            semanticLabel: 'Delete subject ${s.name}',
            child: const SizedBox(
              width: _kDeleteCol,
              height: _kDeleteCol,
              child: Center(child: CloseGlyph(size: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The subject list's columns: the gap between cells, the two count columns
/// and the delete glyph's box, shared by the heading and every row.
const double _kRowGap = 9;
const double _kOpenCol = 36;
const double _kDoneCol = 62;
const double _kDeleteCol = 24;

/// A right-aligned cell in the subject list's count columns.
class _CountCell extends StatelessWidget {
  const _CountCell({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Align(alignment: Alignment.centerRight, child: child),
  );
}

/// A colour choice. The chosen one gets an ink ring standing clear of the
/// colour, so it reads as picked at a glance rather than by a thin border
/// drawn on the colour itself, which the darker swatches swallowed.
class Swatch extends StatelessWidget {
  const Swatch({super.key, required this.colour, required this.on});

  final Color colour;
  final bool on;

  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      border: Border.all(color: on ? C.ink : Colors.transparent, width: 2),
    ),
    child: ColoredBox(color: colour),
  );
}
