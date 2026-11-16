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

  /// The semester a new subject is filed under; empty for none.
  /// Starts on the semester the list is showing, if any.
  late String _semester = widget.store.semesterFilter ?? '';

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
    store.addSubject(
      name,
      _colour,
      semesterId: _semester.isEmpty ? null : _semester,
    );
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
                _CountCell(width: _kOpenCol, text: 'OPEN', style: T.flabel),
                _CountCell(
                  width: _kDoneCol,
                  text: 'SUBMITTED',
                  style: T.flabel,
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
              if (store.semesters.isNotEmpty)
                LabelledField(
                  label: 'Semester',
                  child: SemesterDropdown(
                    store: store,
                    value: _semester,
                    semanticLabel: 'Semester for the new subject',
                    onChanged: (v) => setState(() => _semester = v),
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
        _Semesters(store: store),
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
    // Subjects are shared by both sections, so this counts both.
    final open = widget.store.items
        .where((a) => !a.done && a.subjectId == s.id)
        .length;
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _name,
                  focusNode: _focus,
                  style: T.body,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _commit(),
                  decoration: inlineNameDecoration(focused: _focus.hasFocus),
                ),
                // Only once there is a semester to choose, so the list keeps
                // its one-line rows for anyone not using them.
                if (widget.store.semesters.isNotEmpty)
                  SemesterDropdown(
                    store: widget.store,
                    value: s.semesterId ?? '',
                    semanticLabel: 'Semester for ${s.name}',
                    fontSize: 13,
                    onChanged: (v) => widget.store.setSubjectSemester(
                      s,
                      v.isEmpty ? null : v,
                    ),
                  ),
              ],
            ),
          ),
          _CountCell(width: _kOpenCol, text: '$open', style: T.count(C.ink)),
          _CountCell(
            width: _kDoneCol,
            text: '$submitted',
            style: T.count(C.ink),
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

/// Picks a semester for a subject, with "No semester" as the empty choice.
/// Used when adding a subject, in either panel, and on each subject's row.
class SemesterDropdown extends StatelessWidget {
  const SemesterDropdown({
    super.key,
    required this.store,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    this.fontSize = 15,
  });

  final AppStore store;

  /// A semester id, or empty for none.
  final String value;
  final ValueChanged<String> onChanged;
  final String semanticLabel;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final known = store.semesters.any((s) => s.id == value);
    final v = known ? value : '';
    return SubjectDropdown<String>(
      // The form field only reads its value once; keyed so an outside change
      // (a deleted semester) shows.
      key: ValueKey(v),
      value: v,
      semanticLabel: semanticLabel,
      fontSize: fontSize,
      onChanged: (x) => onChanged(x ?? ''),
      items: [
        const DropdownMenuItem(value: '', child: Text('No semester')),
        for (final s in store.semesters)
          DropdownMenuItem(value: s.id, child: Text(s.name)),
      ],
    );
  }
}

/// A name that edits in place: transparent until focused, so the row reads as
/// a list rather than a form. Shared by subject and semester rows.
InputDecoration inlineNameDecoration({required bool focused}) =>
    InputDecoration(
      isDense: true,
      filled: true,
      fillColor: focused ? C.field : Colors.transparent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
    );

/// The semesters, below the subjects: each renames in place and deletes with
/// the same glyph, and a new one is added with the card's task row.
class _Semesters extends StatefulWidget {
  const _Semesters({required this.store});

  final AppStore store;

  @override
  State<_Semesters> createState() => _SemestersState();
}

class _SemestersState extends State<_Semesters> {
  final _name = TextEditingController();
  final _focus = FocusNode();

  AppStore get store => widget.store;

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add() {
    if (store.addSemester(_name.text) == null) {
      _focus.requestFocus();
      return;
    }
    _name.clear();
    // Keep focus, so several can be typed in a row.
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: C.rule)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Semesters'),
        if (store.semesters.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'None yet. Add one to file subjects under it.',
              style: T.emptyBody,
            ),
          )
        else
          for (final (i, s) in store.semesters.indexed)
            DecoratedBox(
              key: ValueKey(s.id),
              decoration: BoxDecoration(
                border: i == 0 ? null : Border(top: BorderSide(color: C.rule)),
              ),
              child: _SemesterRow(store: store, semester: s),
            ),
        const SizedBox(height: 8),
        AddRow(
          controller: _name,
          focusNode: _focus,
          hint: 'Add a semester',
          buttonLabel: 'Add semester',
          onSubmit: _add,
        ),
      ],
    ),
  );
}

class _SemesterRow extends StatefulWidget {
  const _SemesterRow({required this.store, required this.semester});

  final AppStore store;
  final Semester semester;

  @override
  State<_SemesterRow> createState() => _SemesterRowState();
}

class _SemesterRowState extends State<_SemesterRow> {
  late final TextEditingController _name = TextEditingController(
    text: widget.semester.name,
  );
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
      setState(() {});
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
      _name.text = widget.semester.name;
      return;
    }
    if (v != widget.semester.name) {
      widget.store.renameSemester(widget.semester, v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.semester;
    final count = widget.store.subjects
        .where((x) => x.semesterId == s.id)
        .length;
    void delete() => widget.store.deleteSemester(s);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        spacing: _kRowGap,
        children: [
          Expanded(
            child: Semantics(
              label: 'Semester name',
              child: TextField(
                controller: _name,
                focusNode: _focus,
                style: T.body,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _commit(),
                decoration: inlineNameDecoration(focused: _focus.hasFocus),
              ),
            ),
          ),
          _CountCell(width: _kDoneCol, text: '$count SUBJ.', style: T.flabel),
          Tap(
            onTap: () {
              if (count == 0) return delete();
              confirm(
                context,
                title: 'Delete “${s.name}”?',
                body:
                    'Its $count subject${count == 1 ? '' : 's'} will have no '
                    'semester. No subjects or work are deleted.',
                confirmLabel: 'Delete semester',
                onConfirm: delete,
              );
            },
            semanticLabel: 'Delete semester ${s.name}',
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

/// A right-aligned cell in the subject list's count columns, used for the
/// heading and for every row, so a column's label and its numbers end on
/// the same line.
///
/// Mono letter-spacing is added after every glyph, the last one included, so
/// a right-aligned spaced label stops short of its box by that much while a
/// bolder number in a different spacing stops short by another amount. The
/// trailing space is taken back here, so it is the ink that lines up, not
/// the advance.
class _CountCell extends StatelessWidget {
  const _CountCell({
    required this.width,
    required this.text,
    required this.style,
  });

  final double width;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Align(
      alignment: Alignment.centerRight,
      child: Transform.translate(
        offset: Offset(style.letterSpacing ?? 0, 0),
        child: Text(text, style: style),
      ),
    ),
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
